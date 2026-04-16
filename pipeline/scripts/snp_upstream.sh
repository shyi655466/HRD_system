#!/bin/bash
set -euo pipefail

# SNP panel upstream: FASTQ -> dedup BAM -> seqz/small.seqz
#
# 说明:
# - 面板数据一般覆盖区域有限，本脚本仍沿用 sequenza-utils 生成 seqz 供下游 scarHRD 使用。
# - 对于面板数据，HRD 结果仅作流程验证/趋势参考，临床解释需谨慎。
#
# 示例（20260321 测试数据，P13 对）:
#   bash pipeline/scripts/snp_upstream.sh \
#     -T pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13T-01 \
#     -N pipeline/test/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P13N-01 \
#     -a P13T -b P13T_LIB -c P13N -d P13N_LIB \
#     -o pipeline/test/20260321/p13

# ================= 配置区域 =================
FASTP_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/fastp"
BWA_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/bwa"
SAMTOOLS_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/samtools"
SEQUENZA_UTILS_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/sequenza-utils"
JAVA_CMD="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/bin/java"
PICARD_JAR="/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline/envs/share/picard-3.4.0-0/picard.jar"

THREADS=8
REF_FA="/data/database/hg38/hg38.fa"
GC_WIG="/data/database/hg38/hg38_gc50_sequenza.wig.gz"
RG_PL="ILLUMINA"
BIN_WIDTH=50
KEEP_CLEAN_FASTQ="true"
# ==========================================

usage() {
    cat <<EOF
Usage:
  $0 \\
    -T <tumor_input> -N <normal_input> \\
    -a <tumor_rg_sm> -b <tumor_rg_lb> \\
    -c <normal_rg_sm> -d <normal_rg_lb> \\
    [-t <threads>] [-r <ref_fa>] [-g <gc_wig>] [-o <seqz_prefix>] [-w <bin_width>]

Required:
  -T <tumor_input>    肿瘤输入（样本目录 或 FASTQ 前缀）
  -N <normal_input>   对照输入（样本目录 或 FASTQ 前缀）
  -a <tumor_rg_sm>    肿瘤样本 RG SM
  -b <tumor_rg_lb>    肿瘤样本 RG LB
  -c <normal_rg_sm>   对照样本 RG SM
  -d <normal_rg_lb>   对照样本 RG LB

Optional:
  -t <threads>        线程数，默认 8
  -r <ref_fa>         参考基因组 fasta
  -g <gc_wig>         GC wig 文件
  -o <seqz_prefix>    输出前缀，默认 <tumor_sm>_vs_<normal_sm>
  -w <bin_width>      seqz_binning 窗口大小，默认 50
  -h                  显示帮助

Input naming support:
  目录模式：自动识别 *R1*.fastq.gz / *R2*.fastq.gz
  前缀模式：支持 *_1/_2、*_R1/_R2、*_combined_R1/_combined_R2（.fastq 或 .fastq.gz）
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
        echo "Error: 未找到 BAM 索引（支持 .bai/.bam.bai） -> ${bam}" >&2
        exit 1
    fi
}

# 输入既可为目录，也可为前缀
detect_fastq_pair() {
    local input="$1"
    local r1=""
    local r2=""

    if [[ -d "$input" ]]; then
        r1="$(ls "$input"/*R1*.fastq.gz 2>/dev/null | head -n 1 || true)"
        r2="$(ls "$input"/*R2*.fastq.gz 2>/dev/null | head -n 1 || true)"
    else
        # 优先按更具体模式匹配
        if [[ -f "${input}_combined_R1.fastq.gz" && -f "${input}_combined_R2.fastq.gz" ]]; then
            r1="${input}_combined_R1.fastq.gz"
            r2="${input}_combined_R2.fastq.gz"
        elif [[ -f "${input}_R1.fastq.gz" && -f "${input}_R2.fastq.gz" ]]; then
            r1="${input}_R1.fastq.gz"
            r2="${input}_R2.fastq.gz"
        elif [[ -f "${input}_1.fastq.gz" && -f "${input}_2.fastq.gz" ]]; then
            r1="${input}_1.fastq.gz"
            r2="${input}_2.fastq.gz"
        elif [[ -f "${input}_combined_R1.fastq" && -f "${input}_combined_R2.fastq" ]]; then
            r1="${input}_combined_R1.fastq"
            r2="${input}_combined_R2.fastq"
        elif [[ -f "${input}_R1.fastq" && -f "${input}_R2.fastq" ]]; then
            r1="${input}_R1.fastq"
            r2="${input}_R2.fastq"
        elif [[ -f "${input}_1.fastq" && -f "${input}_2.fastq" ]]; then
            r1="${input}_1.fastq"
            r2="${input}_2.fastq"
        fi
    fi

    if [[ -z "$r1" || -z "$r2" ]]; then
        echo "Error: 无法识别输入 $input 的 R1/R2 FASTQ" >&2
        exit 1
    fi
    echo "$r1 $r2"
}

build_dedup_bam() {
    local role="$1"    # tumor / normal
    local input="$2"
    local rg_sm="$3"
    local rg_lb="$4"

    local fq1 fq2
    read -r fq1 fq2 < <(detect_fastq_pair "$input")

    local prefix="${OUT_PREFIX}.${role}"
    local clean1="${prefix}.clean_R1.fastq.gz"
    local clean2="${prefix}.clean_R2.fastq.gz"
    local sorted_bam="${prefix}.sorted.bam"
    local dedup_bam="${prefix}.dedup.bam"
    local metrics="${prefix}.marked_dup_metrics.txt"
    local rg="@RG\tID:${role}\tSM:${rg_sm}\tPL:${RG_PL}\tLB:${rg_lb}"

    if [[ -f "${dedup_bam}" ]] && has_bam_index "${dedup_bam}"; then
        log "[${role}] 检测到已有 dedup BAM，跳过上游处理"
        check_bam_index "${dedup_bam}"
        return 0
    fi

    log "开始处理 ${role} 样本"
    log "  FQ1: ${fq1}"
    log "  FQ2: ${fq2}"
    log "  RG_SM: ${rg_sm}"
    log "  RG_LB: ${rg_lb}"

    log "[${role}] Step 1/3 fastp"
    "${FASTP_CMD}" \
        -i "${fq1}" -I "${fq2}" \
        -o "${clean1}" -O "${clean2}" \
        -l 75 -w "${THREADS}" \
        --json "${prefix}.fastp.json" \
        --html "${prefix}.fastp.html"

    log "[${role}] Step 2/3 bwa mem + samtools sort"
    "${BWA_CMD}" mem -M -t "${THREADS}" -R "${rg}" "${REF_FA}" "${clean1}" "${clean2}" | \
        "${SAMTOOLS_CMD}" sort -@ "${THREADS}" -o "${sorted_bam}" -

    log "[${role}] Step 3/3 picard MarkDuplicates"
    "${JAVA_CMD}" -Xmx32g -jar "${PICARD_JAR}" MarkDuplicates \
        I="${sorted_bam}" \
        O="${dedup_bam}" \
        M="${metrics}" \
        REMOVE_DUPLICATES=false \
        CREATE_INDEX=true

    check_file "${dedup_bam}"
    check_bam_index "${dedup_bam}"

    rm -f "${sorted_bam}"
    if [[ "${KEEP_CLEAN_FASTQ}" != "true" ]]; then
        rm -f "${clean1}" "${clean2}"
    fi
}

ensure_gc_wig() {
    if [[ -f "${GC_WIG}" ]]; then
        log "GC wig 文件已存在: ${GC_WIG}"
        return 0
    fi

    log "GC wig 文件不存在，开始生成: ${GC_WIG}"
    "${SEQUENZA_UTILS_CMD}" gc_wiggle \
        -w "${BIN_WIDTH}" \
        --fasta "${REF_FA}" \
        -o "${GC_WIG}"
    check_file "${GC_WIG}"
}

run_sequenza() {
    local normal_bam="$1"
    local tumor_bam="$2"
    local out_prefix="$3"

    local seqz="${out_prefix}.seqz.gz"
    local small_seqz="${out_prefix}_small.seqz.gz"

    log "[Sequenza] Step 1/2 bam2seqz"
    "${SEQUENZA_UTILS_CMD}" bam2seqz \
        -n "${normal_bam}" \
        -t "${tumor_bam}" \
        --fasta "${REF_FA}" \
        -gc "${GC_WIG}" \
        -o "${seqz}"
    check_file "${seqz}"

    log "[Sequenza] Step 2/2 seqz_binning"
    "${SEQUENZA_UTILS_CMD}" seqz_binning \
        --seqz "${seqz}" \
        -w "${BIN_WIDTH}" \
        -o "${small_seqz}"
    check_file "${small_seqz}"
}

while getopts "T:N:a:b:c:d:t:r:g:o:w:h" opt; do
    case "${opt}" in
        T) TUMOR_INPUT="${OPTARG}" ;;
        N) NORMAL_INPUT="${OPTARG}" ;;
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

if [[ -z "${TUMOR_INPUT:-}" || -z "${NORMAL_INPUT:-}" || -z "${TUMOR_RG_SM:-}" || -z "${TUMOR_RG_LB:-}" || -z "${NORMAL_RG_SM:-}" || -z "${NORMAL_RG_LB:-}" ]]; then
    echo "Error: 缺少必要参数" >&2
    usage
fi

OUT_PREFIX="${OUT_PREFIX:-${TUMOR_RG_SM}_vs_${NORMAL_RG_SM}}"

check_cmd "${FASTP_CMD}"
check_cmd "${BWA_CMD}"
check_cmd "${SAMTOOLS_CMD}"
check_cmd "${JAVA_CMD}"
check_cmd "${SEQUENZA_UTILS_CMD}"
check_file "${REF_FA}"
check_file "${PICARD_JAR}"

log "=========================================="
log "开始 SNP panel upstream 流程"
log "Tumor input  : ${TUMOR_INPUT}"
log "Normal input : ${NORMAL_INPUT}"
log "Threads      : ${THREADS}"
log "Reference    : ${REF_FA}"
log "GC WIG       : ${GC_WIG}"
log "Out prefix   : ${OUT_PREFIX}"
log "=========================================="

build_dedup_bam "normal" "${NORMAL_INPUT}" "${NORMAL_RG_SM}" "${NORMAL_RG_LB}"
build_dedup_bam "tumor" "${TUMOR_INPUT}" "${TUMOR_RG_SM}" "${TUMOR_RG_LB}"

NORMAL_BAM="${OUT_PREFIX}.normal.dedup.bam"
TUMOR_BAM="${OUT_PREFIX}.tumor.dedup.bam"
check_file "${NORMAL_BAM}"
check_file "${TUMOR_BAM}"
check_bam_index "${NORMAL_BAM}"
check_bam_index "${TUMOR_BAM}"

ensure_gc_wig
run_sequenza "${NORMAL_BAM}" "${TUMOR_BAM}" "${OUT_PREFIX}"

log "=========================================="
log "流程结束，关键产物:"
log "  ${NORMAL_BAM}"
log "  ${TUMOR_BAM}"
log "  ${OUT_PREFIX}.seqz.gz"
log "  ${OUT_PREFIX}_small.seqz.gz"
log "=========================================="

echo "SNP_PIPELINE_NORMAL_BAM=${NORMAL_BAM}"
echo "SNP_PIPELINE_TUMOR_BAM=${TUMOR_BAM}"
echo "SNP_PIPELINE_SEQZ=${OUT_PREFIX}.seqz.gz"
echo "SNP_PIPELINE_SEQZ_SMALL=${OUT_PREFIX}_small.seqz.gz"
