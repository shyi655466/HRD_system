"""
管线已在磁盘产出 *_final_hrd_score.tsv，但 Celery/MySQL 中断导致库中仍为「分析中」时：
从 TSV 同步 HRDResult，将未结束的 HRD/报告任务 **更新** 为终态（不删行、不删 work 目录），
并把样本标为已完成。可选排队生成 HRD_report.html。

与 clear_analysis 的区别：不删除 AnalysisTask / HRDResult / 磁盘进度。
"""

from __future__ import annotations

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from analysis.hrd_pipeline import (
    brca_status_from_hrd_score,
    parse_final_hrd_tsv,
    sample_hrd_result_dir,
    sanitize_pair_id,
)
from analysis.models import AnalysisTask, HRDResult, Sample

WIP = (
    AnalysisTask.Status.PENDING,
    AnalysisTask.Status.QUEUED,
    AnalysisTask.Status.RUNNING,
)


def _find_result_tsv(sample: Sample) -> Path:
    pair_id = sanitize_pair_id(sample)
    hrd_dir = sample_hrd_result_dir(sample)
    primary = hrd_dir / f"{pair_id}_final_hrd_score.tsv"
    if primary.is_file():
        return primary.resolve()
    matches = sorted(hrd_dir.glob("*_final_hrd_score.tsv"))
    if len(matches) == 1:
        return matches[0].resolve()
    if not matches:
        raise CommandError(
            f"未在 {hrd_dir} 找到 *_final_hrd_score.tsv（已试 {primary.name}）。"
        )
    raise CommandError(
        f"{hrd_dir} 下有多份结果 TSV，请只保留一份或修正 pair_id 命名: "
        + ", ".join(m.name for m in matches[:10])
    )


class Command(BaseCommand):
    help = (
        "从 pipeline/work/<样本UUID>/HRD_result/ 的 TSV 回填 HRDResult，"
        "并将卡住的 HRD/报告任务更新为终态（不删除任务行与磁盘文件）。"
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--sample-id",
            dest="sample_id",
            required=True,
            help="样本 UUID（与 pipeline/work 下目录名一致）",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="只打印将执行的操作，不写库",
        )
        parser.add_argument(
            "--enqueue-report",
            action="store_true",
            help="完成后异步排队 generate_hrd_report_task（生成 HRD_report.html）",
        )
        parser.add_argument(
            "--from-hrd-result-only",
            action="store_true",
            help="不读 TSV：仅在已存在 HRDResult 时，把卡住任务与样本状态收束为已完成",
        )

    def handle(self, *args, **options):
        sample_id = options["sample_id"]
        dry = options["dry_run"]
        enqueue_report = options["enqueue_report"]
        from_db_only = options["from_hrd_result_only"]

        try:
            sample = Sample.objects.get(pk=sample_id)
        except Sample.DoesNotExist as e:
            raise CommandError(f"样本不存在: {sample_id}") from e

        tsv_path: Path | None = None
        scores: dict | None = None

        if from_db_only:
            r = HRDResult.objects.filter(sample=sample).first()
            if r is None:
                raise CommandError(
                    "未找到 HRDResult，无法使用 --from-hrd-result-only；请去掉该参数以从 TSV 同步。"
                )
            scores = {
                "hrd_score": float(r.hrd_score),
                "loh_score": int(r.loh_score),
                "tai_score": int(r.tai_score),
                "lst_score": int(r.lst_score),
                "brca_status": r.brca_status,
            }
            self.stdout.write("使用库中已有 HRDResult，不读取 TSV。")
        else:
            tsv_path = _find_result_tsv(sample)
            scores = parse_final_hrd_tsv(tsv_path)
            scores["brca_status"] = brca_status_from_hrd_score(scores["hrd_score"])
            self.stdout.write(f"将读取: {tsv_path}")

        pver = (
            "wgs_recovered_disk"
            if sample.data_type == Sample.DataType.WGS
            else "wes_recovered_disk"
        )

        wip_hrd = sample.analysis_tasks.filter(
            task_type=AnalysisTask.TaskType.HRD_ANALYSIS,
            status__in=WIP,
        ).order_by("-id")
        wip_rep = sample.analysis_tasks.filter(
            task_type=AnalysisTask.TaskType.REPORT_GENERATE,
            status__in=WIP,
        ).order_by("-id")

        self.stdout.write(
            f"样本 {sample.sample_code}: 待收尾 HRD 任务 {wip_hrd.count()} 条，"
            f"未结束报告任务 {wip_rep.count()} 条；当前 analysis_status={sample.analysis_status}"
        )

        if dry:
            self.stdout.write(self.style.WARNING("dry-run，未修改数据库"))
            return

        now = timezone.now()

        hrd_defaults = {
            "hrd_score": scores["hrd_score"],
            "loh_score": scores["loh_score"],
            "tai_score": scores["tai_score"],
            "lst_score": scores["lst_score"],
            "brca_status": scores["brca_status"],
            "input_type": sample.data_type,
        }
        if not from_db_only:
            hrd_defaults["pipeline_version"] = pver
            hrd_defaults["analysis_date"] = now

        with transaction.atomic():
            HRDResult.objects.update_or_create(sample=sample, defaults=hrd_defaults)

            if wip_hrd.exists():
                keep = wip_hrd.first()
                keep.status = AnalysisTask.Status.SUCCESS
                keep.finished_at = now
                keep.error_message = ""
                if tsv_path is not None:
                    keep.result_path = str(tsv_path)
                note = (
                    "[recover_sample_hrd_from_disk] "
                    + (
                        "从磁盘 TSV 同步入库并收束卡住状态。"
                        if tsv_path is not None
                        else "库中已有 HRDResult，仅收束卡住任务状态。"
                    )
                )
                keep.log_output = (keep.log_output or "")[-8000:] + "\n" + note
                uf = [
                    "status",
                    "finished_at",
                    "error_message",
                    "log_output",
                    "updated_at",
                ]
                if tsv_path is not None:
                    uf.insert(2, "result_path")
                keep.save(update_fields=uf)
                tail_msg = (
                    "同源样本上另一条未结束的 HRD 任务，已由 recover 收束。"
                )
                for t in wip_hrd.exclude(pk=keep.pk):
                    t.status = AnalysisTask.Status.FAILED
                    t.finished_at = now
                    t.error_message = tail_msg[:2000]
                    t.save(
                        update_fields=[
                            "status",
                            "finished_at",
                            "error_message",
                            "updated_at",
                        ]
                    )

            if enqueue_report:
                rep_msg = "未结束的报告任务已标记失败；recover 已排队重新生成 HTML 报告。"
            else:
                rep_msg = (
                    "未结束的报告任务已标记失败；可对本命令加 --enqueue-report "
                    "以排队生成 HRD_report.html。"
                )
            for t in wip_rep:
                t.status = AnalysisTask.Status.FAILED
                t.finished_at = now
                t.error_message = rep_msg[:2000]
                t.save(
                    update_fields=[
                        "status",
                        "finished_at",
                        "error_message",
                        "updated_at",
                    ]
                )

            sample.analysis_status = Sample.AnalysisStatus.COMPLETED
            sample.save(update_fields=["analysis_status", "updated_at"])

        self.stdout.write(self.style.SUCCESS("已写入 HRDResult，样本状态为 COMPLETED。"))

        if enqueue_report:
            from analysis.tasks import generate_hrd_report_task

            generate_hrd_report_task.delay(str(sample.id))
            self.stdout.write("已排队 generate_hrd_report_task。")
