#!/usr/bin/env bash
set -euo pipefail

# WGS 全流程：wgs_upstream.sh（FASTQ→dedup BAM，按步骤跳过已有产物）+ wgs_downstream.R（ASCAT + scarHRD）
# 已有 dedup BAM 或已有最终 HRD TSV 时，重复运行会自动跳过对应阶段，无需单独「仅下游」入口。
#
# 用法（与 wgs_upstream.sh 一致，额外 -o 指定 HRD 输出目录）:
#   bash pipeline/scripts/run_wgs.sh \
#     -n <normal_prefix> -t <tumor_prefix> -p <pair_id> \
#     -N <normal_sm> -T <tumor_sm> -a <normal_lb> -b <tumor_lb> \
#     [-@ <threads>] [-r <ref_fa>] [-o <hrd_out_dir>]
#
# 未指定 -o 时，HRD 目录默认为: $(dirname <tumor.dedup.bam>)/HRD_result
#
# 环境变量（可选）:
#   RSCRIPT  — Rscript 可执行文件，默认 pipeline/envs/bin/Rscript
#
# 成功结束时打印: HRD_PIPELINE_RESULT_TSV=<path>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPSTREAM_SH="${SCRIPT_DIR}/wgs_upstream.sh"
DOWNSTREAM_R="${SCRIPT_DIR}/wgs_downstream.R"
RSCRIPT_CMD="${RSCRIPT:-${PIPELINE_ROOT}/envs/bin/Rscript}"

usage() {
  cat <<EOF
Usage:
  $0 -n <normal_prefix> -t <tumor_prefix> -p <pair_id> \\
     -N <normal_sm> -T <tumor_sm> -a <normal_lb> -b <tumor_lb> \\
     [-@ <threads>] [-r <ref_fa>] [-o <hrd_out_dir>]

  -h  显示帮助

说明:
  - upstream 按步跳过：clean FASTQ / sorted.bam / dedup.bam 已存在则不再跑该步
  - 若两路 dedup BAM 已齐，仅会跳过上游并进入下游
  - 若 <sample_id>_final_hrd_score.tsv 已存在，则跳过下游
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
  local tumor_bam="$1"
  local normal_bam="$2"
  local sample_id="$3"
  local hrd_out="$4"
  local final_tsv="${hrd_out}/${sample_id}_final_hrd_score.tsv"

  if [[ -f "${final_tsv}" ]]; then
    echo "[Skip] 已有 HRD 结果，跳过 wgs_downstream.R: ${final_tsv}"
    echo "HRD_PIPELINE_RESULT_TSV=${final_tsv}"
    return 0
  fi

  [[ -f "${DOWNSTREAM_R}" ]] || { echo "Error: 未找到 ${DOWNSTREAM_R}" >&2; exit 1; }
  [[ -x "${RSCRIPT_CMD}" || -f "${RSCRIPT_CMD}" ]] || { echo "Error: Rscript 不可用: ${RSCRIPT_CMD}" >&2; exit 1; }

  mkdir -p "${hrd_out}"
  echo "=========================================="
  echo "WGS downstream (wgs_downstream.R)"
  echo "Sample   : ${sample_id}"
  echo "Tumor BAM: ${tumor_bam}"
  echo "Normal   : ${normal_bam}"
  echo "HRD out  : ${hrd_out}"
  echo "=========================================="

  "${RSCRIPT_CMD}" "${DOWNSTREAM_R}" \
    "${tumor_bam}" \
    "${normal_bam}" \
    "${sample_id}" \
    "${hrd_out}"

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

while getopts "n:t:p:N:T:a:b:@:r:o:h" opt; do
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

UP_ARGS=(
  -n "${NORMAL_PREFIX}"
  -t "${TUMOR_PREFIX}"
  -p "${PAIR_ID}"
  -N "${NORMAL_SM}"
  -T "${TUMOR_SM}"
  -a "${NORMAL_LB}"
  -b "${TUMOR_LB}"
)
[[ -n "${THREADS}" ]] && UP_ARGS+=(-@ "${THREADS}")
[[ -n "${REF_FA}" ]] && UP_ARGS+=(-r "${REF_FA}")

echo "=========================================="
echo "WGS full pipeline: upstream + downstream"
echo "Pair ID : ${PAIR_ID}"
echo "=========================================="

bash "${UPSTREAM_SH}" "${UP_ARGS[@]}"

TUMOR_BAM="${TUMOR_PREFIX}.dedup.bam"
NORMAL_BAM="${NORMAL_PREFIX}.dedup.bam"

TUMOR_BAM="$(abs_path "${TUMOR_BAM}")"
NORMAL_BAM="$(abs_path "${NORMAL_BAM}")"

if [[ -z "${HRD_OUT}" ]]; then
  HRD_OUT="$(dirname "${TUMOR_BAM}")/HRD_result"
else
  mkdir -p "${HRD_OUT}"
  HRD_OUT="$(abs_path "${HRD_OUT}")"
fi

run_downstream "${TUMOR_BAM}" "${NORMAL_BAM}" "${PAIR_ID}" "${HRD_OUT}"
