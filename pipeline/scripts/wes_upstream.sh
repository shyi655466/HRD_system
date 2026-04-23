#!/bin/bash
set -euo pipefail

# ================= 配置区域 =================
# 可选环境变量（与 wgs_upstream 对齐，可共用 HRD_WGS_* 工具链；本机或服务器上按需 export）:
#   HRD_PIPELINE_ROOT          — pipeline 根目录（默认：本脚本所在目录的上一级）
#   HRD_WGS_FASTP / BWA / SAMTOOLS / JAVA / PICARD_JAR — 与 wgs_upstream 相同约定
#   HRD_WES_SEQUENZA_UTILS       — sequenza-utils（默认: ${PIPELINE_ROOT}/envs/bin/sequenza-utils）
#   HRD_WES_REF_FA               — 未设置时继承 HRD_WGS_REF_FA，再缺省 /data/database/hg38/hg38.fa
#   HRD_WES_GC_WIG               — 未设置时继承 HRD_WGS_GC_WIG，再缺省 .../hg38_gc50_sequenza.wig.gz
#   HRD_WES_THREADS              — 未设置时继承 HRD_WGS_THREADS，再缺省 8（仍可由 -t 覆盖）
#   HRD_WES_BIN_WIDTH            — Sequenza 分箱宽度，默认 50（仍可由 -w 覆盖）
#   HRD_WES_RG_PL                — 未设置时继承 HRD_WGS_RG_PL，再缺省 ILLUMINA
#   HRD_WES_KEEP_CLEAN_FASTQ     — 未设置时继承 HRD_WGS_KEEP_CLEAN_FASTQ，再缺省 false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_DEFAULT_PIPELINE_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIPELINE_ROOT="${HRD_PIPELINE_ROOT:-${_DEFAULT_PIPELINE_ROOT}}"

FASTP_CMD="${HRD_WGS_FASTP:-${PIPELINE_ROOT}/envs/bin/fastp}"
BWA_CMD="${HRD_WGS_BWA:-${PIPELINE_ROOT}/envs/bin/bwa}"
SAMTOOLS_CMD="${HRD_WGS_SAMTOOLS:-${PIPELINE_ROOT}/envs/bin/samtools}"
JAVA_CMD="${HRD_WGS_JAVA:-${PIPELINE_ROOT}/envs/bin/java}"
PICARD_JAR="${HRD_WGS_PICARD_JAR:-${PIPELINE_ROOT}/envs/share/picard-3.4.0-0/picard.jar}"
SEQUENZA_UTILS_CMD="${HRD_WES_SEQUENZA_UTILS:-${PIPELINE_ROOT}/envs/bin/sequenza-utils}"

THREADS="${HRD_WES_THREADS:-${HRD_WGS_THREADS:-8}}"
REF_FA="${HRD_WES_REF_FA:-${HRD_WGS_REF_FA:-/data/database/hg38/hg38.fa}}"
GC_WIG="${HRD_WES_GC_WIG:-${HRD_WGS_GC_WIG:-/data/database/hg38/hg38_gc50_sequenza.wig.gz}}"
BIN_WIDTH="${HRD_WES_BIN_WIDTH:-50}"
RG_PL="${HRD_WES_RG_PL:-${HRD_WGS_RG_PL:-ILLUMINA}}"
KEEP_CLEAN_FASTQ="${HRD_WES_KEEP_CLEAN_FASTQ:-${HRD_WGS_KEEP_CLEAN_FASTQ:-false}}"
# ==========================================

usage() {
    cat <<EOF
Usage:
  $0 \\
    -T <tumor_prefix>  -N <normal_prefix> \\
    -a <tumor_rg_sm>   -b <tumor_rg_lb> \\
    -c <normal_rg_sm>  -d <normal_rg_lb> \\
    [-t <threads>] [-r <ref_fa>] [-g <gc_wig>] [-o <seqz_prefix>]

Required:
  -T <tumor_prefix>    肿瘤样本前缀，例如 tumor（输入文件: tumor_1.fastq / tumor_2.fastq 或 .fastq.gz）
  -N <normal_prefix>   对照样本前缀，例如 normal
  -a <tumor_rg_sm>     肿瘤样本 RG SM
  -b <tumor_rg_lb>     肿瘤样本 RG LB
  -c <normal_rg_sm>    对照样本 RG SM
  -d <normal_rg_lb>    对照样本 RG LB

Optional:
  -t <threads>         线程数；默认来自 HRD_WES_THREADS / HRD_WGS_THREADS / 8
  -r <ref_fa>          参考基因组 fasta；默认 HRD_WES_REF_FA / HRD_WGS_REF_FA / /data/database/hg38/hg38.fa
  -g <gc_wig>          GC wig；默认 HRD_WES_GC_WIG / HRD_WGS_GC_WIG / hg38_gc50_sequenza.wig.gz
  -o <seqz_prefix>     输出前缀，默认 <tumor_prefix>_vs_<normal_prefix>
  -w <bin_width>       Sequenza 分箱宽度；默认 HRD_WES_BIN_WIDTH / 50
  -h                   显示帮助

环境变量与工具路径:
  工具默认位于 \${HRD_PIPELINE_ROOT:-<仓库>/pipeline}/envs/bin；若 Conda 环境不在此路径，可设 HRD_PIPELINE_ROOT 为实际 pipeline 根目录，或使用 HRD_WGS_* 等变量指向各可执行文件。
EOF
    exit 1
}

log() {
    echo "[$(date '+%F %T')] $*"
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: 命令不存在: $1" >&2
        exit 1
    }
}

check_file() {
    local f="$1"
    [[ -f "$f" ]] || { echo "Error: 文件不存在: $f" >&2; exit 1; }
}

has_bam_index() {
    local bam="$1"
    local idx1="${bam}.bai"
    local idx2="${bam%.bam}.bai"
    [[ -f "${idx1}" || -f "${idx2}" ]]
}

check_bam_index() {
    local bam="$1"
    if ! has_bam_index "${bam}"; then
        echo "Error: 未找到 BAM 索引（支持 .bai/.bam.bai）: ${bam}" >&2
        exit 1
    fi
}

detect_fastq_pair() {
    local prefix="$1"

    if [[ -f "${prefix}_1.fastq.gz" && -f "${prefix}_2.fastq.gz" ]]; then
        echo "${prefix}_1.fastq.gz ${prefix}_2.fastq.gz"
    elif [[ -f "${prefix}_1.fastq" && -f "${prefix}_2.fastq" ]]; then
        echo "${prefix}_1.fastq ${prefix}_2.fastq"
    else
        echo "Error: 找不到 ${prefix}_1 / ${prefix}_2 的 FASTQ 文件（支持 .fastq 或 .fastq.gz）" >&2
        exit 1
    fi
}

build_dedup_bam() {
    local prefix="$1"
    local rg_sm="$2"
    local rg_lb="$3"

    local fq1 fq2
    read -r fq1 fq2 < <(detect_fastq_pair "$prefix")

    local clean1="${prefix}.clean_1.fastq.gz"
    local clean2="${prefix}.clean_2.fastq.gz"
    local sorted_bam="${prefix}.sorted.bam"
    local dedup_bam="${prefix}.dedup.bam"
    local metrics="${prefix}.marked_dup_metrics.txt"
    # 使用 basename 作为 @RG ID，避免绝对路径前缀含特殊字符或过长
    local rg_id
    rg_id="$(basename "${prefix}")"
    local rg="@RG\tID:${rg_id}\tSM:${rg_sm}\tPL:${RG_PL}\tLB:${rg_lb}"

    log "开始处理样本: ${prefix}"
    log "  FQ1: ${fq1}"
    log "  FQ2: ${fq2}"
    log "  RG_SM: ${rg_sm}"
    log "  RG_LB: ${rg_lb}"

    # 已有 dedup BAM 则跳过上游，便于失败后重跑
    if [[ -f "${dedup_bam}" ]] && has_bam_index "${dedup_bam}"; then
        log "[${prefix}] 检测到已有 dedup BAM，跳过 fastp/bwa/picard"
        return 0
    fi

    # 1. fastp
    log "[${prefix}] Step 1/3 fastp 质控"
    "${FASTP_CMD}" \
        -i "${fq1}" -I "${fq2}" \
        -o "${clean1}" -O "${clean2}" \
        -l 75 -w "${THREADS}" \
        --json "${prefix}.fastp.json" \
        --html "${prefix}.fastp.html"

    # 2. BWA MEM + samtools sort
    log "[${prefix}] Step 2/3 BWA 比对并排序"
    "${BWA_CMD}" mem -M -t "${THREADS}" -R "${rg}" "${REF_FA}" "${clean1}" "${clean2}" | \
        "${SAMTOOLS_CMD}" sort -@ "${THREADS}" -o "${sorted_bam}" -

    # 3. Picard MarkDuplicates
    log "[${prefix}] Step 3/3 Picard MarkDuplicates"
    "${JAVA_CMD}" -Xmx32g -jar "${PICARD_JAR}" MarkDuplicates \
        I="${sorted_bam}" \
        O="${dedup_bam}" \
        M="${metrics}" \
        REMOVE_DUPLICATES=false \
        CREATE_INDEX=true

    # 基本检查
    [[ -f "${dedup_bam}" ]] || { echo "Error: ${dedup_bam} 未生成" >&2; exit 1; }
    check_bam_index "${dedup_bam}"

    # 清理中间文件
    log "[${prefix}] 清理中间文件"
    rm -f "${sorted_bam}"

    if [[ "${KEEP_CLEAN_FASTQ}" == "false" ]]; then
        rm -f "${clean1}" "${clean2}"
    fi

    log "[${prefix}] 完成，输出: ${dedup_bam}"
}

ensure_gc_wig() {
    if [[ -f "${GC_WIG}" ]]; then
        log "GC wig 文件已存在: ${GC_WIG}"
    else
        log "GC wig 文件不存在，开始生成: ${GC_WIG}"
        "${SEQUENZA_UTILS_CMD}" gc_wiggle \
            -w "${BIN_WIDTH}" \
            --fasta "${REF_FA}" \
            -o "${GC_WIG}"
    fi

    [[ -f "${GC_WIG}" ]] || { echo "Error: GC wig 文件生成失败: ${GC_WIG}" >&2; exit 1; }
}

run_sequenza() {
    local normal_bam="$1"
    local tumor_bam="$2"
    local out_prefix="$3"

    local seqz="${out_prefix}.seqz.gz"
    local small_seqz="${out_prefix}_small.seqz.gz"

    if [[ -f "${small_seqz}" ]]; then
        log "[Sequenza] 已存在分箱 seqz，跳过 bam2seqz / seqz_binning: ${small_seqz}"
        return 0
    fi

    log "[Sequenza] Step 1/2 bam2seqz"
    "${SEQUENZA_UTILS_CMD}" bam2seqz \
        -n "${normal_bam}" \
        -t "${tumor_bam}" \
        --fasta "${REF_FA}" \
        -gc "${GC_WIG}" \
        -o "${seqz}"

    [[ -f "${seqz}" ]] || { echo "Error: ${seqz} 未生成" >&2; exit 1; }

    log "[Sequenza] Step 2/2 seqz_binning"
    "${SEQUENZA_UTILS_CMD}" seqz_binning \
        --seqz "${seqz}" \
        -w "${BIN_WIDTH}" \
        -o "${small_seqz}"

    [[ -f "${small_seqz}" ]] || { echo "Error: ${small_seqz} 未生成" >&2; exit 1; }

    log "Sequenza 处理完成"
    log "  原始输出: ${seqz}"
    log "  分箱输出: ${small_seqz}"
}

# ================ 参数解析 ================
while getopts "T:N:a:b:c:d:t:r:g:o:w:h" opt; do
    case "${opt}" in
        T) TUMOR_PREFIX="${OPTARG}" ;;
        N) NORMAL_PREFIX="${OPTARG}" ;;
        a) TUMOR_RG_SM="${OPTARG}" ;;
        b) TUMOR_RG_LB="${OPTARG}" ;;
        c) NORMAL_RG_SM="${OPTARG}" ;;
        d) NORMAL_RG_LB="${OPTARG}" ;;
        t) THREADS="${OPTARG}" ;;
        r) REF_FA="${OPTARG}" ;;
        g) GC_WIG="${OPTARG}" ;;
        o) OUT_PREFIX="${OPTARG}" ;;
        w) BIN_WIDTH="${OPTARG}" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# 必填参数检查
if [[ -z "${TUMOR_PREFIX:-}" || -z "${NORMAL_PREFIX:-}" || -z "${TUMOR_RG_SM:-}" || -z "${TUMOR_RG_LB:-}" || -z "${NORMAL_RG_SM:-}" || -z "${NORMAL_RG_LB:-}" ]]; then
    echo "Error: 缺少必要参数" >&2
    usage
fi

OUT_PREFIX="${OUT_PREFIX:-${TUMOR_PREFIX}_vs_${NORMAL_PREFIX}}"

# ================ 前置检查 ================
check_cmd "${FASTP_CMD}"
check_cmd "${BWA_CMD}"
check_cmd "${SAMTOOLS_CMD}"
check_cmd "${JAVA_CMD}"
check_cmd "${SEQUENZA_UTILS_CMD}"

[[ -f "${REF_FA}" ]] || { echo "Error: 参考基因组不存在: ${REF_FA}" >&2; exit 1; }
[[ -f "${PICARD_JAR}" ]] || { echo "Error: Picard jar 不存在: ${PICARD_JAR}" >&2; exit 1; }

log "=========================================="
log "开始完整流程"
log "Tumor : ${TUMOR_PREFIX}"
log "Normal: ${NORMAL_PREFIX}"
log "Threads: ${THREADS}"
log "Reference: ${REF_FA}"
log "GC WIG: ${GC_WIG}"
log "Output prefix: ${OUT_PREFIX}"
log "=========================================="

# ================ 主流程 ================
build_dedup_bam "${NORMAL_PREFIX}" "${NORMAL_RG_SM}" "${NORMAL_RG_LB}"
build_dedup_bam "${TUMOR_PREFIX}"  "${TUMOR_RG_SM}"  "${TUMOR_RG_LB}"

ensure_gc_wig

run_sequenza "${NORMAL_PREFIX}.dedup.bam" "${TUMOR_PREFIX}.dedup.bam" "${OUT_PREFIX}"

check_file "${OUT_PREFIX}.seqz.gz"
check_file "${OUT_PREFIX}_small.seqz.gz"

log "=========================================="
log "流程全部结束"
log "最终关键输出:"
log "  ${NORMAL_PREFIX}.dedup.bam"
log "  ${TUMOR_PREFIX}.dedup.bam"
log "  ${OUT_PREFIX}.seqz.gz"
log "  ${OUT_PREFIX}_small.seqz.gz"
log "=========================================="

echo "WES_PIPELINE_SEQZ=${OUT_PREFIX}.seqz.gz"
echo "WES_PIPELINE_SEQZ_SMALL=${OUT_PREFIX}_small.seqz.gz"