#!/usr/bin/env Rscript

# ==============================================================================
# WGS downstream HRD pipeline (hg38, ASCAT + scarHRD)
#
# 功能:
#   1) 从 tumor/normal BAM 经顺序 allele counting + getBAFsAndLogRs 生成 LogR/BAF（避免 prepareHTS 并行 worker 工作目录问题）
#   2) 运行 ASCAT 获得 purity / ploidy / allele-specific segments
#   3) 将 ASCAT segments 转换为 scarHRD 输入格式
#   4) 运行 scarHRD 计算 LOH / TAI / LST / HRD-sum
#
# 用法:
#   Rscript run_wgs_downstream_ascat_hrd.R \
#       <tumor_bam> <normal_bam> <sample_id> <output_dir> \
#       [allelecounter_exe] [alleles_prefix] [loci_prefix] \
#       [gc_file] [rt_file]
#
# 示例:
#   Rscript pipeline/scripts/wgs_downstream.R \
#       pipeline/test/SAMN29155871/SRR19859026.dedup.bam pipeline/test/SAMN29155871/SRR19859027.dedup.bam \
#       SAMN29155871 pipeline/test/SAMN29155871/HRD_result \
#       pipeline/envs/bin/alleleCounter \
#       pipeline/ref/ASCAT/hg38/G1000_alleles_hg38_chr \
#       pipeline/ref/ASCAT/hg38/G1000_loci_hg38_chr \
#       pipeline/ref/ASCAT/hg38/GC_G1000_hg38.txt \
#       pipeline/ref/ASCAT/hg38/RT_G1000_hg38.txt
# 可选环境变量:
#   HRD_PIPELINE_ROOT — pipeline 根目录（默认与历史路径一致）
#   HRD_WGS_ALLELECOUNTER_EXE, HRD_WGS_ASCAT_ALLELES_PREFIX, HRD_WGS_ASCAT_LOCI_PREFIX,
#   HRD_WGS_ASCAT_GC_FILE, HRD_WGS_ASCAT_RT_FILE, HRD_WGS_GENDER
# ==============================================================================

hrd_env_or <- function(nm, fb) {
  v <- Sys.getenv(nm, unset = "")
  if (nzchar(v)) v else fb
}

default_pipeline_root <- "/data_storage2/shiyi/git_repo/work_repo/HRD_system/pipeline"
PIPELINE_ROOT <- hrd_env_or("HRD_PIPELINE_ROOT", default_pipeline_root)

DEFAULT_ALLELECOUNTER_EXE <- hrd_env_or(
  "HRD_WGS_ALLELECOUNTER_EXE",
  file.path(PIPELINE_ROOT, "envs", "bin", "alleleCounter")
)
DEFAULT_ALLELES_PREFIX <- hrd_env_or(
  "HRD_WGS_ASCAT_ALLELES_PREFIX",
  file.path(PIPELINE_ROOT, "ref", "ASCAT", "hg38", "G1000_alleles_hg38_chr", "G1000_alleles_hg38_chr")
)
# 对于 chr 风格 BAM（如 chr1），使用已加 chr 前缀的 loci 文件前缀
DEFAULT_LOCI_PREFIX <- hrd_env_or(
  "HRD_WGS_ASCAT_LOCI_PREFIX",
  file.path(PIPELINE_ROOT, "ref", "ASCAT", "hg38", "G1000_loci_hg38_chr_prefixed", "G1000_loci_hg38_chr")
)
DEFAULT_GC_FILE <- hrd_env_or(
  "HRD_WGS_ASCAT_GC_FILE",
  file.path(PIPELINE_ROOT, "ref", "ASCAT", "hg38", "GC_G1000_hg38.txt")
)
DEFAULT_RT_FILE <- hrd_env_or(
  "HRD_WGS_ASCAT_RT_FILE",
  file.path(PIPELINE_ROOT, "ref", "ASCAT", "hg38", "RT_G1000_hg38.txt")
)
DEFAULT_GENDER <- hrd_env_or("HRD_WGS_GENDER", "XX")

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 4) {
  stop(
    "参数不足！\n",
    "用法: Rscript wgs_downstream.R \
    <tumor_bam> <normal_bam> <sample_id> <output_dir> \
    [allelecounter_exe] [alleles_prefix] [loci_prefix] [gc_file] [rt_file]\n"
  )
}

tumor_bam         <- args[1]
normal_bam        <- args[2]
sample_id         <- args[3]
output_dir        <- args[4]
allelecounter_exe <- if (length(args) >= 5 && nzchar(args[5])) args[5] else DEFAULT_ALLELECOUNTER_EXE
alleles_prefix    <- if (length(args) >= 6 && nzchar(args[6])) args[6] else DEFAULT_ALLELES_PREFIX
loci_prefix       <- if (length(args) >= 7 && nzchar(args[7])) args[7] else DEFAULT_LOCI_PREFIX
gc_file           <- if (length(args) >= 8 && nzchar(args[8])) args[8] else DEFAULT_GC_FILE
rt_file           <- if (length(args) >= 9 && nzchar(args[9])) args[9] else DEFAULT_RT_FILE

has_bam_bai <- function(bam_file) {
  idx1 <- paste0(bam_file, ".bai")
  idx2 <- sub("\\.bam$", ".bai", bam_file)
  file.exists(idx1) || file.exists(idx2)
}

check_bam_with_bai <- function(bam_file) {
  if (!file.exists(bam_file)) stop("文件不存在: ", bam_file)
  if (!has_bam_bai(bam_file)) {
    stop("未找到 BAM 索引（仅接受 .bai 或 .bam.bai）: ", bam_file)
  }
}

for (f in c(allelecounter_exe)) {
  if (!file.exists(f)) stop("文件不存在: ", f)
}
if (!file.exists(paste0(alleles_prefix, "1.txt"))) {
  stop("alleles_prefix 无效，未找到: ", paste0(alleles_prefix, "1.txt"))
}
if (!file.exists(paste0(loci_prefix, "1.txt"))) {
  stop("loci_prefix 无效，未找到: ", paste0(loci_prefix, "1.txt"))
}
# 统一为绝对路径，避免 setwd 后 loci/alleles 路径失效
alleles_prefix <- sub("1\\.txt$", "", normalizePath(paste0(alleles_prefix, "1.txt"), mustWork = TRUE))
loci_prefix <- sub("1\\.txt$", "", normalizePath(paste0(loci_prefix, "1.txt"), mustWork = TRUE))
check_bam_with_bai(tumor_bam)
check_bam_with_bai(normal_bam)

if (!grepl("^/", output_dir)) {
  output_dir <- file.path(getwd(), output_dir)
}
output_dir <- normalizePath(output_dir, mustWork = FALSE)
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
message("Gender      : ", DEFAULT_GENDER)
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

archive_allele_frequency_files <- function(sample_id, output_dir) {
  esc <- function(x) gsub("([][{}()+*^$.|?\\\\-])", "\\\\\\1", x)
  normal_id <- paste0(sample_id, "_normal")
  pat <- paste0("^(", esc(sample_id), "|", esc(normal_id), ")_alleleFrequencies_chr.*\\.txt$")
  files <- list.files(output_dir, pattern = pat, full.names = TRUE)
  if (length(files) == 0) return(invisible(NULL))

  archive_dir <- file.path(output_dir, "trash_archive")
  if (!dir.exists(archive_dir)) dir.create(archive_dir, recursive = TRUE)

  target_files <- file.path(archive_dir, basename(files))
  ok <- file.rename(files, target_files)
  if (!all(ok)) {
    failed <- files[!ok]
    warning("以下中间文件归档失败: ", paste(failed, collapse = ", "))
  } else {
    message("[Phase 1] 已归档 alleleFrequencies 中间文件到: ", archive_dir)
  }
}

# scarHRD README 提到 GRCh38 需要支持的 copynumber 版本
scar_reference <- "grch38"

# ------------------------------------------------------------------------------
# Phase 1: ASCAT prepareHTS
# ------------------------------------------------------------------------------

message("[Phase 1] ASCAT HTS（顺序 allele counting + getBAFsAndLogRs）...")

tumor_logr_file  <- file.path(output_dir, paste0(sample_id, ".tumor.LogR.txt"))
tumor_baf_file   <- file.path(output_dir, paste0(sample_id, ".tumor.BAF.txt"))
normal_logr_file <- file.path(output_dir, paste0(sample_id, ".normal.LogR.txt"))
normal_baf_file  <- file.path(output_dir, paste0(sample_id, ".normal.BAF.txt"))

# 必须在 setwd 之前解析 BAM 绝对路径（相对路径是相对于当前工作目录的）
tumor_bam_abs <- normalizePath(tumor_bam, mustWork = TRUE)
normal_bam_abs <- normalizePath(normal_bam, mustWork = TRUE)

old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(output_dir)

# Phase 1 不用 ascat.prepareHTS()：其内部 foreach %dopar% 的子进程工作目录常不是 output_dir，
# alleleCounter 输出落到错误路径或失败，进而 readAlleleCountFiles 报 length(files)>0 为 FALSE。
# 这里顺序调用 ascat.getAlleleCounts，与 prepareHTS 后半段 getBAFsAndLogRs + synchroniseFiles 等价。
normalname <- paste0(sample_id, "_normal")
chrom_names <- c(1:22, "X")

message("[Phase 1] allele counting（顺序执行）...")
for (CHR in chrom_names) {
  loci_chr <- paste0(loci_prefix, CHR, ".txt")
  if (!file.exists(loci_chr)) stop("缺少 loci 文件: ", loci_chr)
  ASCAT::ascat.getAlleleCounts(
    seq.file = tumor_bam_abs,
    output.file = paste0(sample_id, "_alleleFrequencies_chr", CHR, ".txt"),
    loci.file = loci_chr,
    min.base.qual = 20,
    min.map.qual = 35,
    allelecounter.exe = allelecounter_exe
  )
}
for (CHR in chrom_names) {
  loci_chr <- paste0(loci_prefix, CHR, ".txt")
  ASCAT::ascat.getAlleleCounts(
    seq.file = normal_bam_abs,
    output.file = paste0(normalname, "_alleleFrequencies_chr", CHR, ".txt"),
    loci.file = loci_chr,
    min.base.qual = 20,
    min.map.qual = 35,
    allelecounter.exe = allelecounter_exe
  )
}

ASCAT::ascat.getBAFsAndLogRs(
  samplename = sample_id,
  tumourAlleleCountsFile.prefix = paste0(sample_id, "_alleleFrequencies_chr"),
  normalAlleleCountsFile.prefix = paste0(normalname, "_alleleFrequencies_chr"),
  tumourLogR_file = tumor_logr_file,
  tumourBAF_file = tumor_baf_file,
  normalLogR_file = normal_logr_file,
  normalBAF_file = normal_baf_file,
  alleles.prefix = alleles_prefix,
  gender = DEFAULT_GENDER,
  genomeVersion = "hg38",
  chrom_names = chrom_names,
  minCounts = 10,
  BED_file = NA,
  probloci_file = NA,
  tumour_only_mode = FALSE,
  loci_binsize = 1,
  seed = as.integer(Sys.time())
)
ASCAT::ascat.synchroniseFiles(
  samplename = sample_id,
  tumourLogR_file = tumor_logr_file,
  tumourBAF_file = tumor_baf_file,
  normalLogR_file = normal_logr_file,
  normalBAF_file = normal_baf_file
)

archive_allele_frequency_files(sample_id, output_dir)

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