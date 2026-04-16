# HRD_system
pipeline 目录约定（简要）

scripts/     流程入口与 Shell/R脚本（版本控制）
ref/         参考序列与 ASCAT/scarHRD 资源（大文件见根 .gitignore pipeline/ref/）
envs/        Conda 环境前缀（根 .gitignore envs/；勿提交完整 env）
logs/        运行日志（*.log 被忽略；目录可保留）
test/        本地试跑与历史批次（根 .gitignore test/；勿提交大体积 BAM/FASTQ）
