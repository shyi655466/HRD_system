#!/usr/bin/env bash
set -euo pipefail

# 20260321 单对样本 WGS upstream
# 优先复用旧目录中的 dedup BAM；若不可复用则从 FASTQ 重新处理
#
# 用法:
#   bash pipeline/scripts/wgs_upstream_20260321.sh \
#     [pair_id] [tumor_r1] [tumor_r2] [normal_r1] [normal_r2] [run_root] [threads] [reuse_dir]
#
# 当能在 reuse_dir 找到 <pair_id小写>.tumor/normal.dedup.bam 时，不要求 FASTQ 参数

PAIR_ID="${1:-P13}"
TUMOR_R1="${2:-}"
TUMOR_R2="${3:-}"
NORMAL_R1="${4:-}"
NORMAL_R2="${5:-}"
RUN_ROOT="${6:-/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/wgs_run_20260321}"
THREADS="${7:-8}"
PAIR_ID_LOWER="$(echo "${PAIR_ID}" | tr '[:upper:]' '[:lower:]')"
REUSE_DIR="${8:-/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/${PAIR_ID_LOWER}}"
FASTP_TIMEOUT_SEC="${FASTP_TIMEOUT_SEC:-14400}"

REF_FA="/data/database/hg38/hg38.fa"
FASTP_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/fastp"
BWA_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/bwa"
SAMTOOLS_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/samtools"
JAVA_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/java"
PICARD_JAR="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/share/picard-3.4.0-0/picard.jar"
RG_PL="ILLUMINA"

check_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Error: 文件不存在: $f" >&2; exit 1; }
}

has_bam_index() {
  local bam="$1"
  [[ -f "${bam}.bai" || -f "${bam%.bam}.bai" ]]
}

link_bam_and_index() {
  local src_bam="$1"
  local dst_bam="$2"
  mkdir -p "$(dirname "${dst_bam}")"
  ln -sf "${src_bam}" "${dst_bam}"
  if [[ -f "${src_bam}.bai" ]]; then
    ln -sf "${src_bam}.bai" "${dst_bam}.bai"
  elif [[ -f "${src_bam%.bam}.bai" ]]; then
    ln -sf "${src_bam%.bam}.bai" "${dst_bam}.bai"
  fi
}

try_reuse_previous_pair() {
  local out_dir="${RUN_ROOT}/${PAIR_ID}"
  local tumor_bam="${out_dir}/tumor.dedup.bam"
  local normal_bam="${out_dir}/normal.dedup.bam"

  if [[ -f "${tumor_bam}" && -f "${normal_bam}" ]] && has_bam_index "${tumor_bam}" && has_bam_index "${normal_bam}"; then
    echo "[Reuse] 目标目录已存在 dedup BAM，跳过上游重跑"
    return 0
  fi

  local old_tumor="${REUSE_DIR}/${PAIR_ID_LOWER}.tumor.dedup.bam"
  local old_normal="${REUSE_DIR}/${PAIR_ID_LOWER}.normal.dedup.bam"
  if [[ -f "${old_tumor}" && -f "${old_normal}" ]] && has_bam_index "${old_tumor}" && has_bam_index "${old_normal}"; then
    echo "[Reuse] 复用旧目录结果: ${REUSE_DIR}"
    link_bam_and_index "${old_tumor}" "${tumor_bam}"
    link_bam_and_index "${old_normal}" "${normal_bam}"
    return 0
  fi

  return 1
}

build_dedup_bam() {
  local role="$1"        # normal / tumor
  local fq1="$2"
  local fq2="$3"
  local rg_sm="$4"
  local rg_lb="$5"

  local out_dir="${RUN_ROOT}/${PAIR_ID}"
  local prefix="${out_dir}/${role}"
  local clean1="${prefix}.clean_1.fastq.gz"
  local clean2="${prefix}.clean_2.fastq.gz"
  local sorted_bam="${prefix}.sorted.bam"
  local dedup_bam="${prefix}.dedup.bam"
  local metrics="${prefix}.marked_dup_metrics.txt"
  local rg
  # 某些 bwa 版本要求 -R 参数中的制表符必须写为转义序列 "\t"，不能是字面 tab
  rg="@RG\\tID:${PAIR_ID}_${role}\\tSM:${rg_sm}\\tPL:${RG_PL}\\tLB:${rg_lb}"

  mkdir -p "${out_dir}"

  if [[ -f "${dedup_bam}" && ( -f "${dedup_bam}.bai" || -f "${prefix}.dedup.bai" ) ]]; then
    echo "[Skip] ${PAIR_ID} ${role} 已存在 dedup BAM: ${dedup_bam}"
    return 0
  fi

  echo "=========================================="
  echo "[${PAIR_ID}][${role}] fastp + bwa + picard"
  echo "FQ1: ${fq1}"
  echo "FQ2: ${fq2}"
  echo "OUT: ${dedup_bam}"
  echo "=========================================="

  run_fastp_once() {
    local threads="$1"
    timeout "${FASTP_TIMEOUT_SEC}" "${FASTP_CMD}" \
      -i "${fq1}" -I "${fq2}" \
      -o "${clean1}" -O "${clean2}" \
      -l 75 -w "${threads}" \
      --json "${prefix}.fastp.json" \
      --html "${prefix}.fastp.html"
  }

  # fastp 在个别样本上可能多线程挂起：先用配置线程跑，超时后自动降到单线程重试一次
  if ! run_fastp_once "${THREADS}"; then
    echo "[Warn] fastp 失败或超时(${FASTP_TIMEOUT_SEC}s)，清理中间结果并降线程重试..." >&2
    rm -f "${clean1}" "${clean2}" "${prefix}.fastp.json" "${prefix}.fastp.html"
    run_fastp_once "1"
  fi

  "${BWA_CMD}" mem -M -t "${THREADS}" -R "${rg}" "${REF_FA}" "${clean1}" "${clean2}" | \
    "${SAMTOOLS_CMD}" sort -@"${THREADS}" -o "${sorted_bam}"

  "${SAMTOOLS_CMD}" index "${sorted_bam}"

  "${JAVA_CMD}" -Xmx32g -jar "${PICARD_JAR}" MarkDuplicates \
    I="${sorted_bam}" \
    O="${dedup_bam}" \
    M="${metrics}" \
    REMOVE_DUPLICATES=false \
    CREATE_INDEX=true

  [[ -f "${dedup_bam}" ]] || { echo "Error: 未生成 ${dedup_bam}" >&2; exit 1; }
  [[ -f "${dedup_bam}.bai" || -f "${prefix}.dedup.bai" ]] || {
    echo "Error: 未生成 BAM 索引 ${dedup_bam}.bai" >&2
    exit 1
  }

  rm -f "${sorted_bam}" "${sorted_bam}.bai" "${clean1}" "${clean2}"
}

check_file "${REF_FA}"
check_file "${FASTP_CMD}"
check_file "${BWA_CMD}"
check_file "${SAMTOOLS_CMD}"
check_file "${JAVA_CMD}"
check_file "${PICARD_JAR}"

mkdir -p "${RUN_ROOT}"
if ! try_reuse_previous_pair; then
  [[ -n "${TUMOR_R1}" && -n "${TUMOR_R2}" && -n "${NORMAL_R1}" && -n "${NORMAL_R2}" ]] || {
    echo "Error: 未找到可复用的旧 ${PAIR_ID} BAM，且 FASTQ 参数不完整。" >&2
    echo "请提供 tumor/normal 的 R1/R2 FASTQ 路径，或确认 ${REUSE_DIR} 中存在 ${PAIR_ID_LOWER}.*.dedup.bam" >&2
    exit 1
  }
  check_file "${TUMOR_R1}"
  check_file "${TUMOR_R2}"
  check_file "${NORMAL_R1}"
  check_file "${NORMAL_R2}"

  build_dedup_bam "normal" "${NORMAL_R1}" "${NORMAL_R2}" "${PAIR_ID}_normal" "${PAIR_ID}_normal_lb"
  build_dedup_bam "tumor" "${TUMOR_R1}" "${TUMOR_R2}" "${PAIR_ID}_tumor" "${PAIR_ID}_tumor_lb"
fi

tumor_bam="${RUN_ROOT}/${PAIR_ID}/tumor.dedup.bam"
normal_bam="${RUN_ROOT}/${PAIR_ID}/normal.dedup.bam"
run_dir="${RUN_ROOT}/${PAIR_ID}"

echo "=========================================="
echo "Upstream 完成（单样本对）"
echo "Pair ID    : ${PAIR_ID}"
echo "Run dir    : ${run_dir}"
echo "Tumor BAM  : ${tumor_bam}"
echo "Normal BAM : ${normal_bam}"
echo "=========================================="
