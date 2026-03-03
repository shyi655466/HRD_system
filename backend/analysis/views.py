from rest_framework import generics, permissions, status
from rest_framework.views import APIView      
from rest_framework.response import Response  
from django.shortcuts import get_object_or_404
import uuid                                   
from .models import Sample, AnalysisTask, HRDResult
from .serializers import SampleSerializer
from .tasks import run_hrd_analysis

# 1. 列表视图：负责 "列出所有样本" 和 "创建新样本"
class SampleListCreateView(generics.ListCreateAPIView):
    queryset = Sample.objects.all().order_by('-created_at')
    serializer_class = SampleSerializer
    permission_classes = [permissions.IsAuthenticated]

    # 重写 perform_create：在创建样本时，自动把 "提交者" 设为当前登录用户
    # 注意：如果你用 Postman 测试没登录，这就需要先注释掉 owner 赋值，或者确保已登录
    def perform_create(self, serializer):
        # 如果是匿名用户测试，暂时指定一个默认用户（仅限调试阶段！）
        # user = self.request.user if self.request.user.is_authenticated else User.objects.first()
        serializer.save(owner=self.request.user) 

# 2. 详情视图：负责 "查询/修改/删除" 某一个特定样本
class SampleDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Sample.objects.all()
    serializer_class = SampleSerializer
    permission_classes = [permissions.IsAuthenticated]

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