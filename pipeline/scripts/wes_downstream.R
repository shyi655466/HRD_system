#!/usr/bin/env Rscript

# ==============================================================================
# WES downstream HRD pipeline (hg38, scarHRD from Sequenza seqz)
#
# 功能:
#   1) 读取上游产出的 .seqz.gz（建议使用 *_small.seqz.gz）
#   2) 调用 scarHRD::scar_score(seqz=TRUE) 计算 LOH / TAI / LST / HRD-sum
#   3) 输出原始结果与统一的最终 TSV/CSV
#
# 用法:
#   Rscript wes_downstream.R <seqz_file> <sample_id> <output_dir> [reference]
#
# 示例:
#   Rscript pipeline/scripts/wes_downstream.R \
#     pipeline/test/pair1/pair1_small.seqz.gz \
#     pair1 \
#     pipeline/test/pair1/HRD_result \
#     grch38
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)
argv <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", argv, value = TRUE)
script_dir <- if (length(file_arg)) {
  dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
} else {
  getwd()
}
# 脚本位于 pipeline/scripts/，供后续扩展加载资源时使用
pipeline_root <- dirname(script_dir)

# ================= 配置区域 ============================
DEFAULT_REFERENCE <- Sys.getenv("HRD_WES_SCAR_REFERENCE", unset = "grch38")
# ======================================================

if (length(args) < 3) {
  stop(
    "参数不足！\n",
    "用法: Rscript wes_downstream.R <seqz_file> <sample_id> <output_dir> [reference]\n"
  )
}

seqz_file <- args[1]
sample_id <- args[2]
output_dir <- args[3]
reference <- if (length(args) >= 4 && nzchar(args[4])) args[4] else DEFAULT_REFERENCE

has_bam_bai <- function(bam_file) {
  idx1 <- paste0(bam_file, ".bai")
  idx2 <- sub("\\.bam$", ".bai", bam_file)
  file.exists(idx1) || file.exists(idx2)
}

if (!file.exists(seqz_file)) stop("文件不存在: ", seqz_file)
if (grepl("\\.bam$", seqz_file, ignore.case = TRUE)) {
  if (!has_bam_bai(seqz_file)) {
    stop("检测到 BAM 输入且缺少索引（仅接受 .bai 或 .bam.bai）: ", seqz_file)
  }
  stop("wes_downstream.R 仅接受 seqz 输入；请先在上游生成 *.seqz.gz")
}
if (!grepl("\\.seqz\\.gz$", seqz_file)) {
  warning("输入文件不是 .seqz.gz，建议使用上游产出的 *.seqz.gz 或 *_small.seqz.gz")
}

if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

suppressPackageStartupMessages({
  library(scarHRD)
})

safe_write_table <- function(df, file) {
  write.table(df, file = file, sep = "\t", quote = FALSE, row.names = FALSE, col.names = TRUE)
}

find_col <- function(df, candidates) {
  nm <- colnames(df)
  for (pat in candidates) {
    idx <- grep(pat, nm, ignore.case = TRUE, perl = TRUE)
    if (length(idx) > 0) return(nm[idx[1]])
  }
  stop("找不到列名，候选模式为: ", paste(candidates, collapse = ", "))
}

message("======================================================")
message("START WES scarHRD pipeline")
message("Sample      : ", sample_id)
message("Seqz file   : ", seqz_file)
message("Reference   : ", reference)
message("Output dir  : ", output_dir)
message("======================================================")

message("[Phase 1] scarHRD::scar_score(seqz=TRUE) ...")
raw_score <- scarHRD::scar_score(
  seg = seqz_file,
  reference = reference,
  seqz = TRUE
)
raw_score_df <- as.data.frame(raw_score)

raw_tsv <- file.path(output_dir, paste0(sample_id, "_scarHRD_raw.tsv"))
safe_write_table(raw_score_df, raw_tsv)

# 兼容不同版本 scarHRD 输出列名。seqz=TRUE 时常用列名 "HRD" 表示 LOH 计数；总分为 "HRD-sum"，与 ^HRD$ 不冲突
loh_col <- find_col(raw_score_df, c("^LOH$", "^HRD$", "\\bLOH\\b"))
tai_col <- find_col(raw_score_df, c("Telomeric", "^TAI$", "NtAI"))
lst_col <- find_col(raw_score_df, c("^LST$"))
sum_col <- find_col(raw_score_df, c("HRD.sum", "HRD-sum", "^sum$"))

final_result_df <- data.frame(
  SampleID = sample_id,
  LOH = as.numeric(raw_score_df[[loh_col]]),
  TAI = as.numeric(raw_score_df[[tai_col]]),
  LST = as.numeric(raw_score_df[[lst_col]]),
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
message("scarHRD raw : ", raw_tsv)
message("HRD TSV     : ", final_tsv)
message("HRD CSV     : ", final_csv)
message("======================================================")
message("HRD_PIPELINE_RESULT_TSV=", final_tsv)
