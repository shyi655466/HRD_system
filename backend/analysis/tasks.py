# analysis/tasks.py
import traceback
from celery import shared_task
from django.db import transaction
from django.utils import timezone

from utils.logger import logger

from .hrd_pipeline import run_wgs_for_sample
from .models import Sample, AnalysisTask, HRDResult


@shared_task
def run_hrd_analysis(db_task_id, sample_id):
    """
    异步 HRD 分析：初版仅 WGS，调用 pipeline/scripts/run_wgs.sh 并解析 TSV 写库。
    """
    task = None
    sample = None
    try:
        task = AnalysisTask.objects.select_related("sample").get(id=db_task_id)
    except AnalysisTask.DoesNotExist as e:
        return f"SKIP: {e}"

    if str(task.sample_id) != str(sample_id):
        logger.error(
            "run_hrd_analysis 参数与任务记录不一致: db_task_id=%s task.sample_id=%s sample_id=%s",
            db_task_id,
            task.sample_id,
            sample_id,
        )
        return "SKIP: sample_id mismatch"

    sample = task.sample

    err_tail = ""

    try:
        if sample.data_type != Sample.DataType.WGS:
            raise ValueError(
                "初版仅支持 WGS。当前样本数据类型为 "
                f"{sample.get_data_type_display()}，请待后续版本。"
            )

        task.status = AnalysisTask.Status.RUNNING
        task.started_at = timezone.now()
        task.save(update_fields=["status", "started_at", "updated_at"])

        sample.analysis_status = Sample.AnalysisStatus.RUNNING
        sample.save(update_fields=["analysis_status", "updated_at"])

        print(f"任务 [{task.id}] 开始 WGS 流程: {sample.sample_code}")
        result_data, pipe_log, result_tsv = run_wgs_for_sample(
            sample, analysis_task_id=task.id
        )
        log_tail = (pipe_log or "")[-12000:]

        with transaction.atomic():
            HRDResult.objects.update_or_create(
                sample=sample,
                defaults={
                    "hrd_score": result_data["hrd_score"],
                    "loh_score": result_data["loh_score"],
                    "tai_score": result_data["tai_score"],
                    "lst_score": result_data["lst_score"],
                    "brca_status": result_data["brca_status"],
                    "input_type": sample.data_type,
                    "pipeline_version": "wgs_v1_celery",
                    "analysis_date": timezone.now(),
                },
            )

            task.status = AnalysisTask.Status.SUCCESS
            task.finished_at = timezone.now()
            task.result_path = result_tsv
            task.log_output = log_tail
            task.error_message = ""
            task.save(
                update_fields=[
                    "status",
                    "finished_at",
                    "result_path",
                    "log_output",
                    "error_message",
                    "updated_at",
                ]
            )

            sample.analysis_status = Sample.AnalysisStatus.COMPLETED
            sample.save(update_fields=["analysis_status", "updated_at"])

        print(f"任务 [{task.id}] 完成，结果已入库。")
        return "SUCCESS"

    except Exception as e:
        err_tail = traceback.format_exc()[-2000:]
        if task:
            task.status = AnalysisTask.Status.FAILED
            task.finished_at = timezone.now()
            task.error_message = str(e)[:2000]
            task.log_output = (task.log_output or "") + "\n" + err_tail
            task.save(
                update_fields=[
                    "status",
                    "finished_at",
                    "error_message",
                    "log_output",
                    "updated_at",
                ]
            )
        if sample:
            sample.analysis_status = Sample.AnalysisStatus.FAILED
            sample.save(update_fields=["analysis_status", "updated_at"])
        print(f"任务 [{getattr(task, 'id', '?')}] 失败: {e}")
        return "FAILED"
