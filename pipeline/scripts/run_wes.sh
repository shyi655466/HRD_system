#!/usr/bin/env bash
set -euo pipefail

# WES 全流程：wes_upstream.sh（FASTQ→dedup BAM→Sequenza seqz）+ wes_downstream.R（scarHRD）
#
# 命令行与 run_wgs.sh 对齐，便于 Django 同一套参数约定：
#   -n <normal_prefix>  -t <tumor_prefix>  -p <pair_id>
#   -N <normal_sm> -T <tumor_sm> -a <normal_lb> -b <tumor_lb>
#
# 示例（test/SAMN29155878：SRR19858928 为肿瘤 -T，SRR19858929 为对照 -N）:
#   bash pipeline/scripts/run_wes.sh \
#     -n /path/to/pipeline/test/SAMN29155878/SRR19858929 \
#     -t /path/to/pipeline/test/SAMN29155878/SRR19858928 \
#     -p SAMN29155878 \
#     -N SRR19858929 -T SRR19858928 \
#     -a SRR19858929_lb -b SRR19858928_lb \
#     [-@ <threads>] [-r <ref_fa>] [-o <HRD_out_dir>] [-G <scarHRD_reference>]
#
# 未指定 -o 时，HRD 输出目录为: $(dirname <tumor_prefix>)/HRD_result
# 全流程 stdout/stderr 追加写入: $(dirname <tumor_prefix>)/run.log
# 若已由上游写入 run.log 前言，请设置 HRD_APPEND_LOG=1 避免清空该文件。
# Sequenza 输出前缀为: $(dirname <tumor_prefix>)/<pair_id>_wes_seqz
#
# 环境变量（可选）:
#   RSCRIPT — Rscript 可执行文件，默认 pipeline/envs/bin/Rscript
#
# 成功结束时打印: HRD_PIPELINE_RESULT_TSV=<path>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPSTREAM_SH="${SCRIPT_DIR}/wes_upstream.sh"
DOWNSTREAM_R="${SCRIPT_DIR}/wes_downstream.R"
RSCRIPT_CMD="${RSCRIPT:-${PIPELINE_ROOT}/envs/bin/Rscript}"

usage() {
  cat <<EOF
Usage:
  $0 -n <normal_prefix> -t <tumor_prefix> -p <pair_id> \\
     -N <normal_sm> -T <tumor_sm> -a <normal_lb> -b <tumor_lb> \\
     [-@ <threads>] [-r <ref_fa>] [-o <HRD_out_dir>] [-G <scarHRD_reference>]

  -h  显示帮助

说明:
  - prefix 为 FASTQ 路径前缀（不含 _1 / _2），与 wgs/wes upstream 一致
  - upstream 在 dedup BAM 或 *_small.seqz.gz 已存在时会跳过对应步骤
  - 若 <pair_id>_final_hrd_score.tsv 已存在，则跳过下游
EOF
  exit 1
}

abs_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p"
  else
    [[ -e "$p" ]] || { echo "Error: 路径不存在: $p" >&2; exit 1; }
    (cd "$(dirname "$p")" && echo "$(pwd)/$(basename "$p")")
  fi
}

run_downstream() {
  local small_seqz="$1"
  local sample_id="$2"
  local hrd_result_dir="$3"
  local scar_reference="${4:-}"
  local final_tsv="${hrd_result_dir}/${sample_id}_final_hrd_score.tsv"

  if [[ -f "${final_tsv}" ]]; then
    echo "[Skip] 已有 HRD 结果，跳过 wes_downstream.R: ${final_tsv}"
    echo "HRD_PIPELINE_RESULT_TSV=${final_tsv}"
    return 0
  fi

  [[ -f "${small_seqz}" ]] || { echo "Error: 未找到 small seqz: ${small_seqz}" >&2; exit 1; }
  [[ -f "${DOWNSTREAM_R}" ]] || { echo "Error: 未找到 ${DOWNSTREAM_R}" >&2; exit 1; }
  [[ -x "${RSCRIPT_CMD}" || -f "${RSCRIPT_CMD}" ]] || { echo "Error: Rscript 不可用: ${RSCRIPT_CMD}" >&2; exit 1; }

  mkdir -p "${hrd_result_dir}"
  echo "=========================================="
  echo "WES downstream (wes_downstream.R)"
  echo "Sample        : ${sample_id}"
  echo "Seqz (small)  : ${small_seqz}"
  echo "HRD dir       : ${hrd_result_dir}"
  echo "scarHRD ref   : ${scar_reference:-grch38(default)}"
  echo "=========================================="

  if [[ -n "${scar_reference}" ]]; then
    "${RSCRIPT_CMD}" "${DOWNSTREAM_R}" \
      "${small_seqz}" \
      "${sample_id}" \
      "${hrd_result_dir}" \
      "${scar_reference}"
  else
    "${RSCRIPT_CMD}" "${DOWNSTREAM_R}" \
      "${small_seqz}" \
      "${sample_id}" \
      "${hrd_result_dir}"
  fi

  [[ -f "${final_tsv}" ]] || { echo "Error: 未生成 ${final_tsv}" >&2; exit 1; }
  echo "HRD_PIPELINE_RESULT_TSV=${final_tsv}"
}

[[ "${1:-}" == "-h" ]] && usage

NORMAL_PREFIX=""
TUMOR_PREFIX=""
PAIR_ID=""
NORMAL_SM=""
TUMOR_SM=""
NORMAL_LB=""
TUMOR_LB=""
THREADS=""
REF_FA=""
HRD_OUT=""
SCAR_REF=""

while getopts "n:t:p:N:T:a:b:@:r:o:G:h" opt; do
  case $opt in
    n) NORMAL_PREFIX="$OPTARG" ;;
    t) TUMOR_PREFIX="$OPTARG" ;;
    p) PAIR_ID="$OPTARG" ;;
    N) NORMAL_SM="$OPTARG" ;;
    T) TUMOR_SM="$OPTARG" ;;
    a) NORMAL_LB="$OPTARG" ;;
    b) TUMOR_LB="$OPTARG" ;;
    @) THREADS="$OPTARG" ;;
    r) REF_FA="$OPTARG" ;;
    o) HRD_OUT="$OPTARG" ;;
    G) SCAR_REF="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "${NORMAL_PREFIX}" || -z "${TUMOR_PREFIX}" || -z "${PAIR_ID}" || \
      -z "${NORMAL_SM}" || -z "${TUMOR_SM}" || \
      -z "${NORMAL_LB}" || -z "${TUMOR_LB}" ]]; then
  echo "Error: 缺少必要参数" >&2
  usage
fi

[[ -f "${UPSTREAM_SH}" ]] || { echo "Error: 未找到 ${UPSTREAM_SH}" >&2; exit 1; }

TUMOR_PREFIX="$(abs_path "${TUMOR_PREFIX}")"
NORMAL_PREFIX="$(abs_path "${NORMAL_PREFIX}")"
WORK_DIR="$(dirname "${TUMOR_PREFIX}")"
SEQZ_PREFIX="${WORK_DIR}/${PAIR_ID}_wes_seqz"

LOG_PATH="${WORK_DIR}/run.log"
mkdir -p "${WORK_DIR}"
if [[ -z "${HRD_APPEND_LOG:-}" ]]; then
  : > "${LOG_PATH}"
fi
exec > >(tee -a "${LOG_PATH}") 2>&1

echo "=== HRD WES run log (bash) ==="
echo "log_file: ${LOG_PATH}"
echo "started_at: $(date -Iseconds 2>/dev/null || date)"

UP_ARGS=(
  -T "${TUMOR_PREFIX}"
  -N "${NORMAL_PREFIX}"
  -a "${TUMOR_SM}"
  -b "${TUMOR_LB}"
  -c "${NORMAL_SM}"
  -d "${NORMAL_LB}"
  -o "${SEQZ_PREFIX}"
)
[[ -n "${THREADS}" ]] && UP_ARGS+=(-t "${THREADS}")
[[ -n "${REF_FA}" ]] && UP_ARGS+=(-r "${REF_FA}")

echo "=========================================="
echo "WES full pipeline: upstream + downstream"
echo "Pair ID     : ${PAIR_ID}"
echo "Seqz prefix : ${SEQZ_PREFIX}"
echo "=========================================="

bash "${UPSTREAM_SH}" "${UP_ARGS[@]}"

SMALL_SEQZ="${SEQZ_PREFIX}_small.seqz.gz"
[[ -f "${SMALL_SEQZ}" ]] || { echo "Error: 上游未生成 ${SMALL_SEQZ}" >&2; exit 1; }

if [[ -z "${HRD_OUT}" ]]; then
  HRD_OUT="${WORK_DIR}/HRD_result"
else
  mkdir -p "${HRD_OUT}"
  HRD_OUT="$(abs_path "${HRD_OUT}")"
fi

run_downstream "${SMALL_SEQZ}" "${PAIR_ID}" "${HRD_OUT}" "${SCAR_REF}"
