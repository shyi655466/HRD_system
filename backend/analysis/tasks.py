# analysis/tasks.py
import traceback
from celery import shared_task
from django.db import transaction
from django.utils import timezone

from utils.logger import logger

from .hrd_pipeline import run_wes_for_sample, run_wgs_for_sample, sample_hrd_result_dir
from .models import Sample, AnalysisTask, HRDResult
from .report_html import build_hrd_report_html


@shared_task
def run_hrd_analysis(db_task_id, sample_id):
    """
    异步 HRD 分析：WGS 调用 run_wgs.sh，WES 调用 run_wes.sh，解析 TSV 写库。
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
        if sample.data_type not in (
            Sample.DataType.WGS,
            Sample.DataType.WES,
        ):
            raise ValueError(
                "仅支持 WGS / WES 分析。当前样本数据类型为 "
                f"{sample.get_data_type_display()}。"
            )

        task.status = AnalysisTask.Status.RUNNING
        task.started_at = timezone.now()
        task.save(update_fields=["status", "started_at", "updated_at"])

        sample.analysis_status = Sample.AnalysisStatus.RUNNING
        sample.save(update_fields=["analysis_status", "updated_at"])

        if sample.data_type == Sample.DataType.WGS:
            print(f"任务 [{task.id}] 开始 WGS 流程: {sample.sample_code}")
            result_data, pipe_log, result_tsv = run_wgs_for_sample(
                sample, analysis_task_id=task.id
            )
            pipeline_version = "wgs_v1_celery"
        else:
            print(f"任务 [{task.id}] 开始 WES 流程: {sample.sample_code}")
            result_data, pipe_log, result_tsv = run_wes_for_sample(
                sample, analysis_task_id=task.id
            )
            pipeline_version = "wes_v1_celery"

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
                    "pipeline_version": pipeline_version,
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

            sid = str(sample.id)
            transaction.on_commit(lambda s=sid: generate_hrd_report_task.delay(s))

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


REPORT_FILENAME = "HRD_report.html"


@shared_task(bind=True, name="analysis.generate_hrd_report_task")
def generate_hrd_report_task(self, sample_id: str):
    """
    HRD 分析成功后异步生成静态 HTML 报告，写入 pipeline/work/<UUID>/HRD_result/HRD_report.html，
    并更新 HRDResult.report_path；同时写入一条 REPORT_GENERATE 类型的 AnalysisTask 记录。
    """
    celery_id = ""
    try:
        rid = getattr(self.request, "id", None)
        celery_id = str(rid) if rid is not None else ""
    except Exception:
        celery_id = ""

    db_task = None
    try:
        sample = Sample.objects.select_related("hrd_result").get(pk=sample_id)
    except Sample.DoesNotExist:
        logger.error("generate_hrd_report_task: 样本不存在 sample_id=%s", sample_id)
        return "SKIP: sample not found"

    result = getattr(sample, "hrd_result", None)
    if result is None:
        logger.warning("generate_hrd_report_task: 无 HRD 结果，跳过 sample_id=%s", sample_id)
        return "SKIP: no hrd_result"

    db_task = AnalysisTask.objects.create(
        sample=sample,
        task_type=AnalysisTask.TaskType.REPORT_GENERATE,
        status=AnalysisTask.Status.RUNNING,
        started_at=timezone.now(),
        celery_task_id=celery_id,
        parameters={"output": REPORT_FILENAME},
    )

    log_lines: list[str] = []
    try:
        hrd_result_dir = sample_hrd_result_dir(sample)
        out_path = hrd_result_dir / REPORT_FILENAME
        html_doc = build_hrd_report_html(sample, result)
        out_path.write_text(html_doc, encoding="utf-8")
        abs_path = str(out_path.resolve())
        log_lines.append(f"written: {abs_path}")

        HRDResult.objects.filter(pk=result.pk).update(report_path=abs_path)

        db_task.status = AnalysisTask.Status.SUCCESS
        db_task.finished_at = timezone.now()
        db_task.result_path = abs_path
        db_task.log_output = "\n".join(log_lines)
        db_task.error_message = ""
        db_task.save(
            update_fields=[
                "status",
                "finished_at",
                "result_path",
                "log_output",
                "error_message",
                "updated_at",
            ]
        )
        logger.info("HRD 报告已生成 sample_id=%s path=%s", sample_id, abs_path)
        return "SUCCESS"

    except Exception as e:
        err = traceback.format_exc()[-4000:]
        logger.exception("generate_hrd_report_task 失败 sample_id=%s", sample_id)
        if db_task:
            db_task.status = AnalysisTask.Status.FAILED
            db_task.finished_at = timezone.now()
            db_task.error_message = str(e)[:2000]
            db_task.log_output = "\n".join(log_lines) + "\n" + err
            db_task.save(
                update_fields=[
                    "status",
                    "finished_at",
                    "error_message",
                    "log_output",
                    "updated_at",
                ]
            )
        return "FAILED"
