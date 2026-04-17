"""
WGS HRD 流程编排：准备工作目录、调用 run_wgs.sh、解析 *_final_hrd_score.tsv。
"""
from __future__ import annotations

import csv
import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Any

from django.conf import settings
from django.utils import timezone

from .models import HRDResult, Sample, SampleFile


def _repo_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def pipeline_scripts_dir() -> Path:
    root = getattr(settings, "HRD_PIPELINE_ROOT", None)
    if root:
        return Path(root) / "scripts"
    return _repo_root() / "pipeline" / "scripts"


def pipeline_work_root() -> Path:
    root = getattr(settings, "HRD_PIPELINE_WORK_ROOT", None)
    if root:
        return Path(root)
    return _repo_root() / "pipeline" / "work"


def sanitize_pair_id(sample: Sample) -> str:
    raw = (sample.sample_code or "").strip() or str(sample.id)
    s = re.sub(r"[^A-Za-z0-9._-]+", "_", raw).strip("._-")
    return (s or str(sample.id))[:120]


def _upstream_read_suffix(src: Path) -> str:
    """
    wgs_upstream 依次查找 prefix_1.fastq与 prefix_1.fastq.gz。
    链接名必须与真实压缩格式一致：未压缩却使用 .fastq.gz 会导致 fastp/igzip 报 invalid gzip header。
    """
    name = src.name.lower()
    if name.endswith(".gz") or name.endswith(".bgz"):
        return ".fastq.gz"
    return ".fastq"


def _safe_symlink(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    src_r = src.resolve()
    if not src_r.is_file():
        raise FileNotFoundError(f"FASTQ 不存在或不是文件: {src_r}")
    if dst.is_symlink() or dst.exists():
        dst.unlink()
    dst.symlink_to(src_r)


def collect_fastq_by_role(sample: Sample) -> dict[str, str]:
    roles = (
        SampleFile.FileRole.TUMOR_R1,
        SampleFile.FileRole.TUMOR_R2,
        SampleFile.FileRole.NORMAL_R1,
        SampleFile.FileRole.NORMAL_R2,
    )
    out: dict[str, str] = {}
    for sf in SampleFile.objects.filter(sample=sample, file_role__in=roles):
        p = (sf.storage_path or "").strip()
        if not p:
            raise ValueError(f"文件角色 {sf.file_role} 缺少 storage_path")
        out[sf.file_role] = p
    for r in roles:
        if r not in out:
            raise ValueError(f"缺少必需文件角色: {r}")
    return out


def prepare_wgs_workdir(sample: Sample, paths: dict[str, str]) -> tuple[Path, str, str]:
    """
    在 work 目录下创建 normal/tumor 前缀及 _1/_2 的符号链接（扩展名随源文件是否 gzip 而定），
    命名约定与 wgs_upstream.sh 一致。
    返回 (work_dir, normal_prefix, tumor_prefix)，前缀为绝对路径字符串且无后缀。
    """
    work_dir = pipeline_work_root() / str(sample.id)
    work_dir.mkdir(parents=True, exist_ok=True)

    normal_base = work_dir / "normal"
    tumor_base = work_dir / "tumor"
    normal_prefix = str(normal_base.resolve())
    tumor_prefix = str(tumor_base.resolve())

    n1 = Path(paths[SampleFile.FileRole.NORMAL_R1])
    n2 = Path(paths[SampleFile.FileRole.NORMAL_R2])
    t1 = Path(paths[SampleFile.FileRole.TUMOR_R1])
    t2 = Path(paths[SampleFile.FileRole.TUMOR_R2])
    _safe_symlink(n1, work_dir / f"normal_1{_upstream_read_suffix(n1)}")
    _safe_symlink(n2, work_dir / f"normal_2{_upstream_read_suffix(n2)}")
    _safe_symlink(t1, work_dir / f"tumor_1{_upstream_read_suffix(t1)}")
    _safe_symlink(t2, work_dir / f"tumor_2{_upstream_read_suffix(t2)}")

    return work_dir, normal_prefix, tumor_prefix


def parse_final_hrd_tsv(tsv_path: Path) -> dict[str, Any]:
    with tsv_path.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f, delimiter="\t")
        row = next(reader, None)
    if not row:
        raise ValueError(f"HRD TSV 无数据行: {tsv_path}")

    norm = {k.strip().lower(): (k, v) for k, v in row.items() if k}

    def get_val(*names: str) -> str:
        for n in names:
            key = n.lower()
            if key in norm:
                return (norm[key][1] or "").strip()
        raise KeyError(f"TSV 缺少列: {names}")

    def get_float(*names: str) -> float:
        return float(get_val(*names))

    def get_int(*names: str) -> int:
        return int(float(get_val(*names)))

    return {
        "hrd_score": get_float("hrd_score", "hrdscore"),
        "loh_score": get_int("loh"),
        "tai_score": get_int("tai"),
        "lst_score": get_int("lst"),
    }


def run_wgs_for_sample(
    sample: Sample,
    *,
    analysis_task_id: int | None = None,
) -> tuple[dict[str, Any], str, str]:
    """
    执行 WGS 全流程。返回 (result_dict_for_HRDResult, combined_log, result_tsv_path)。
    子进程 stdout/stderr 实时写入 work_dir/run.log，便于 tail 与排障。
    """
    paths = collect_fastq_by_role(sample)
    work_dir, normal_prefix, tumor_prefix = prepare_wgs_workdir(sample, paths)
    pair_id = sanitize_pair_id(sample)
    hrd_out = work_dir / "hrd_out"
    hrd_out.mkdir(parents=True, exist_ok=True)

    run_sh = pipeline_scripts_dir() / "run_wgs.sh"
    if not run_sh.is_file():
        raise FileNotFoundError(f"未找到 run_wgs.sh: {run_sh}")

    env = os.environ.copy()
    rscript = getattr(settings, "HRD_RSCRIPT", None)
    if rscript:
        env["RSCRIPT"] = rscript

    cmd: list[str] = [
        "/bin/bash",
        str(run_sh),
        "-n",
        normal_prefix,
        "-t",
        tumor_prefix,
        "-p",
        pair_id,
        "-N",
        f"{sample.sample_code}_normal",
        "-T",
        f"{sample.sample_code}_tumor",
        "-a",
        f"{sample.sample_code}_normal_lb",
        "-b",
        f"{sample.sample_code}_tumor_lb",
        "-o",
        str(hrd_out.resolve()),
    ]
    threads = getattr(settings, "HRD_WGS_THREADS", None)
    if threads:
        cmd.extend(["-@", str(threads)])
    ref_fa = getattr(settings, "HRD_WGS_REF_FA", None)
    if ref_fa:
        cmd.extend(["-r", str(ref_fa)])

    log_path = work_dir / "run.log"
    cmd_line = " ".join(shlex.quote(c) for c in cmd)
    with open(log_path, "w", encoding="utf-8") as logf:
        logf.write("=== HRD WGS run log ===\n")
        logf.write(f"started_at: {timezone.now().isoformat()}\n")
        logf.write(f"sample_uuid: {sample.id}\n")
        logf.write(f"sample_code: {sample.sample_code}\n")
        if analysis_task_id is not None:
            logf.write(f"analysis_task_id: {analysis_task_id}\n")
        logf.write(f"log_file: {log_path.resolve()}\n")
        logf.write("--- command ---\n")
        logf.write(cmd_line + "\n")
        logf.write("--- pipeline output ---\n")
        logf.flush()

        run_kw: dict = dict(
            cwd=str(pipeline_scripts_dir().parent),
            env=env,
            stdout=logf,
            stderr=subprocess.STDOUT,
            text=True,
        )
        _timeout = getattr(settings, "HRD_WGS_SUBPROCESS_TIMEOUT", None)
        if _timeout and _timeout > 0:
            run_kw["timeout"] = _timeout
        proc = subprocess.run(cmd, **run_kw)

    log = log_path.read_text(encoding="utf-8")
    if proc.returncode != 0:
        raise RuntimeError(
            f"run_wgs.sh 退出码 {proc.returncode}，完整日志: {log_path}\n{log[-8000:]}"
        )

    result_line = None
    for line in log.splitlines():
        if line.startswith("HRD_PIPELINE_RESULT_TSV="):
            result_line = line.strip()
            break
    tsv_str: str | None = None
    if result_line:
        _, _, rest = result_line.partition("=")
        tsv_str = rest.strip() or None
    if not tsv_str:
        cand = hrd_out / f"{pair_id}_final_hrd_score.tsv"
        if cand.is_file():
            tsv_str = str(cand.resolve())
    if not tsv_str:
        raise RuntimeError(f"未能解析 HRD 结果 TSV 路径。日志尾部:\n{log[-4000:]}")

    tsv_path = Path(tsv_str)
    if not tsv_path.is_file():
        raise FileNotFoundError(f"HRD 结果文件不存在: {tsv_path}")

    scores = parse_final_hrd_tsv(tsv_path)
    scores["brca_status"] = HRDResult.BRCAStatus.UNKNOWN
    return scores, log, str(tsv_path.resolve())
