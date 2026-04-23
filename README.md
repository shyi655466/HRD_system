# HRD_system

同源重组缺陷（HRD）分析系统：Django REST API + Vue 前端 + 本地生信流程（`pipeline/`）：**WGS** 与 **WES**。

## 初版（grad / 当前）范围

- **分析**：**WGS** 走 `pipeline/scripts/run_wgs.sh`；**WES** 走 `pipeline/scripts/run_wes.sh`（上游 `wes_upstream.sh` + 下游 `wes_downstream.R` / scarHRD）。Celery 解析 `*_final_hrd_score.tsv` 写入数据库。**SNP Panel** 可录入样本，但「开始分析」会返回 400。
- **数据入口**：**服务器路径导入** FASTQ（见 `HRD_ALLOWED_IMPORT_ROOTS`）。**不做**浏览器分片上传、分片合并任务。
- **报告**：**不做 PDF**；分析成功后异步生成静态 **HTML**（`pipeline/work/<样本UUID>/HRD_result/HRD_report.html`），结果页支持 **JSON / CSV** 导出。

## 目录说明


| 路径                  | 说明                                                  |
| ------------------- | --------------------------------------------------- |
| `backend/`          | Django、Celery 任务、分析 API                             |
| `frontend/`         | Vue 3 + Element Plus                                |
| `pipeline/scripts/` | `run_wgs.sh`、`run_wes.sh`、`wes_upstream.sh`、`wes_downstream.R` 等 |
| `pipeline/work/`    | 默认 **工作目录**（按样本 UUID 分子目录；大文件勿提交 git）          |
| `pipeline/ref/`     | 参考序列与 ASCAT 等资源（大文件通常 gitignore）                    |
| `pipeline/environment.yml` | **Conda** 生信环境配方；实际 `env`/`envs` 目录勿提交，见下节 |


## 两套依赖（务勿混淆）

- **Web / API（pip）**：在 `backend/` 下使用 `pip install -r requirements.txt`（Django、Celery 等），与 Conda 无关。
- **生信管线（Conda）**：WGS、WES 使用的 fastp、BWA、R 等，建议用 `pipeline/environment.yml` 建独立环境。  
  **应提交 yml 配方**；**不要提交**本机里名为 `env/`、`envs/` 的**实际环境目录**（已在 `.gitignore`）。在已跑通管线的机器上可用 `conda env export --no-builds` 再导出为 `environment.lock.yml` 以固定版本。详见 `pipeline/environment.yml` 文件内注释。

## 环境变量（后端 / Celery）

仓库根目录可使用 `.env`（与 `.env.example` 同级），`settings` 由 **python-dotenv** 自动加载。也可在运行环境中直接 `export`。


| 变量                           | 说明                                |
| ---------------------------- | --------------------------------- |
| `HRD_PIPELINE_ROOT`          | pipeline 根目录，默认 `<仓库根>/pipeline`  |
| `HRD_PIPELINE_WORK_ROOT`     | 分析工作根目录，默认 `<仓库根>/pipeline/work`  |
| `HRD_WGS_REF_FA`             | 传给 `run_wgs.sh -r`；不设置则用脚本内默认参考路径 |
| `HRD_WGS_THREADS`            | BWA/fastp 等线程数，默认 `8`             |
| `HRD_RSCRIPT`                | 可选；显式指定 `Rscript` 路径              |
| `HRD_WGS_SUBPROCESS_TIMEOUT` | 可选；WGS 子进程超时（秒），不设或 ≤0 表示不限制   |
| `HRD_WES_REF_FA`             | 传给 `run_wes.sh -r`；未设置时与 `HRD_WGS_REF_FA` 相同 |
| `HRD_WES_THREADS`            | WES 线程；未设置时与 `HRD_WGS_THREADS` 相同  |
| `HRD_WES_SCAR_REFERENCE`     | 可选；传给 `run_wes.sh -G`（scarHRD `reference`） |
| `HRD_WES_SUBPROCESS_TIMEOUT` | 可选；WES 子进程超时；未设置时与 WGS 超时相同   |


Django `settings.py` 中 `HRD_ALLOWED_IMPORT_ROOTS` 为 **服务器导入 FASTQ** 的白名单目录，需与部署路径一致。

## 运行提示（开发）

1. **依赖**：MySQL、Redis；在 `backend/` 下 `pip install -r requirements.txt`；前端 `npm install`。
2. **迁移**：`python manage.py migrate`
3. **Web**：`python manage.py runserver`（在 `backend/`）
4. **Worker**：`celery -A backend worker -l info`（工作目录需能访问 `HRD_PIPELINE_*`、FASTQ 与 conda/R 工具链，与命令行跑 `run_wgs.sh` / `run_wes.sh` 一致）
5. **前端**：`npm run dev`（在 `frontend/`）

生产环境请改用环境变量管理 `SECRET_KEY`、`DEBUG`、`ALLOWED_HOSTS`、数据库与 CORS，勿提交密钥。

## FASTQ 与上游命名

`wgs_upstream.sh` 与 WES 上游脚本使用前缀 `normal` / `tumor`，期望 `前缀_1` / `前缀_2` 的 `**.fastq` 或 `.fastq.gz`**。Web 任务会在 `HRD_PIPELINE_WORK_ROOT/<sample_uuid>/` 下创建指向导入路径的符号链接，无需手工改文件名。
