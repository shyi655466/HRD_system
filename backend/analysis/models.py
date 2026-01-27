from django.db import models
from django.conf import settings
import uuid

class Sample(models.Model):
    """样本信息表"""
    STATUS_CHOICES = [
        ('uploaded', '待分析'),
        ('running', '分析中'),
        ('completed', '已完成'),
        ('failed', '分析失败'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient_id = models.CharField("患者编号", max_length=50, db_index=True)
    sample_code = models.CharField("样本条码", max_length=50, unique=True)
    
    # 存储路径建议存相对路径
    fastq_r1 = models.CharField("R1文件路径", max_length=255)
    fastq_r2 = models.CharField("R2文件路径", max_length=255, blank=True, null=True)
    
    status = models.CharField("状态", max_length=20, choices=STATUS_CHOICES, default='uploaded')
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, verbose_name="提交者")
    created_at = models.DateTimeField("创建时间", auto_now_add=True)

    class Meta:
        verbose_name = "样本管理"
        verbose_name_plural = verbose_name

class HRDResult(models.Model):
    """HRD分析结果表"""
    sample = models.OneToOneField(Sample, on_delete=models.CASCADE, related_name='result')
    
    # HRD核心三个指标
    hrd_score = models.FloatField("HRD总分", help_text="通常为 LOH+TAI+LST 的总和")
    loh_score = models.IntegerField("LOH评分")
    tai_score = models.IntegerField("TAI评分")
    lst_score = models.IntegerField("LST评分")
    
    # BRCA 状态
    brca_status = models.CharField("BRCA状态", max_length=50, choices=[('Positive', '阳性'), ('Negative', '阴性')])
    
    # 详细的变异数据 (存为JSON格式，灵活应对不同生信软件的输出)
    variant_data = models.JSONField("变异详情JSON", default=dict, blank=True)
    
    analysis_date = models.DateTimeField("分析完成时间", auto_now_add=True)

    class Meta:
        verbose_name = "分析结果"
        verbose_name_plural = verbose_name

class AnalysisTask(models.Model):
    """
    任务进度表 (AnalysisTasks)
    实现异步任务调度与审计追踪
    """
    TASK_STATUS = [
        ('PENDING', '排队中'),
        ('STARTED', '计算中'),
        ('SUCCESS', '成功'),
        ('FAILURE', '失败'),
        ('REVOKED', '已取消'),
    ]

    # 1. 关联样本 (外键)
    sample = models.ForeignKey(Sample, on_delete=models.CASCADE, related_name='tasks', verbose_name="关联样本")
    
    # 2. Celery 异步任务标识 (用于追踪和终止任务)
    celery_task_id = models.CharField("Celery任务ID", max_length=100, blank=True, null=True, unique=True)
    
    # 3. 任务状态 (记录具体的执行情况)
    status = models.CharField("任务状态", max_length=20, choices=TASK_STATUS, default='PENDING')
    
    # 4. 参数配置快照 (JSON格式，记录本次分析使用的纯度阈值、软件版本等)
    # 对应你报告中的：参数配置快照
    parameters = models.JSONField("参数快照", default=dict, blank=True)
    
    # 5. 运行日志索引 (存储关键报错信息或日志文件路径)
    # 对应你报告中的：运行日志索引
    log_output = models.TextField("执行日志/错误信息", blank=True)
    
    # 时间戳
    created_at = models.DateTimeField("任务创建时间", auto_now_add=True)
    updated_at = models.DateTimeField("状态更新时间", auto_now=True)

    class Meta:
        verbose_name = "分析任务记录"
        verbose_name_plural = verbose_name
        ordering = ['-created_at']

    def __str__(self):
        return f"Task {self.id} for {self.sample.sample_code} - {self.status}"