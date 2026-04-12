# analysis/tasks.py
import time
import traceback
from celery import shared_task
from django.db import transaction
from django.utils import timezone

from .models import Sample, AnalysisTask, HRDResult


@shared_task
def run_hrd_analysis(db_task_id, sample_id):
    """
    异步 HRD 分析：仅在此任务内调用命令行/R 脚本并写库（V1 为模拟耗时与结果）。
    """
    task = None
    sample = None
    try:
        task = AnalysisTask.objects.select_related("sample").get(id=db_task_id)
        sample = Sample.objects.get(id=sample_id)
    except (AnalysisTask.DoesNotExist, Sample.DoesNotExist) as e:
        return f"SKIP: {e}"

    err_tail = ""

    try:
        task.status = AnalysisTask.Status.RUNNING
        task.started_at = timezone.now()
        task.save(update_fields=["status", "started_at", "updated_at"])

        sample.analysis_status = Sample.AnalysisStatus.RUNNING
        sample.save(update_fields=["analysis_status", "updated_at"])

        # ====== 未来：在此调用生信命令行 / R 脚本 ======
        print(f"任务 [{task.id}] 开始处理样本: {sample.sample_code}")
        time.sleep(15)

        mock_result_data = {
            "hrd_score": 68.5,
            "loh_score": 25,
            "tai_score": 25,
            "lst_score": 18,
            "brca_status": HRDResult.BRCAStatus.NEGATIVE,
        }
        # ===============================================

        with transaction.atomic():
            HRDResult.objects.update_or_create(
                sample=sample,
                defaults={
                    **mock_result_data,
                    "input_type": sample.data_type,
                    "analysis_date": timezone.now(),
                },
            )

            task.status = AnalysisTask.Status.SUCCESS
            task.finished_at = timezone.now()
            task.log_output = "Analysis completed successfully."
            task.error_message = ""
            task.save(
                update_fields=[
                    "status",
                    "finished_at",
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
