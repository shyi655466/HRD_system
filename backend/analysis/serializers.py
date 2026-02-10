from rest_framework import serializers
from .models import Sample, HRDResult, AnalysisTask

# 1. 结果序列化器
class HRDResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = HRDResult
        # 我们只暴露核心的科学指标给前端
        fields = ['hrd_score', 'loh_score', 'tai_score', 'lst_score', 'brca_status', 'variant_data', 'analysis_date']

# 2. 任务序列化器
class AnalysisTaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalysisTask
        fields = ['id', 'status', 'created_at', 'log_output']

# 3. 样本序列化器 (核心)
class SampleSerializer(serializers.ModelSerializer):
    # 嵌套显示：在查询样本时，直接把它的 result (结果) 和 tasks (任务记录) 也带出来
    result = HRDResultSerializer(read_only=True)
    
    # 注意：因为是一对多，tasks 可能会有多个，所以 many=True
    tasks = AnalysisTaskSerializer(many=True, read_only=True)

    class Meta:
        model = Sample
        # 暴露所有关键字段，owner 字段我们会自动填充
        fields = ['id', 'patient_id', 'sample_code', 'status', 'created_at', 'result', 'tasks']
        read_only_fields = ['id', 'created_at', 'status']