"""
清理未结束的分析任务（PENDING / QUEUED / RUNNING），并同步样本状态与 HRD 结果。

用于在更换机器、重启 worker 或排查卡住任务前，清理队列中/进行中的分析相关 DB 记录，
避免前端仍显示「分析中」或残留不完整结果。
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from analysis.models import AnalysisTask, HRDResult, Sample


WIP_STATUSES = (
    AnalysisTask.Status.PENDING,
    AnalysisTask.Status.QUEUED,
    AnalysisTask.Status.RUNNING,
)


def _sync_sample_analysis_status(sample):
    """根据剩余任务记录推断样本分析状态。"""
    qs = sample.analysis_tasks.filter(task_type=AnalysisTask.TaskType.HRD_ANALYSIS)
    if qs.filter(status=AnalysisTask.Status.SUCCESS).exists():
        sample.analysis_status = Sample.AnalysisStatus.COMPLETED
    elif qs.filter(status=AnalysisTask.Status.FAILED).exists():
        sample.analysis_status = Sample.AnalysisStatus.FAILED
    else:
        sample.analysis_status = Sample.AnalysisStatus.NOT_STARTED
    sample.save(update_fields=["analysis_status", "updated_at"])


class Command(BaseCommand):
    help = (
        "删除状态为 PENDING/QUEUED/RUNNING 的 AnalysisTask；"
        "对涉及样本：若无已成功 HRD 任务则删除 HRDResult，并重算 analysis_status。"
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="只打印将删除/更新的数量，不写数据库",
        )
        parser.add_argument(
            "--sample-id",
            dest="sample_id",
            default=None,
            help="仅清理该样本 UUID 下的进行中任务（适合 Celery 重启后单个样本卡在「分析中」）",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        sample_filter = options.get("sample_id")
        wip = AnalysisTask.objects.filter(status__in=WIP_STATUSES)
        if sample_filter:
            wip = wip.filter(sample_id=sample_filter)
            if not wip.exists() and not dry_run:
                self.stdout.write(
                    self.style.WARNING(
                        f"样本 {sample_filter} 下无 PENDING/QUEUED/RUNNING 任务，无需清理"
                    )
                )
                return
        sample_ids = list(wip.values_list("sample_id", flat=True).distinct())
        n_tasks = wip.count()

        self.stdout.write(
            f"进行中任务数: {n_tasks}，涉及样本数: {len(sample_ids)}"
        )
        if dry_run:
            for sid in sample_ids[:50]:
                self.stdout.write(f"  sample_id={sid}")
            if len(sample_ids) > 50:
                self.stdout.write(f"  ... 另有 {len(sample_ids) - 50} 个样本")
            self.stdout.write(self.style.WARNING("dry-run，未修改数据库"))
            return

        if n_tasks == 0:
            self.stdout.write(self.style.SUCCESS("无进行中任务，无需清理"))
            return

        with transaction.atomic():
            wip.delete()

            for sid in sample_ids:
                sample = Sample.objects.select_for_update().get(pk=sid)
                has_success = sample.analysis_tasks.filter(
                    task_type=AnalysisTask.TaskType.HRD_ANALYSIS,
                    status=AnalysisTask.Status.SUCCESS,
                ).exists()
                if not has_success:
                    deleted_hrd, _ = HRDResult.objects.filter(sample=sample).delete()
                    if deleted_hrd:
                        self.stdout.write(
                            f"  已删除样本 {sample.sample_code} 的 HRD 结果记录"
                        )
                _sync_sample_analysis_status(sample)
                self.stdout.write(
                    f"  样本 {sample.sample_code} -> {sample.analysis_status}"
                )

        self.stdout.write(
            self.style.SUCCESS(f"完成：已删除 {n_tasks} 条进行中任务，已处理 {len(sample_ids)} 个样本")
        )
        self.stdout.write(
            "提示：若 Celery/Redis 里仍有旧消息，请在 worker 侧执行 "
            "`celery -A backend purge` 或重启 broker/worker，以免旧任务仍被执行。"
        )
