from django.contrib import admin
from .models import Sample, SampleFile, UploadSession, AnalysisTask, HRDResult


@admin.register(Sample)
class SampleAdmin(admin.ModelAdmin):
    list_display = (
        'sample_code',
        'patient_id',
        'data_type',
        'upload_status',
        'analysis_status',
        'owner',
        'created_at',
    )
    list_filter = (
        'data_type',
        'upload_status',
        'analysis_status',
        'created_at',
    )
    search_fields = (
        'sample_code',
        'patient_id',
    )
    ordering = ('-created_at',)


@admin.register(SampleFile)
class SampleFileAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'sample',
        'file_role',
        'original_name',
        'file_size',
        'uploaded_size',
        'upload_status',
        'merge_status',
        'is_verified',
        'created_at',
    )
    list_filter = (
        'file_role',
        'upload_status',
        'merge_status',
        'is_verified',
        'created_at',
    )
    search_fields = (
        'original_name',
        'sample__sample_code',
        'sample__patient_id',
    )
    ordering = ('-created_at',)


@admin.register(UploadSession)
class UploadSessionAdmin(admin.ModelAdmin):
    list_display = (
        'upload_id',
        'file',
        'status',
        'total_size',
        'current_offset',
        'uploaded_chunks',
        'created_at',
        'last_activity_at',
    )
    list_filter = (
        'status',
        'created_at',
        'expires_at',
    )
    search_fields = (
        'upload_id',
        'file__original_name',
        'file__sample__sample_code',
    )
    ordering = ('-created_at',)


@admin.register(AnalysisTask)
class AnalysisTaskAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'sample',
        'task_type',
        'status',
        'celery_task_id',
        'retry_count',
        'created_at',
        'started_at',
        'finished_at',
    )
    list_filter = (
        'task_type',
        'status',
        'created_at',
    )
    search_fields = (
        'sample__sample_code',
        'sample__patient_id',
        'celery_task_id',
    )
    ordering = ('-created_at',)


@admin.register(HRDResult)
class HRDResultAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'sample',
        'hrd_score',
        'loh_score',
        'tai_score',
        'lst_score',
        'brca_status',
        'analysis_date',
    )
    list_filter = (
        'brca_status',
        'analysis_date',
    )
    search_fields = (
        'sample__sample_code',
        'sample__patient_id',
    )
    ordering = ('-analysis_date',)