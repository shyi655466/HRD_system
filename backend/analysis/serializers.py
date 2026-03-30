from rest_framework import serializers
from .models import Sample, HRDResult, AnalysisTask, SampleFile

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
        fields = ['patient_id', 'sample_code', 'data_type', 'description']

# 3. 样本序列化器 (核心)
class SampleSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()

    class Meta:
        model = Sample
        fields = [
            'id',
            'patient_id',
            'sample_code',
            'data_type',
            'upload_status',
            'analysis_status',
            'status',
            'description',
            'metadata',
            'created_at',
            'updated_at',
            'owner',
        ]
        read_only_fields = [
            'id',
            'status',
            'created_at',
            'updated_at',
            'owner',
        ]

    def get_status(self, obj):
        """
        兼容旧前端的状态字段
        优先返回分析状态；如果分析尚未开始，则返回上传状态
        """
        if obj.analysis_status and obj.analysis_status != Sample.AnalysisStatus.NOT_STARTED:
            return obj.analysis_status
        return obj.upload_status


class SampleFileSerializer(serializers.ModelSerializer):
    class Meta:
        model = SampleFile
        fields = [
            'id',
            'file_role',
            'original_name',
            'storage_path',
            'file_size',
            'upload_status',
            'merge_status',
            'is_verified',
            'metadata',
            'created_at',
            'updated_at',
        ]


class SampleDetailSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()
    files = SampleFileSerializer(many=True, read_only=True)

    class Meta:
        model = Sample
        fields = [
            'id',
            'patient_id',
            'sample_code',
            'data_type',
            'upload_status',
            'analysis_status',
            'status',
            'description',
            'metadata',
            'created_at',
            'updated_at',
            'files',
        ]

    def get_status(self, obj):
        if obj.analysis_status and obj.analysis_status != Sample.AnalysisStatus.NOT_STARTED:
            return obj.analysis_status
        return obj.upload_status