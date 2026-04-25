# HRD_system

同源重组缺陷（HRD）分析系统：**Django REST API** + **Vue 3 / Element Plus / Vite** 前端 + 本地生信流程（`pipeline/`），支持 **WGS** 与 **WES** 全流程编排、Celery 异步分析、结果入库与报告。

---

## 已实现能力概览

| 模块 | 说明 |
|------|------|
| **认证** | JWT（`djangorestframework-simplejwt`）；前端路由守卫，未登录跳转登录页 |
| **工作台** | 仪表盘统计（样本数、分析状态分布、近期任务等） |
| **样本** | 列表检索与筛选；**服务器绝对路径**导入 FASTQ（`/samples/import`），白名单 `HRD_ALLOWED_IMPORT_ROOTS`；样本详情（基础信息、关联文件、分析记录、结果摘要）；分析中自动轮询状态 |
| **分析** | `POST` 触发 Celery `run_hrd_analysis`：WGS 调用 `run_wgs.sh`，WES 调用 `run_wes.sh`；解析 `*_final_hrd_score.tsv` 写入 `HRDResult`；长耗时子流程前后**关闭数据库连接**，减轻 MySQL `wait_timeout` 导致的「gone away」 |
| **报告** | **在线报告**：`/samples/:id/report`（`HrdReport.vue`）。**静态 HTML**：分析成功后 `transaction.on_commit` 排队 `generate_hrd_report_task`，写入 `pipeline/work/<样本UUID>/HRD_result/HRD_report.html`；`USE_TZ=False` 下 naive 时间已兼容 |
| **报告中心** | `/reports` 汇总入口（与样本报告联动） |
| **运维命令** | `clear_analysis`：清理未结束任务并重算样本状态；`recover_sample_from_disk`：从磁盘 TSV 回填结果、收束卡住状态，可选 `--enqueue-report` |

**SNP Panel**：可录入样本，但「开始分析」接口对非 WGS/WES 返回 **400**。

**不做**：浏览器分片上传大文件、PDF 报告。

---

## 初版（grad / 当前）技术范围补充

- **上游**：WGS 使用 `wgs_upstream.sh`（fastp → BWA → Picard 等，路径与线程可由环境变量覆盖）；WES 使用 `wes_upstream.sh` 及下游 `wes_downstream.R` / scarHRD 等脚本（见 `pipeline/scripts/`）。
- **工作目录**：`pipeline/work/<样本UUID>/` 下符号链接 FASTQ、`run.log`、`HRD_result/` 等；**勿将大文件提交 git**。
- **导出**：在线报告页支持结果 **JSON / CSV** 导出（以当前前端实现为准）。

---

## 目录说明

| 路径 | 说明 |
|------|------|
| `backend/` | Django、DRF、Celery 任务、分析 API、`analysis/management/commands/` 运维命令 |
| `frontend/` | Vue 3 + Element Plus + Vite；`npm run dev` 默认开发端口 **5173**（代理 `/api` → 后端） |
| `pipeline/scripts/` | `run_wgs.sh`、`run_wes.sh`、`wgs_upstream.sh`、`wes_upstream.sh`、`wes_downstream.R` 等 |
| `pipeline/work/` | 默认**分析工作根**（按样本 UUID 分子目录；大文件勿提交） |
| `pipeline/ref/` | 参考序列与 ASCAT 等资源（大文件通常 gitignore） |
| `pipeline/environment.yml` | **Conda** 生信环境配方；实际 `env/`、`pipeline/envs/` 勿提交，见下节 |

---

## 两套依赖（务勿混淆）

- **Web / API（pip）**：在 `backend/` 下 `pip install -r requirements.txt`（Django、DRF、Celery、PyMySQL 等），与 Conda 无关。
- **生信管线（Conda）**：fastp、BWA、samtools、R 及 ASCAT / Sequenza / scarHRD 等，建议 `conda env create -f pipeline/environment.yml`。  
  **应提交 yml 配方**；**不要提交**本机 `env/`、`pipeline/envs/` 等实际环境目录（`.gitignore`）。跑通后可用 `conda env export --no-builds` 导出 `environment.lock.yml` 固定版本，详见 `pipeline/environment.yml` 内注释。

---

## 环境变量（后端 / Celery）

仓库根目录复制 `.env.example` 为 `.env`，由 **python-dotenv** 加载（见 `backend/backend/settings.py`）。常用项如下（完整示例见 `.env.example`）。

| 变量 | 说明 |
|------|------|
| `DJANGO_SECRET_KEY` / `DJANGO_DEBUG` / `DJANGO_ALLOWED_HOSTS` | Django 基本配置 |
| `MYSQL_*` | 数据库；可选 `MYSQL_UNIX_SOCKET` 走 Unix socket |
| `CELERY_BROKER_URL` / `CELERY_RESULT_BACKEND` | Redis；默认 `6379/0` 与 `/1` |
| `HRD_PIPELINE_ROOT` | pipeline 根目录，默认 `<仓库根>/pipeline` |
| `HRD_PIPELINE_WORK_ROOT` | 分析工作根，默认 `<仓库根>/pipeline/work` |
| `HRD_WGS_REF_FA` | 传给 `run_wgs.sh -r`；不设置则用脚本内默认参考 |
| `HRD_WGS_THREADS` | BWA / fastp 等线程数，默认 `8` |
| `HRD_RSCRIPT` | 可选；显式指定 `Rscript` |
| `HRD_WGS_SUBPROCESS_TIMEOUT` | 可选；WGS 子进程超时（秒），≤0 表示不限制 |
| `HRD_WES_REF_FA` / `HRD_WES_THREADS` / `HRD_WES_SCAR_REFERENCE` / `HRD_WES_SUBPROCESS_TIMEOUT` | WES；未单独设置时参考/线程/超时与 WGS 对齐 |
| `HRD_POSITIVE_SCORE_MIN` | 可选；HRD 总分阳性阈值（默认 42），与前端及 BRCA 字段判定一致 |

`settings.py` 中 **`HRD_ALLOWED_IMPORT_ROOTS`** 为服务器导入 FASTQ 的**白名单目录前缀**，需与部署路径一致。

---

## 运行提示（开发）

1. **依赖**：MySQL、Redis；`backend/` 下 `pip install -r requirements.txt`；`frontend/` 下 `npm install`。
2. **迁移**：在 `backend/` 执行 `python manage.py migrate`。
3. **Web**：`python manage.py runserver 0.0.0.0:8010`（端口可按习惯调整，与 `frontend/vite.config.js` 里 `proxy` 一致即可）。
4. **Celery Worker**：`celery -A backend worker -l info`（工作目录需能访问 `HRD_PIPELINE_*`、FASTQ 与 Conda/R 工具链，与命令行跑 `run_wgs.sh` / `run_wes.sh` 一致）。
5. **前端**：`npm run dev`（默认 **http://localhost:5173**）。

**说明**：`manage.py recover_sample_from_disk ... --enqueue-report` 仅向 Celery **投递**生成报告任务；需 **Worker 在线且代码已更新**，才会写出 `HRD_result/HRD_report.html`。

---

## 运维命令（`backend/` 下执行）

| 命令 | 用途 |
|------|------|
| `python manage.py clear_analysis [--dry-run] [--sample-id <UUID>]` | 删除状态为 PENDING/QUEUED/RUNNING 的 `AnalysisTask`，无成功 HRD 任务时删除对应 `HRDResult` 并重算样本分析状态；适合「清空排队/僵尸任务」或 Celery 重启后整库/单样本清理 |
| `python manage.py recover_sample_from_disk --sample-id <UUID> [--dry-run] [--enqueue-report] [--from-hrd-result-only]` | **不删**磁盘进度与任务行：从 `HRD_result/*_final_hrd_score.tsv`（或仅用库中已有 `HRDResult`）回填/对齐数据库，收束卡住的任务与样本状态；`--enqueue-report` 排队生成静态 HTML |

---

## FASTQ 与上游命名

`wgs_upstream.sh` 与 WES 上游脚本使用前缀 `normal` / `tumor`，期望 `前缀_1` / `前缀_2` 的 `**.fastq` 或 `.fastq.gz`**。Web 任务会在 `HRD_PIPELINE_WORK_ROOT/<sample_uuid>/` 下创建指向导入路径的**符号链接**，无需手工改文件名。

---

## 生产与排障提示

- 生产环境请用环境变量管理 `SECRET_KEY`、`DEBUG`、`ALLOWED_HOSTS`、数据库与 CORS，**勿提交**真实 `.env` 与密钥。
- Celery 长任务若仍遇 MySQL 断连，可在数据库侧适当增大 `wait_timeout`，并确保 Worker 使用与 `tasks.py` 一致的代码版本。
- MySQL 连接示例（与本地 `.env` 一致时）：  
  `mysql -h 127.0.0.1 -P 33061 -u root -p`  
  或使用 `MYSQL_UNIX_SOCKET` 指定 socket。
  `mysql -S /data_storage2/shiyi/mysql_data/mysql.sock -u root -p`
