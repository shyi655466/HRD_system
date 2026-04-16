#!/usr/bin/env Rscript

# ==============================================================================
# SNP panel downstream HRD pipeline (hg38, scarHRD from seqz)
#
# 功能:
#   1) 读取上游 SNP 脚本产出的 .seqz.gz（建议 *_small.seqz.gz）
#   2) 运行 scarHRD::scar_score(seqz=TRUE)
#   3) 输出 LOH/TAI/LST/HRD_Score
#
# 用法:
#   Rscript snp_downstream.R <seqz_file> <sample_id> <output_dir> [reference]
#
# 示例（基于 20260321 测试数据生成的 small seqz）:
#   Rscript pipeline/scripts/snp_downstream.R \
#     pipeline/test/20260321/p13_small.seqz.gz \
#     P13 \
#     pipeline/test/20260321/p13_hrd \
#     grch38
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

# ================= 配置区域（绝对路径） =================
PIPELINE_ROOT <- "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline"
DEFAULT_REFERENCE <- "grch38"
# ======================================================
if (length(args) < 3) {
  stop(
    "参数不足！\n",
    "用法: Rscript snp_downstream.R <seqz_file> <sample_id> <output_dir> [reference]\n"
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
  stop("snp_downstream.R 仅接受 seqz 输入；请先在上游生成 *.seqz.gz")
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
    idx <- grep(pat, nm, ignore.case = TRUE)
    if (length(idx) > 0) return(nm[idx[1]])
  }
  stop("找不到列名，候选模式为: ", paste(candidates, collapse = ", "))
}

message("======================================================")
message("START SNP panel scarHRD pipeline")
message("Sample      : ", sample_id)
message("Seqz file   : ", seqz_file)
message("Reference   : ", reference)
message("Output dir  : ", output_dir)
message("======================================================")

raw_score <- scarHRD::scar_score(
  seg = seqz_file,
  reference = reference,
  seqz = TRUE
)
raw_score_df <- as.data.frame(raw_score)
raw_tsv <- file.path(output_dir, paste0(sample_id, "_scarHRD_raw.tsv"))
safe_write_table(raw_score_df, raw_tsv)

# 兼容不同版本 scarHRD 输出列名
loh_col <- find_col(raw_score_df, c("^HRD$", "^LOH$"))
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
