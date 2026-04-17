# HRD_system

同源重组缺陷（HRD）分析系统：Django REST API + Vue 前端 + 本地 WGS 生信流程（`pipeline/`）。

## 初版（当前）范围

- **分析**：仅 **WGS** 走真实流程（Celery 调用 `pipeline/scripts/run_wgs.sh`，解析 `*_final_hrd_score.tsv` 写入数据库）。**WES / SNP** 可录入样本，但「开始分析」会返回 400，提示待后续版本。
- **数据入口**：**服务器路径导入** FASTQ（见 `HRD_ALLOWED_IMPORT_ROOTS`）。**不做**浏览器分片上传、分片合并任务。
- **报告**：**不做 PDF**；结果页提供 **JSON / CSV** 导出。

## 目录说明


| 路径                  | 说明                                                  |
| ------------------- | --------------------------------------------------- |
| `backend/`          | Django、Celery 任务、分析 API                             |
| `frontend/`         | Vue 3 + Element Plus                                |
| `pipeline/scripts/` | `run_wgs.sh`、`wgs_upstream.sh`、`wgs_downstream.R` 等 |
| `pipeline/work/`    | 默认 **WGS 工作目录**（按样本 UUID 分子目录；大文件勿提交 git）           |
| `pipeline/ref/`     | 参考序列与 ASCAT 等资源（大文件通常 gitignore）                    |


## 环境变量（后端 / Celery）

在运行 `manage.py` 与 Celery worker 的环境中可设置：


| 变量                           | 说明                                |
| ---------------------------- | --------------------------------- |
| `HRD_PIPELINE_ROOT`          | pipeline 根目录，默认 `<仓库根>/pipeline`  |
| `HRD_PIPELINE_WORK_ROOT`     | 分析工作根目录，默认 `<仓库根>/pipeline/work`  |
| `HRD_WGS_REF_FA`             | 传给 `run_wgs.sh -r`；不设置则用脚本内默认参考路径 |
| `HRD_WGS_THREADS`            | BWA/fastp 等线程数，默认 `8`             |
| `HRD_RSCRIPT`                | 可选；显式指定 `Rscript` 路径              |
| `HRD_WGS_SUBPROCESS_TIMEOUT` | 可选；WGS 子进程超时（秒），不设或 ≤0 表示不限制      |


Django `settings.py` 中 `HRD_ALLOWED_IMPORT_ROOTS` 为 **服务器导入 FASTQ** 的白名单目录，需与部署路径一致。

## 运行提示（开发）

1. **依赖**：MySQL、Redis；Python 环境安装 Django 项目依赖；前端 `npm install`。
2. **迁移**：`python manage.py migrate`
3. **Web**：`python manage.py runserver`（在 `backend/`）
4. **Worker**：`celery -A backend worker -l info`（工作目录需能访问 `HRD_PIPELINE_*`、FASTQ 与 conda/R 工具链，与命令行跑 `run_wgs.sh` 一致）
5. **前端**：`npm run dev`（在 `frontend/`）

生产环境请改用环境变量管理 `SECRET_KEY`、`DEBUG`、`ALLOWED_HOSTS`、数据库与 CORS，勿提交密钥。

## FASTQ 与上游命名

`wgs_upstream.sh` 使用前缀 `normal` / `tumor`，期望 `前缀_1` / `前缀_2` 的 `**.fastq` 或 `.fastq.gz`**。Web 任务会在 `HRD_PIPELINE_WORK_ROOT/<sample_uuid>/` 下创建指向导入路径的符号链接，无需手工改文件名。