#!/bin/bash
set -euo pipefail

# ================= 配置区域 =================
FASTP_CMD="/data_storage2/shiyi/condaEnv/hrd/bin/fastp"
BWA_CMD="/data_storage2/shiyi/condaEnv/hrd/bin/bwa"
SAMTOOLS_CMD="/data_storage2/shiyi/condaEnv/hrd/bin/samtools"
JAVA_CMD="/data_storage2/shiyi/condaEnv/hrd/bin/java"
PICARD_JAR="/data_storage2/shiyi/condaEnv/hrd/share/picard-2.20.4-0/picard.jar"

# 默认参数
THREADS=8
REF_FA="/data/database/hg38/hg38.fa"
GC_WIG="/data/database/hg38/hg38_gc50_sequenza.wig.gz"
BIN_WINDOW=50
RG_PL="ILLUMINA"
KEEP_CLEAN_FASTQ="false"
KEEP_SORTED_BAM="false"
# ===========================================

usage() {
    cat <<EOF
Usage:
  $0 \\
    -n <normal_prefix> -t <tumor_prefix> -p <pair_id> \\
    -N <normal_sm> -T <tumor_sm> \\
    -a <normal_lb> -b <tumor_lb> \\
    [-@ <threads>] [-r <ref_fa>] 

Required:
  -n <normal_prefix>   正常样本前缀，例如 SRR19859027（输入: <prefix>_1.fastq / <prefix>_2.fastq）
  -t <tumor_prefix>    肿瘤样本前缀，例如 SRR19859026
  -p <pair_id>         肿瘤-正常样本对ID，例如 SAMN29155871
  -N <normal_sm>       正常样本 RG:SM
  -T <tumor_sm>        肿瘤样本 RG:SM
  -a <normal_lb>       正常样本 RG:LB
  -b <tumor_lb>        肿瘤样本 RG:LB

Optional:
  -@ <threads>         线程数，默认 8
  -r <ref_fa>          参考基因组 fasta，默认 /data/database/hg38/hg38.fa
  -h                   显示帮助

EOF
    exit 1
}

# 解析参数
while getopts "n:t:p:N:T:a:b:@:r:h" opt; do
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
        h) usage ;;
        *) usage ;;
    esac
done

# 检查参数
if [[ -z "${NORMAL_PREFIX:-}" || -z "${TUMOR_PREFIX:-}" || -z "${PAIR_ID:-}" || \
      -z "${NORMAL_SM:-}" || -z "${TUMOR_SM:-}" || \
      -z "${NORMAL_LB:-}" || -z "${TUMOR_LB:-}" ]]; then
    echo "Error: 缺少必要参数"
    usage
fi

# ---------------- 工具函数 ----------------
check_file() {
    local f="$1"
    if [[ ! -f "$f" ]]; then
        echo "Error: 文件不存在 -> $f"
        exit 1
    fi
}

already_processed() {
    local PREFIX="$1"
    local DEDUP_BAM="${PREFIX}.dedup.bam"
    local DEDUP_BAI="${PREFIX}.dedup.bam.bai"

    if [[ -f "${DEDUP_BAM}" && -f "${DEDUP_BAI}" ]]; then
        echo "[Skip] 检测到已有结果: ${DEDUP_BAM} 和 ${DEDUP_BAI}"
        return 0
    else
        return 1
    fi
}

process_sample() {
    local PREFIX="$1"
    local RG_SM="$2"
    local RG_LB="$3"

    local FQ1="${PREFIX}_1.fastq"
    local FQ2="${PREFIX}_2.fastq"

    local CLEAN1="${PREFIX}.clean_1.fastq.gz"
    local CLEAN2="${PREFIX}.clean_2.fastq.gz"
    local SORTED_BAM="${PREFIX}.sorted.bam"
    local DEDUP_BAM="${PREFIX}.dedup.bam"
    local METRICS="${PREFIX}.marked_dup_metrics.txt"

    check_file "${FQ1}"
    check_file "${FQ2}"

    local RG="@RG\tID:${PREFIX}\tSM:${RG_SM}\tPL:${RG_PL}\tLB:${RG_LB}"

    echo "------------------------------------------"
    echo "处理样本: ${PREFIX}"
    echo "SM=${RG_SM}"
    echo "LB=${RG_LB}"
    echo "------------------------------------------"

    # 1. fastp
    echo "[${PREFIX}] fastp..."
    ${FASTP_CMD} \
        -i "${FQ1}" -I "${FQ2}" \
        -o "${CLEAN1}" -O "${CLEAN2}" \
        -l 75 -w "${THREADS}" \
        --json "${PREFIX}.fastp.json" \
        --html "${PREFIX}.fastp.html"

    # 2. bwa mem + samtools sort
    echo "[${PREFIX}] BWA MEM + samtools sort..."
    ${BWA_CMD} mem -M -t "${THREADS}" -R "${RG}" "${REF_FA}" "${CLEAN1}" "${CLEAN2}" | \
        ${SAMTOOLS_CMD} sort -@ "${THREADS}" -o "${SORTED_BAM}" -

    ${SAMTOOLS_CMD} index "${SORTED_BAM}"

    # 3. picard MarkDuplicates
    echo "[${PREFIX}] Picard MarkDuplicates..."
    ${JAVA_CMD} -Xmx32g -jar "${PICARD_JAR}" MarkDuplicates \
        I="${SORTED_BAM}" \
        O="${DEDUP_BAM}" \
        M="${METRICS}" \
        REMOVE_DUPLICATES=false \
        CREATE_INDEX=true

    # 4. 清理中间文件
    if [[ -f "${DEDUP_BAM}" ]]; then
        if [[ "${KEEP_CLEAN_FASTQ}" != "true" ]]; then
            rm -f "${CLEAN1}" "${CLEAN2}"
        fi
    else
        echo "Error: ${DEDUP_BAM} 未生成"
        exit 1
    fi
}

# ---------------- 主流程 ----------------
echo "=========================================="
echo "WGS upstream pipeline started"
echo "Pair ID      : ${PAIR_ID}"
echo "Normal Prefix: ${NORMAL_PREFIX}"
echo "Tumor Prefix : ${TUMOR_PREFIX}"
echo "Reference    : ${REF_FA}"
echo "=========================================="


# 分别处理 normal / tumor
if already_processed "${NORMAL_PREFIX}"; then
    echo "[Normal] 跳过上游处理，直接使用已有 dedup BAM"
else
    process_sample "${NORMAL_PREFIX}" "${NORMAL_SM}" "${NORMAL_LB}"
fi

if already_processed "${TUMOR_PREFIX}"; then
    echo "[Tumor] 跳过上游处理，直接使用已有 dedup BAM"
else
    process_sample "${TUMOR_PREFIX}" "${TUMOR_SM}" "${TUMOR_LB}"
fi

NORMAL_BAM="${NORMAL_PREFIX}.dedup.bam"
TUMOR_BAM="${TUMOR_PREFIX}.dedup.bam"

check_file "${NORMAL_BAM}"
check_file "${TUMOR_BAM}"
check_file "${NORMAL_BAM}.bai"
check_file "${TUMOR_BAM}.bai"

echo "=========================================="
echo "流程完成"
echo "Normal dedup BAM : ${NORMAL_BAM}"
echo "Tumor  dedup BAM : ${TUMOR_BAM}"
echo "=========================================="