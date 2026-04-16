#!/usr/bin/env bash
set -euo pipefail

PAIR_ID="P4"
RUN_ROOT="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/wgs_run_20260321"

TUMOR_R1="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4T-01_combined_R1.fastq.gz"
TUMOR_R2="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4T-01_combined_R2.fastq.gz"
NORMAL_R1="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4N-01_combined_R1.fastq.gz"
NORMAL_R2="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P4N-01_combined_R2.fastq.gz"

bash "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_upstream_20260321.sh" \
  "${PAIR_ID}" "${TUMOR_R1}" "${TUMOR_R2}" "${NORMAL_R1}" "${NORMAL_R2}" "${RUN_ROOT}"

bash "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/scripts/wgs_downstream_20260321.sh" \
  "${PAIR_ID}" "${RUN_ROOT}"
