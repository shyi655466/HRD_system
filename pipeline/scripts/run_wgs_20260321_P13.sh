#!/usr/bin/env bash
set -euo pipefail

PAIR_ID="P13"
RUN_ROOT="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/wgs_run_20260321"
REUSE_DIR="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/p13"
FORCE_REBUILD_FROM_FASTQ="${FORCE_REBUILD_FROM_FASTQ:-false}"

TUMOR_R1="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13T-01_combined_R1.fastq.gz"
TUMOR_R2="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13T-01_combined_R2.fastq.gz"
NORMAL_R1="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13N-01_combined_R1.fastq.gz"
NORMAL_R2="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13N-01_combined_R2.fastq.gz"

if [[ "${FORCE_REBUILD_FROM_FASTQ}" == "true" ]]; then
  bash "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_upstream_20260321.sh" \
    "${PAIR_ID}" "${TUMOR_R1}" "${TUMOR_R2}" "${NORMAL_R1}" "${NORMAL_R2}" "${RUN_ROOT}" "8" "${REUSE_DIR}"
else
  # 默认优先复用旧 p13 结果（若不可复用，脚本会提示并要求补充 FASTQ 或检查目录）
  bash "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_upstream_20260321.sh" \
    "${PAIR_ID}" "" "" "" "" "${RUN_ROOT}" "8" "${REUSE_DIR}"
fi

bash "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_downstream_20260321.sh" \
  "${PAIR_ID}" "${RUN_ROOT}" "${REUSE_DIR}"
