import uuid
from django.conf import settings
from django.db import models
from django.utils import timezone


class TimeStampedModel(models.Model):
    """通用时间字段基类"""
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="创建时间")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="更新时间")

    class Meta:
        abstract = True

class Sample(TimeStampedModel):
    class DataType(models.TextChoices):
        WGS = "WGS", "WGS"
        WES = "WES", "WES"
        SNP_PANEL = "SNP_PANEL", "SNP Panel"

    class UploadStatus(models.TextChoices):
        DRAFT = "DRAFT", "草稿"
        UPLOADING = "UPLOADING", "上传中"
        UPLOADED = "UPLOADED", "已上传"
        UPLOAD_FAILED = "UPLOAD_FAILED", "上传失败"

    class AnalysisStatus(models.TextChoices):
        NOT_STARTED = "NOT_STARTED", "未开始"
        QUEUED = "QUEUED", "排队中"
        RUNNING = "RUNNING", "分析中"
        COMPLETED = "COMPLETED", "已完成"
        FAILED = "FAILED", "分析失败"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient_id = models.CharField(max_length=50, db_index=True)
    sample_code = models.CharField(max_length=50, unique=True, db_index=True)
    data_type = models.CharField(max_length=20, choices=DataType.choices, default=DataType.WGS)
    upload_status = models.CharField(max_length=20, choices=UploadStatus.choices, default=UploadStatus.DRAFT)
    analysis_status = models.CharField(max_length=20, choices=AnalysisStatus.choices, default=AnalysisStatus.NOT_STARTED)
    description = models.TextField(blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="samples")

    class Meta:
        verbose_name = "样本"
        verbose_name_plural = "样本"

class SampleFile(TimeStampedModel):
    class FileRole(models.TextChoices):
        TUMOR_R1 = "TUMOR_R1", "Tumor FASTQ R1"
        TUMOR_R2 = "TUMOR_R2", "Tumor FASTQ R2"
        NORMAL_R1 = "NORMAL_R1", "Normal FASTQ R1"
        NORMAL_R2 = "NORMAL_R2", "Normal FASTQ R2"

    class UploadStatus(models.TextChoices):
        PENDING = "PENDING", "待上传"
        UPLOADING = "UPLOADING", "上传中"
        UPLOADED = "UPLOADED", "已上传"
        FAILED = "FAILED", "上传失败"
        CANCELLED = "CANCELLED", "已取消"

    class MergeStatus(models.TextChoices):
        PENDING = "PENDING", "待合并"
        MERGING = "MERGING", "合并中"
        MERGED = "MERGED", "已合并"
        FAILED = "FAILED", "合并失败"

    id = models.BigAutoField(primary_key=True)
    sample = models.ForeignKey(Sample, on_delete=models.CASCADE, related_name="files")
    file_role = models.CharField(max_length=20, choices=FileRole.choices, db_index=True)
    original_name = models.CharField(max_length=255)
    stored_name = models.CharField(max_length=255, blank=True, default="")
    storage_path = models.CharField(max_length=500, blank=True, default="")
    temp_dir = models.CharField(max_length=500, blank=True, default="")
    file_size = models.BigIntegerField(default=0)
    uploaded_size = models.BigIntegerField(default=0)
    chunk_size = models.IntegerField(default=0)
    total_chunks = models.IntegerField(default=0)
    checksum_md5 = models.CharField(max_length=32, blank=True, default="")
    upload_status = models.CharField(max_length=20, choices=UploadStatus.choices, default=UploadStatus.PENDING)
    merge_status = models.CharField(max_length=20, choices=MergeStatus.choices, default=MergeStatus.PENDING)
    is_verified = models.BooleanField(default=False)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name = "样本文件"
        verbose_name_plural = "样本文件"

class UploadSession(TimeStampedModel):
    """
    上传会话表
    用于分片上传、断点续传、恢复上传状态
    """

    class Status(models.TextChoices):
        INITIATED = "INITIATED", "已初始化"
        UPLOADING = "UPLOADING", "上传中"
        PAUSED = "PAUSED", "已暂停"
        MERGING = "MERGING", "合并中"
        COMPLETED = "COMPLETED", "已完成"
        FAILED = "FAILED", "失败"
        EXPIRED = "EXPIRED", "已过期"
        CANCELLED = "CANCELLED", "已取消"

    id = models.BigAutoField(primary_key=True)
    upload_id = models.UUIDField(
        default=uuid.uuid4,
        unique=True,
        editable=False,
        db_index=True,
        verbose_name="上传会话ID"
    )
    file = models.ForeignKey(
        SampleFile,
        on_delete=models.CASCADE,
        related_name="upload_sessions",
        verbose_name="所属文件"
    )
    chunk_size = models.IntegerField(
        verbose_name="分片大小(Byte)"
    )
    total_size = models.BigIntegerField(
        verbose_name="文件总大小(Byte)"
    )
    current_offset = models.BigIntegerField(
        default=0,
        verbose_name="当前偏移量(Byte)"
    )
    total_chunks = models.IntegerField(
        default=0,
        verbose_name="总分片数"
    )
    uploaded_chunks = models.IntegerField(
        default=0,
        verbose_name="已上传分片数"
    )
    uploaded_parts = models.JSONField(
        default=list,
        blank=True,
        verbose_name="已上传分片列表"
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.INITIATED,
        db_index=True,
        verbose_name="会话状态"
    )
    client_fingerprint = models.CharField(
        max_length=255,
        blank=True,
        default="",
        verbose_name="客户端标识"
    )
    expires_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="过期时间"
    )
    last_activity_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="最后活跃时间"
    )
    error_message = models.TextField(
        blank=True,
        default="",
        verbose_name="错误信息"
    )

    class Meta:
        db_table = "analysis_upload_session"
        verbose_name = "上传会话"
        verbose_name_plural = "上传会话"
        indexes = [
            models.Index(fields=["upload_id"]),
            models.Index(fields=["file"]),
            models.Index(fields=["status"]),
            models.Index(fields=["expires_at"]),
            models.Index(fields=["last_activity_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.upload_id} - {self.file.original_name}"

    def touch(self):
        self.last_activity_at = timezone.now()
        self.save(update_fields=["last_activity_at", "updated_at"])


class AnalysisTask(TimeStampedModel):
    """
    分析任务表
    用于记录上传合并、HRD分析、报告生成等异步任务
    """

    class TaskType(models.TextChoices):
        UPLOAD_MERGE = "UPLOAD_MERGE", "文件合并"
        HRD_ANALYSIS = "HRD_ANALYSIS", "HRD分析"
        REPORT_GENERATE = "REPORT_GENERATE", "报告生成"
        OTHER = "OTHER", "其他"

    class Status(models.TextChoices):
        PENDING = "PENDING", "待执行"
        QUEUED = "QUEUED", "排队中"
        RUNNING = "RUNNING", "运行中"
        SUCCESS = "SUCCESS", "成功"
        FAILED = "FAILED", "失败"
        CANCELLED = "CANCELLED", "已取消"

    id = models.BigAutoField(primary_key=True)
    sample = models.ForeignKey(
        Sample,
        on_delete=models.CASCADE,
        related_name="analysis_tasks",
        verbose_name="所属样本"
    )
    task_type = models.CharField(
        max_length=30,
        choices=TaskType.choices,
        default=TaskType.HRD_ANALYSIS,
        db_index=True,
        verbose_name="任务类型"
    )
    celery_task_id = models.CharField(
        max_length=100,
        blank=True,
        default="",
        db_index=True,
        verbose_name="Celery任务ID"
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING,
        db_index=True,
        verbose_name="任务状态"
    )
    parameters = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="任务参数"
    )
    input_manifest = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="输入清单"
    )
    log_output = models.TextField(
        blank=True,
        default="",
        verbose_name="日志输出"
    )
    result_path = models.CharField(
        max_length=500,
        blank=True,
        default="",
        verbose_name="结果路径"
    )
    error_message = models.TextField(
        blank=True,
        default="",
        verbose_name="错误信息"
    )
    retry_count = models.IntegerField(
        default=0,
        verbose_name="重试次数"
    )
    started_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="开始时间"
    )
    finished_at = models.DateTimeField(
        null=True,
        blank=True,
        verbose_name="结束时间"
    )

    class Meta:
        db_table = "analysis_task"
        verbose_name = "分析任务"
        verbose_name_plural = "分析任务"
        indexes = [
            models.Index(fields=["sample", "task_type"]),
            models.Index(fields=["sample", "status"]),
            models.Index(fields=["celery_task_id"]),
            models.Index(fields=["created_at"]),
        ]
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.sample.sample_code} - {self.task_type} - {self.status}"


class HRDResult(TimeStampedModel):
    """
    HRD结果表
    一个样本通常对应一条最终HRD结果
    """

    class BRCAStatus(models.TextChoices):
        UNKNOWN = "UNKNOWN", "Unknown"
        POSITIVE = "POSITIVE", "Positive"
        NEGATIVE = "NEGATIVE", "Negative"
        VUS = "VUS", "VUS"

    id = models.BigAutoField(primary_key=True)
    sample = models.OneToOneField(
        Sample,
        on_delete=models.CASCADE,
        related_name="hrd_result",
        verbose_name="所属样本"
    )
    hrd_score = models.FloatField(
        default=0,
        verbose_name="HRD总分"
    )
    loh_score = models.IntegerField(
        default=0,
        verbose_name="LOH分数"
    )
    tai_score = models.IntegerField(
        default=0,
        verbose_name="TAI分数"
    )
    lst_score = models.IntegerField(
        default=0,
        verbose_name="LST分数"
    )
    brca_status = models.CharField(
        max_length=20,
        choices=BRCAStatus.choices,
        default=BRCAStatus.UNKNOWN,
        db_index=True,
        verbose_name="BRCA状态"
    )
    input_type = models.CharField(
        max_length=20,
        choices=Sample.DataType.choices,
        default=Sample.DataType.WGS,
        verbose_name="输入类型"
    )
    genome_build = models.CharField(
        max_length=20,
        blank=True,
        default="hg38",
        verbose_name="参考基因组版本"
    )
    pipeline_version = models.CharField(
        max_length=50,
        blank=True,
        default="",
        verbose_name="管道版本"
    )
    variant_data = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="变异数据"
    )
    qc_metrics = models.JSONField(
        default=dict,
        blank=True,
        verbose_name="质控指标"
    )
    report_path = models.CharField(
        max_length=500,
        blank=True,
        default="",
        verbose_name="报告路径"
    )
    analysis_date = models.DateTimeField(
        default=timezone.now,
        verbose_name="分析时间"
    )

    class Meta:
        db_table = "analysis_hrdresult"
        verbose_name = "HRD结果"
        verbose_name_plural = "HRD结果"
        indexes = [
            models.Index(fields=["brca_status"]),
            models.Index(fields=["analysis_date"]),
        ]
        ordering = ["-analysis_date"]

    def __str__(self):
        return f"{self.sample.sample_code} - HRD {self.hrd_score}"