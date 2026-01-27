from django.contrib import admin
from .models import Sample, HRDResult, AnalysisTask

@admin.register(Sample)
class SampleAdmin(admin.ModelAdmin):
    list_display = ('sample_code', 'patient_id', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('sample_code', 'patient_id')

@admin.register(HRDResult)
class HRDResultAdmin(admin.ModelAdmin):
    list_display = ('sample', 'hrd_score', 'brca_status', 'analysis_date')

@admin.register(AnalysisTask)
class AnalysisTaskAdmin(admin.ModelAdmin):
    list_display = ('id', 'sample', 'status', 'celery_task_id', 'created_at')
    list_filter = ('status', 'created_at')
    readonly_fields = ('created_at', 'updated_at')