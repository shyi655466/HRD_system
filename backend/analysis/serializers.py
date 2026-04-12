from rest_framework import serializers
from .models import Sample, HRDResult, AnalysisTask, SampleFile

# 1. 结果序列化器
class HRDResultSerializer(serializers.ModelSerializer):
    class Meta:
        model = HRDResult
        fields = [
            "hrd_score",
            "loh_score",
            "tai_score",
            "lst_score",
            "brca_status",
            "variant_data",
            "analysis_date",
        ]


# 2. 任务序列化器（与 AnalysisTask 模型字段一致）
class AnalysisTaskSerializer(serializers.ModelSerializer):
    class Meta:
        model = AnalysisTask
        fields = [
            "id",
            "task_type",
            "status",
            "celery_task_id",
            "log_output",
            "error_message",
            "created_at",
            "started_at",
            "finished_at",
        ]

# 3. 样本序列化器 (核心)
class SampleSerializer(serializers.ModelSerializer):
    status = serializers.SerializerMethodField()
    result = HRDResultSerializer(source="hrd_result", read_only=True, allow_null=True)

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
            'result',
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
    result = HRDResultSerializer(source="hrd_result", read_only=True, allow_null=True)
    tasks = AnalysisTaskSerializer(many=True, read_only=True, source="analysis_tasks")

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
            'result',
            'tasks',
        ]

    def get_status(self, obj):
        if obj.analysis_status and obj.analysis_status != Sample.AnalysisStatus.NOT_STARTED:
            return obj.analysis_status
        return obj.upload_status