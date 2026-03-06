#!/data_storage2/shiyi/condaEnv/hrd Rscript

# ==============================================================================
# HRD Analysis Pipeline 
# 功能: 整合 Sequenza 流程 + scarHRD 评分 (输出列名已规范化为 LOH/TAI/LST)
# ==============================================================================

# 1. 参数解析与环境检查
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  stop("错误: 参数不足！\n用法: Rscript run_hrd_analysis.R <seqz_file> <sample_id> <output_dir>")
}

input_file <- args[1]
sample_id  <- args[2]
output_dir <- args[3]

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

suppressPackageStartupMessages({
  library(sequenza)
  library(scarHRD)
})

print(paste("================ STARTING PIPELINE FOR:", sample_id, "================"))

# 定义标准染色体 (hg38)
target_chroms <- paste0("chr", c(1:22, "X", "Y"))

# ==============================================================================
# PHASE 1: Data Extraction
# ==============================================================================
print("[Phase 1] Extracting data...")
tryCatch({
  seqz_data <- sequenza.extract(
    input_file, 
    assembly = "hg19",           
    chromosome.list = target_chroms, 
    verbose = FALSE
  )
  saveRDS(seqz_data, file = file.path(output_dir, paste0(sample_id, "_step1_data.rds")))
  print("[Phase 1] Success.")
}, error = function(e) { stop(paste("[Phase 1] Failed:", e$message)) })

# ==============================================================================
# PHASE 2: Model Fitting
# ==============================================================================
print("[Phase 2] Fitting model...")
tryCatch({
  cp_table <- sequenza.fit(seqz_data)
  saveRDS(cp_table, file = file.path(output_dir, paste0(sample_id, "_step2_cp_table.rds")))
  print("[Phase 2] Success.")
}, error = function(e) { stop(paste("[Phase 2] Failed:", e$message)) })

# ==============================================================================
# PHASE 3: Results Generation
# ==============================================================================
print("[Phase 3] Generating plots...")
tryCatch({
  available_chromosomes <- intersect(target_chroms, seqz_data$chromosomes)
  sequenza.results(
    sequenza.extract = seqz_data,
    cp.table = cp_table,
    sample.id = sample_id,
    out.dir = output_dir,
    chromosome.list = available_chromosomes
  )
  print("[Phase 3] Success.")
}, error = function(e) { stop(paste("[Phase 3] Failed:", e$message)) })

# ==============================================================================
# PHASE 4: HRD Scoring (Standardized Output)
# ==============================================================================
print("[Phase 4] Calculating HRD Score...")

tryCatch({
  # 4.1 获取最佳倍体
  confints_file <- file.path(output_dir, paste0(sample_id, "_confints_CP.txt"))
  if (file.exists(confints_file)) {
    conf_data <- read.table(confints_file, header = TRUE, stringsAsFactors = FALSE)
    best_ploidy <- as.numeric(conf_data$ploidy.estimate[1])
  } else {
    warning("Confints file not found, using fallback ploidy = 2")
    best_ploidy <- 2
  }
  
  # 4.2 清洗 Segments 数据
  raw_seg_file <- file.path(output_dir, paste0(sample_id, "_segments.txt"))
  seg_df <- read.table(raw_seg_file, header = TRUE, stringsAsFactors = FALSE)
  seg_df <- seg_df[!seg_df$chromosome %in% c("chrX", "chrY", "X", "Y"), ]

  clean_df <- data.frame(
    SampleID = sample_id,
    Chromosome = ifelse(grepl("^chr", as.character(seg_df$chromosome)), 
                    as.character(seg_df$chromosome), 
                    paste0("chr", seg_df$chromosome)),
    Start_position = seg_df$start.pos,
    End_position = seg_df$end.pos,
    total_cn = seg_df$CNt,
    A_cn = seg_df$A,
    B_cn = seg_df$B,
    ploidy = best_ploidy
  )
  clean_df <- na.omit(clean_df) # 去除带有NA的异常区段
  
  clean_seg_file <- file.path(output_dir, paste0(sample_id, "_segments_clean.txt"))
  write.table(clean_df, file = clean_seg_file, sep = "\t", quote = FALSE, row.names = FALSE)
  
  # 4.3 运行评分
  raw_score <- scar_score(clean_seg_file, reference = "grch38", seqz = FALSE)
  
  # =========================================================
  # 核心修改：重组输出结果，统一列名为 LOH, TAI, LST
  # =========================================================
  final_result_df <- data.frame(
    SampleID  = sample_id,
    LOH       = as.numeric(raw_score[,"HRD"]),          # 将 "HRD" 列改名为 "LOH"
    TAI       = as.numeric(raw_score[,"Telomeric AI"]), # 将 "Telomeric AI" 改名为 "TAI"
    LST       = as.numeric(raw_score[,"LST"]),          # LST 保持不变
    HRD_Score = as.numeric(raw_score[,"HRD-sum"])       # 总分
  )
  
  # 4.4 输出最终 CSV (这是你要存入数据库的标准格式)
  final_csv <- file.path(output_dir, paste0(sample_id, "_final_hrd_score.csv"))
  write.csv(final_result_df, file = final_csv, row.names = FALSE)
  
  print("================ FINAL STANDARD RESULT ================")
  print(final_result_df)
  print(paste("Saved to:", final_csv))
  print("================ DONE ================")
  
}, error = function(e) { stop(paste("[Phase 4] Failed:", e$message)) })