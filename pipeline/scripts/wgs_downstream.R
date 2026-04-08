#!/usr/bin/env Rscript

# ==============================================================================
# WGS downstream HRD pipeline (hg38, ASCAT + scarHRD)
#
# 功能:
#   1) 从 tumor/normal BAM 通过 ASCAT::ascat.prepareHTS() 生成 LogR/BAF
#   2) 运行 ASCAT 获得 purity / ploidy / allele-specific segments
#   3) 将 ASCAT segments 转换为 scarHRD 输入格式
#   4) 运行 scarHRD 计算 LOH / TAI / LST / HRD-sum
#
# 用法:
#   Rscript run_wgs_downstream_ascat_hrd.R \
#       <tumor_bam> <normal_bam> <sample_id> <output_dir> \
#       <allelecounter_exe> <alleles_prefix> <loci_prefix> \
#       [gc_file] [rt_file]
#
# 示例:
#   Rscript pipeline/scripts/wgs_downstream.R \
#       pipeline/test/SAMN29155871/SAMN29159026.dedup.bam pipeline/test/SAMN29155871/SAMN29159027.dedup.bam \
#       SAMN29155871 pipeline/test/SAMN29155871/HRD_result \
#       pipeline/bin/alleleCounter \
#       pipeline/ref/ASCAT/hg38/G1000_alleles_hg38_chr \
#       pipeline/ref/ASCAT/hg38/G1000_loci_hg38_chr \
#       pipeline/ref/ASCAT/hg38/GC_WGS_hg38.txt \
#       pipeline/ref/ASCAT/hg38//RT_WGS_hg38.txt
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 7) {
  stop(
    "参数不足！\n",
    "用法: Rscript run_wgs_downstream_ascat_hrd.R \
    <tumor_bam> <normal_bam> <sample_id> <output_dir> \
    <allelecounter_exe> <alleles_prefix> <loci_prefix> [gc_file] [rt_file]\n"
  )
}

tumor_bam         <- args[1]
normal_bam        <- args[2]
sample_id         <- args[3]
output_dir        <- args[4]
allelecounter_exe <- args[5]
alleles_prefix    <- args[6]
loci_prefix       <- args[7]
gc_file           <- ifelse(length(args) >= 8, args[8], NA)
rt_file           <- ifelse(length(args) >= 9, args[9], NA)

for (f in c(tumor_bam, normal_bam, paste0(tumor_bam, ".bai"), paste0(normal_bam, ".bai"), allelecounter_exe)) {
  if (!file.exists(f)) stop("文件不存在: ", f)
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

suppressPackageStartupMessages({
  library(ASCAT)
  library(scarHRD)
})

message("======================================================")
message("START hg38 ASCAT + scarHRD pipeline")
message("Sample      : ", sample_id)
message("Tumor BAM   : ", tumor_bam)
message("Normal BAM  : ", normal_bam)
message("Output dir  : ", output_dir)
message("======================================================")

# ------------------------------------------------------------------------------
# Helper
# ------------------------------------------------------------------------------

safe_write_table <- function(df, file) {
  write.table(df, file = file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
}

find_col <- function(df, candidates) {
  nm <- colnames(df)
  for (pat in candidates) {
    idx <- grep(pat, nm, ignore.case = TRUE)
    if (length(idx) > 0) return(nm[idx[1]])
  }
  stop("找不到列名，候选模式为: ", paste(candidates, collapse = ", "))
}

# scarHRD README 提到 GRCh38 需要支持的 copynumber 版本
scar_reference <- "grch38"

# ------------------------------------------------------------------------------
# Phase 1: ASCAT prepareHTS
# ------------------------------------------------------------------------------

message("[Phase 1] ASCAT prepareHTS ...")

tumor_logr_file  <- file.path(output_dir, paste0(sample_id, ".tumor.LogR.txt"))
tumor_baf_file   <- file.path(output_dir, paste0(sample_id, ".tumor.BAF.txt"))
normal_logr_file <- file.path(output_dir, paste0(sample_id, ".normal.LogR.txt"))
normal_baf_file  <- file.path(output_dir, paste0(sample_id, ".normal.BAF.txt"))

# ASCAT README 示例说明：
# - prepareHTS 直接处理 paired tumor/normal BAM
# - genomeVersion 支持 hg38
# - WGS 可直接用 ReferenceFiles/WGS 的 loci/alleles
# - 后续 runASCAT 对 HTS 要 gamma=1
ascat.prepareHTS(
  tumourseqfile = tumor_bam,
  normalseqfile = normal_bam,
  tumourname = sample_id,
  normalname = paste0(sample_id, "_normal"),
  allelecounter_exe = allelecounter_exe,
  skip_allele_counting_normal = FALSE,
  skip_allele_counting_tumour = FALSE,
  alleles.prefix = alleles_prefix,
  loci.prefix = loci_prefix,
  genomeVersion = "hg38",
  nthreads = 8,
  tumourLogR_file = tumor_logr_file,
  tumourBAF_file = tumor_baf_file,
  normalLogR_file = normal_logr_file,
  normalBAF_file = normal_baf_file
)

message("[Phase 1] done.")

# ------------------------------------------------------------------------------
# Phase 2: load data + optional LogR correction
# ------------------------------------------------------------------------------

message("[Phase 2] ASCAT loadData ...")

ascat.bc <- ASCAT::ascat.loadData(
  Tumor_LogR_file    = tumor_logr_file,
  Tumor_BAF_file     = tumor_baf_file,
  Germline_LogR_file = normal_logr_file,
  Germline_BAF_file  = normal_baf_file,
  chrs = 1:22,
  genomeVersion = "hg38"
)

# 可选校正：官方建议使用 ascat.correctLogR()
if (!is.na(gc_file) && file.exists(gc_file)) {
  message("[Phase 2b] ASCAT correctLogR with GC correction ...")
  if (!is.na(rt_file) && file.exists(rt_file)) {
    ascat.bc <- ASCAT::ascat.correctLogR(
      ascat.bc,
      GCcontentfile = gc_file,
      replictimingfile = rt_file
    )
  } else {
    ascat.bc <- ASCAT::ascat.correctLogR(
      ascat.bc,
      GCcontentfile = gc_file
    )
  }
} else {
  message("[Phase 2b] skip LogR correction (未提供 gc_file)")
}

message("[Phase 2] done.")

# ------------------------------------------------------------------------------
# Phase 3: segmentation + ASCAT fitting
# ------------------------------------------------------------------------------

message("[Phase 3] ASCAT segmentation ...")
ascat.bc <- ASCAT::ascat.aspcf(ascat.bc)

message("[Phase 4] ASCAT runAscat ...")
ascat.output <- ASCAT::ascat.runAscat(
  ascat.bc,
  gamma = 1,
  write_segments = TRUE,
  img.dir = output_dir,
  img.prefix = paste0(sample_id, "_")
)

# 保存对象
saveRDS(ascat.bc, file = file.path(output_dir, paste0(sample_id, "_ascat_bc.rds")))
saveRDS(ascat.output, file = file.path(output_dir, paste0(sample_id, "_ascat_output.rds")))

# 导出 purity / ploidy / segments
ascat_results <- data.frame(
  SampleID = sample_id,
  purity   = as.numeric(ascat.output$purity),
  ploidy   = as.numeric(ascat.output$ploidy),
  psi      = as.numeric(ascat.output$psi),
  goodnessOfFit = as.numeric(ascat.output$goodnessOfFit)
)

safe_write_table(ascat_results, file.path(output_dir, paste0(sample_id, "_ascat_results.tsv")))
safe_write_table(ascat.output$segments, file.path(output_dir, paste0(sample_id, "_ascat_segments.tsv")))

message("[Phase 4] done.")

# ------------------------------------------------------------------------------
# Phase 5: convert ASCAT segments to scarHRD input
# ------------------------------------------------------------------------------

message("[Phase 5] preparing scarHRD input ...")

seg_df <- ascat.output$segments

required_cols <- c("chr", "startpos", "endpos", "nMajor", "nMinor")
missing_cols <- setdiff(required_cols, colnames(seg_df))
if (length(missing_cols) > 0) {
  stop("ASCAT segments 缺少必要列: ", paste(missing_cols, collapse = ", "))
}

# 仅保留常染色体
seg_df <- seg_df[seg_df$chr %in% as.character(1:22), , drop = FALSE]

if (nrow(seg_df) == 0) {
  stop("过滤后无常染色体 segments，无法进行 scarHRD 计算。")
}

best_ploidy <- as.numeric(ascat.output$ploidy)

scar_input <- data.frame(
  SampleID       = sample_id,
  Chromosome     = paste0("chr", seg_df$chr),
  Start_position = as.numeric(seg_df$startpos),
  End_position   = as.numeric(seg_df$endpos),
  total_cn       = as.numeric(seg_df$nMajor) + as.numeric(seg_df$nMinor),
  A_cn           = as.numeric(seg_df$nMajor),
  B_cn           = as.numeric(seg_df$nMinor),
  ploidy         = best_ploidy,
  stringsAsFactors = FALSE
)

scar_input <- na.omit(scar_input)

scar_input_file <- file.path(output_dir, paste0(sample_id, "_scarHRD_input.tsv"))
safe_write_table(scar_input, scar_input_file)

message("[Phase 5] scarHRD input written: ", scar_input_file)

# ------------------------------------------------------------------------------
# Phase 6: scarHRD scoring
# ------------------------------------------------------------------------------

message("[Phase 6] scarHRD::scar_score ...")

raw_score <- scarHRD::scar_score(
  seg = scar_input_file,
  reference = scar_reference,
  seqz = FALSE
)

raw_score_df <- as.data.frame(raw_score)
safe_write_table(raw_score_df, file.path(output_dir, paste0(sample_id, "_scarHRD_raw.tsv")))

# 兼容不同版本 scarHRD 输出列名
loh_col <- find_col(raw_score_df, c("^HRD$", "^LOH$"))
tai_col <- find_col(raw_score_df, c("Telomeric", "^TAI$", "NtAI"))
lst_col <- find_col(raw_score_df, c("^LST$"))
sum_col <- find_col(raw_score_df, c("HRD.sum", "HRD-sum", "^sum$"))

final_result_df <- data.frame(
  SampleID  = sample_id,
  LOH       = as.numeric(raw_score_df[[loh_col]]),
  TAI       = as.numeric(raw_score_df[[tai_col]]),
  LST       = as.numeric(raw_score_df[[lst_col]]),
  HRD_Score = as.numeric(raw_score_df[[sum_col]]),
  stringsAsFactors = FALSE
)

final_tsv <- file.path(output_dir, paste0(sample_id, "_final_hrd_score.tsv"))
final_csv <- file.path(output_dir, paste0(sample_id, "_final_hrd_score.csv"))

safe_write_table(final_result_df, final_tsv)
write.csv(final_result_df, final_csv, row.names = FALSE)

message("======================================================")
message("FINAL RESULT")
print(final_result_df)
message("ASCAT results : ", file.path(output_dir, paste0(sample_id, "_ascat_results.tsv")))
message("ASCAT segments: ", file.path(output_dir, paste0(sample_id, "_ascat_segments.tsv")))
message("HRD TSV       : ", final_tsv)
message("HRD CSV       : ", final_csv)
message("======================================================")