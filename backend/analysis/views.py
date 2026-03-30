import os
from pathlib import Path
from rest_framework import generics, permissions, status
from rest_framework.views import APIView      
from rest_framework.response import Response  
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from django.conf import settings
from django.db import transaction                              
from .models import Sample, AnalysisTask, HRDResult, SampleFile
from .serializers import SampleSerializer, SampleDetailSerializer
from .tasks import run_hrd_analysis

# 1. 列表视图：负责 "列出所有样本" 和 "创建新样本"
class SampleListCreateView(generics.ListCreateAPIView):
    serializer_class = SampleSerializer
    permission_classes = [permissions.IsAuthenticated]

    # 重写 perform_create：在创建样本时，自动把 "提交者" 设为当前登录用户
    # 注意：如果你用 Postman 测试没登录，这就需要先注释掉 owner 赋值，或者确保已登录
    def perform_create(self, serializer):
        # 如果是匿名用户测试，暂时指定一个默认用户（仅限调试阶段！）
        # user = self.request.user if self.request.user.is_authenticated else User.objects.first()
        serializer.save(owner=self.request.user) 

    def get_queryset(self):
        return Sample.objects.filter(owner=self.request.user).order_by('-created_at')


# 2. 详情视图：负责 "查询/修改/删除" 某一个特定样本
class SampleDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = SampleDetailSerializer

    def get_queryset(self):
        return Sample.objects.filter(owner=self.request.user).prefetch_related('files')

# 3. 启动分析视图：负责 "触发" 分析流程
class StartAnalysisView(APIView):
    # 这是一个动作接口，不涉及复杂的序列化，所以用 APIView 最灵活
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        sample = get_object_or_404(Sample, pk=pk)

        if sample.status != 'uploaded' and sample.status != 'failed':
            return Response(
                {"error": f"当前样本状态为 {sample.get_status_display()}，无法启动分析。"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 1. 在数据库中创建任务记录 (初始状态为 PENDING)
        task = AnalysisTask.objects.create(
            sample=sample,
            status='PENDING',
            parameters={"pipeline_version": "v2.0_async"} # 标记这是异步跑的
        )

        # 2. 更新样本状态
        sample.status = 'running'
        sample.save()

        # 3. 把任务丢进 Celery 队列
        # 注意这里的 .delay()，它意味着“不要等它跑完，直接往后走”
        celery_task = run_hrd_analysis.delay(task.id, sample.id)

        # 4. 把真实的 Celery 任务 ID 存进数据库，方便以后追踪
        task.celery_task_id = celery_task.id
        task.save()

        # 5. 瞬间返回给前端，不让页面卡住
        return Response({
            "message": "分析任务已成功加入后台队列",
            "db_task_id": task.id,
            "celery_id": celery_task.id,
            "current_status": sample.status
        }, status=status.HTTP_200_OK)

# 4. 结果回传视图：模拟生信软件跑完后，把结果 "推" 给后端
class SubmitResultView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        # A. 找到样本
        sample = get_object_or_404(Sample, pk=pk)

        # B. 接收数据 (假设生信流程发来是一个 JSON)
        data = request.data
        
        # C. 校验: 必须包含核心分数
        if 'hrd_score' not in data:
            return Response({"error": "缺少 hrd_score 字段"}, status=status.HTTP_400_BAD_REQUEST)

        # D. 写入结果表 (HRDResult)
        # update_or_create: 如果有了就更新，没有就创建 (防止重复报错)
        result, created = HRDResult.objects.update_or_create(
            sample=sample,
            defaults={
                'hrd_score': data.get('hrd_score'),
                'loh_score': data.get('loh_score', 0),
                'tai_score': data.get('tai_score', 0),
                'lst_score': data.get('lst_score', 0),
                'brca_status': data.get('brca_status', 'Unknown'),
                'variant_data': data.get('variant_data', {})
            }
        )

        # E. 完结撒花：更新样本和任务状态
        sample.status = 'completed'
        sample.save()

        # 找到该样本最近的一个正在跑的任务，把它标记为成功
        active_task = sample.tasks.filter(status='PENDING').first()
        if active_task:
            active_task.status = 'SUCCESS'
            active_task.save()

        return Response({
            "message": "分析结果已接收",
            "sample_id": sample.id,
            "result_id": result.id
        }, status=status.HTTP_200_OK)


# =========================
# 工具函数
# =========================

ALLOWED_FASTQ_SUFFIXES = [
    ".fastq",
    ".fq",
    ".fastq.gz",
    ".fq.gz",
]


def get_allowed_import_roots():
    roots = getattr(settings, "HRD_ALLOWED_IMPORT_ROOTS", [])
    return [Path(root).resolve() for root in roots]


def is_path_under_allowed_roots(target_path: Path) -> bool:
    """
    判断目标路径是否位于白名单目录下
    """
    try:
        resolved_target = target_path.resolve()
    except Exception:
        return False

    for root in get_allowed_import_roots():
        try:
            resolved_target.relative_to(root)
            return True
        except ValueError:
            continue
    return False


def validate_fastq_file_path(path_str: str):
    """
    校验服务器文件路径是否合法
    返回: (is_valid, message, info_dict)
    """
    if not path_str:
        return False, "路径不能为空", {}

    target = Path(path_str)

    if not is_path_under_allowed_roots(target):
        return False, "路径不在允许导入的目录范围内", {}

    if not target.exists():
        return False, "文件不存在", {}

    if not target.is_file():
        return False, "目标不是文件", {}

    if not os.access(target, os.R_OK):
        return False, "文件不可读", {}

    file_name = target.name.lower()
    if not any(file_name.endswith(suffix) for suffix in ALLOWED_FASTQ_SUFFIXES):
        return False, "文件扩展名不合法，仅支持 .fastq/.fq/.fastq.gz/.fq.gz", {}

    info = {
        "resolved_path": str(target.resolve()),
        "file_name": target.name,
        "file_size": target.stat().st_size,
    }
    return True, "校验通过", info


# =========================
# 1. 校验服务器路径
# POST /api/analysis/server-files/validate-paths/
# =========================

class ServerPathValidateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        files = request.data.get("files", [])

        if not isinstance(files, list) or not files:
            return Response(
                {"detail": "files 必须是非空列表"},
                status=status.HTTP_400_BAD_REQUEST
            )

        results = []
        all_valid = True

        for item in files:
            file_role = item.get("file_role")
            path_str = item.get("path")

            is_valid, message, info = validate_fastq_file_path(path_str)

            result = {
                "file_role": file_role,
                "path": path_str,
                "is_valid": is_valid,
                "message": message,
            }
            result.update(info)

            if not is_valid:
                all_valid = False

            results.append(result)

        return Response(
            {
                "all_valid": all_valid,
                "results": results,
            },
            status=status.HTTP_200_OK
        )


# =========================
# 2. 浏览服务器目录
# GET /api/analysis/server-files/browse/?path=/data/hrd/
# =========================

class ServerFileBrowseView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        path_str = request.query_params.get("path", "")

        # 默认打开第一个允许目录
        if not path_str:
            allowed_roots = get_allowed_import_roots()
            if not allowed_roots:
                return Response(
                    {"detail": "未配置允许导入目录"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            target = allowed_roots[0]
        else:
            target = Path(path_str)

        if not is_path_under_allowed_roots(target):
            return Response(
                {"detail": "目录不在允许范围内"},
                status=status.HTTP_403_FORBIDDEN
            )

        if not target.exists():
            return Response(
                {"detail": "目录不存在"},
                status=status.HTTP_404_NOT_FOUND
            )

        if not target.is_dir():
            return Response(
                {"detail": "目标不是目录"},
                status=status.HTTP_400_BAD_REQUEST
            )

        children = []
        try:
            for child in sorted(target.iterdir(), key=lambda x: (not x.is_dir(), x.name.lower())):
                # 只返回白名单目录下的内容
                if not is_path_under_allowed_roots(child):
                    continue

                item = {
                    "name": child.name,
                    "path": str(child.resolve()),
                    "is_dir": child.is_dir(),
                }

                if child.is_file():
                    item["size"] = child.stat().st_size
                    item["is_fastq"] = any(child.name.lower().endswith(suffix) for suffix in ALLOWED_FASTQ_SUFFIXES)

                children.append(item)

        except PermissionError:
            return Response(
                {"detail": "无权限访问该目录"},
                status=status.HTTP_403_FORBIDDEN
            )

        return Response(
            {
                "current_path": str(target.resolve()),
                "children": children,
            },
            status=status.HTTP_200_OK
        )


# =========================
# 3. 从服务器路径导入样本
# POST /api/analysis/samples/import-from-server/
# =========================

class ImportSampleFromServerView(APIView):
    permission_classes = [IsAuthenticated]

    REQUIRED_FILE_ROLES = {
        "TUMOR_R1",
        "TUMOR_R2",
        "NORMAL_R1",
        "NORMAL_R2",
    }

    def post(self, request):
        patient_id = request.data.get("patient_id", "").strip()
        sample_code = request.data.get("sample_code", "").strip()
        data_type = request.data.get("data_type", "WGS").strip()
        description = request.data.get("description", "").strip()
        files = request.data.get("files", [])

        if not patient_id:
            return Response({"detail": "patient_id 不能为空"}, status=status.HTTP_400_BAD_REQUEST)

        if not sample_code:
            return Response({"detail": "sample_code 不能为空"}, status=status.HTTP_400_BAD_REQUEST)

        if data_type not in {"WGS", "WES", "SNP_PANEL"}:
            return Response({"detail": "data_type 不合法"}, status=status.HTTP_400_BAD_REQUEST)

        if not isinstance(files, list) or len(files) != 4:
            return Response(
                {"detail": "files 必须为包含 4 个文件的列表（tumor/normal 的 R1/R2）"},
                status=status.HTTP_400_BAD_REQUEST
            )

        roles = {item.get("file_role") for item in files}
        if roles != self.REQUIRED_FILE_ROLES:
            return Response(
                {
                    "detail": "files 必须且只能包含 TUMOR_R1 / TUMOR_R2 / NORMAL_R1 / NORMAL_R2"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 样本编号唯一校验
        if Sample.objects.filter(sample_code=sample_code).exists():
            return Response(
                {"detail": f"sample_code 已存在: {sample_code}"},
                status=status.HTTP_400_BAD_REQUEST
            )

        validated_files = []
        for item in files:
            file_role = item.get("file_role")
            path_str = item.get("path", "").strip()

            is_valid, message, info = validate_fastq_file_path(path_str)
            if not is_valid:
                return Response(
                    {
                        "detail": f"{file_role} 路径校验失败: {message}",
                        "file_role": file_role,
                        "path": path_str,
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            validated_files.append({
                "file_role": file_role,
                "original_path": path_str,
                "resolved_path": info["resolved_path"],
                "file_name": info["file_name"],
                "file_size": info["file_size"],
            })

        with transaction.atomic():
            sample = Sample.objects.create(
                patient_id=patient_id,
                sample_code=sample_code,
                data_type=data_type,
                upload_status=Sample.UploadStatus.UPLOADED,
                analysis_status=Sample.AnalysisStatus.NOT_STARTED,
                description=description,
                metadata={
                    "import_mode": "SERVER_PATH",
                },
                owner=request.user,
            )

            sample_files = []
            for file_info in validated_files:
                obj = SampleFile.objects.create(
                    sample=sample,
                    file_role=file_info["file_role"],
                    original_name=file_info["file_name"],
                    stored_name=file_info["file_name"],
                    storage_path=file_info["resolved_path"],
                    temp_dir="",
                    file_size=file_info["file_size"],
                    uploaded_size=file_info["file_size"],
                    chunk_size=0,
                    total_chunks=1,
                    checksum_md5="",
                    upload_status=SampleFile.UploadStatus.UPLOADED,
                    merge_status=SampleFile.MergeStatus.MERGED,
                    is_verified=True,
                    metadata={
                        "source_mode": "SERVER_PATH",
                        "original_server_path": file_info["original_path"],
                        "resolved_server_path": file_info["resolved_path"],
                    },
                )
                sample_files.append({
                    "id": obj.id,
                    "file_role": obj.file_role,
                    "original_name": obj.original_name,
                    "storage_path": obj.storage_path,
                    "file_size": obj.file_size,
                })

        return Response(
            {
                "detail": "样本已成功从服务器路径导入",
                "sample": {
                    "id": str(sample.id),
                    "patient_id": sample.patient_id,
                    "sample_code": sample.sample_code,
                    "data_type": sample.data_type,
                    "upload_status": sample.upload_status,
                    "analysis_status": sample.analysis_status,
                },
                "files": sample_files,
            },
            status=status.HTTP_201_CREATED
        )