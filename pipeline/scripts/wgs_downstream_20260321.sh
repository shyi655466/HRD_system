#!/usr/bin/env bash
set -euo pipefail

# 20260321 单对样本 WGS downstream（合并版）
# 直接调用 pipeline/scripts/wgs_downstream.R
# 若 RUN_ROOT/<pair_id> 下没有标准命名 BAM，则回退使用旧目录 <pair_id小写>/<pair_id小写>.*.dedup.bam
#
# 用法:
#   bash pipeline/scripts/wgs_downstream_20260321.sh [pair_id] [run_root] [reuse_dir] [output_dir]

PAIR_ID="${1:-P13}"
RUN_ROOT="${2:-/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/wgs_run_20260321}"
PAIR_ID_LOWER="$(echo "${PAIR_ID}" | tr '[:upper:]' '[:lower:]')"
REUSE_DIR="${3:-/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/${PAIR_ID_LOWER}}"
OUTPUT_DIR="${4:-}"

WGS_DOWNSTREAM_R="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_downstream.R"
ALLELECOUNTER_EXE="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/alleleCounter"
ALLELES_PREFIX="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/ref/ASCAT/hg38/G1000_alleles_hg38_chr/G1000_alleles_hg38_chr"
LOCI_PREFIX="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/ref/ASCAT/hg38/G1000_loci_hg38_chr_prefixed/G1000_loci_hg38_chr"
GC_FILE="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/ref/ASCAT/hg38/GC_G1000_hg38.txt"
RT_FILE="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/ref/ASCAT/hg38/RT_G1000_hg38.txt"

check_file() {
  local f="$1"
  [[ -f "$f" ]] || { echo "Error: 文件不存在: $f" >&2; exit 1; }
}

has_bam_index() {
  local bam="$1"
  [[ -f "${bam}.bai" || -f "${bam%.bam}.bai" ]]
}

pick_bam_sources() {
  local new_tumor="${RUN_ROOT}/${PAIR_ID}/tumor.dedup.bam"
  local new_normal="${RUN_ROOT}/${PAIR_ID}/normal.dedup.bam"
  local old_tumor="${REUSE_DIR}/${PAIR_ID_LOWER}.tumor.dedup.bam"
  local old_normal="${REUSE_DIR}/${PAIR_ID_LOWER}.normal.dedup.bam"

  if [[ -f "${new_tumor}" && -f "${new_normal}" ]] && has_bam_index "${new_tumor}" && has_bam_index "${new_normal}"; then
    TUMOR_BAM="${new_tumor}"
    NORMAL_BAM="${new_normal}"
    [[ -n "${OUTPUT_DIR}" ]] || OUTPUT_DIR="${RUN_ROOT}/${PAIR_ID}/hrd_result"
    return 0
  fi

  if [[ -f "${old_tumor}" && -f "${old_normal}" ]] && has_bam_index "${old_tumor}" && has_bam_index "${old_normal}"; then
    TUMOR_BAM="${old_tumor}"
    NORMAL_BAM="${old_normal}"
    [[ -n "${OUTPUT_DIR}" ]] || OUTPUT_DIR="${REUSE_DIR}/${PAIR_ID_LOWER}_hrd"
    return 0
  fi

  echo "Error: 未找到可用的 tumor/normal dedup BAM。" >&2
  echo "已检查:" >&2
  echo "  1) ${new_tumor} / ${new_normal}" >&2
  echo "  2) ${old_tumor} / ${old_normal}" >&2
  exit 1
}

check_file "${WGS_DOWNSTREAM_R}"
check_file "${ALLELECOUNTER_EXE}"
check_file "${GC_FILE}"
check_file "${RT_FILE}"
check_file "${ALLELES_PREFIX}1.txt"
check_file "${LOCI_PREFIX}1.txt"

# 预检：避免脚本语法损坏导致运行中途报 unexpected input
Rscript --vanilla -e "parse(file='${WGS_DOWNSTREAM_R}')" >/dev/null

pick_bam_sources
mkdir -p "${OUTPUT_DIR}"

echo "=========================================="
echo "[${PAIR_ID}] WGS downstream start"
echo "Tumor BAM  : ${TUMOR_BAM}"
echo "Normal BAM : ${NORMAL_BAM}"
echo "Out dir    : ${OUTPUT_DIR}"
echo "=========================================="

Rscript "${WGS_DOWNSTREAM_R}" \
  "${TUMOR_BAM}" \
  "${NORMAL_BAM}" \
  "${PAIR_ID}" \
  "${OUTPUT_DIR}" \
  "${ALLELECOUNTER_EXE}" \
  "${ALLELES_PREFIX}" \
  "${LOCI_PREFIX}" \
  "${GC_FILE}" \
  "${RT_FILE}"

FINAL_TSV="${OUTPUT_DIR}/${PAIR_ID}_final_hrd_score.tsv"
check_file "${FINAL_TSV}"
echo "Downstream 完成: ${FINAL_TSV}"
