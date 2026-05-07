
<template>
    <div class="detail-container" v-loading="loading">
        <!-- 页面头部 -->
        <div class="page-header">
            <div>
                <h2 class="page-title">样本详情</h2>
                <p class="page-subtitle">查看样本基础信息、分析进度与 HRD 结果摘要</p>
                <p v-if="shouldPollAnalysis" class="poll-hint">
                  分析排队或进行中，每 {{ pollIntervalSec }} 秒自动更新状态
                </p>
            </div>
            <div class="header-actions">
                <el-button @click="goBack">返回列表</el-button>
                <el-tooltip
                  :disabled="!!sampleDetail?.result"
                  content="暂无 HRD 结果：请先完成分析且成功生成结果"
                  placement="bottom"
                >
                  <span class="header-btn-wrap">
                    <el-button
                      type="success"
                      :disabled="!sampleDetail?.result"
                      @click="goToReport"
                    >
                      查看报告
                    </el-button>
                  </span>
                </el-tooltip>
                <el-button type="primary" :disabled="!canStartAnalysis" :loading="actionLoading" @click="handleStartAnalysis">开始分析</el-button>
            </div>
        </div>

        <el-row :gutter="20" class="detail-top-row">
            <el-col :xs="24" :lg="16" class="detail-top-left">
                <div class="detail-left-stack">
                <el-card shadow="hover" class="detail-card">
                    <template #header>
                        <div class="card-header">基础信息</div>
                    </template>

                    <el-descriptions :column="2" border v-if="sampleDetail">
                        <el-descriptions-item label="样本ID">
                            {{ sampleDetail.id }}
                        </el-descriptions-item>
                        <el-descriptions-item label="患者编号">
                            {{ sampleDetail.patientId || '-' }}
                        </el-descriptions-item>
                        <el-descriptions-item label="样本编号">
                            {{ sampleDetail.sampleCode || '-' }}
                        </el-descriptions-item>
                        <el-descriptions-item label="数据类型">
                            {{ dataTypeLabel(sampleDetail.dataType) }}
                        </el-descriptions-item>
                        <el-descriptions-item label="备注" :span="2">
                            {{ sampleDetail.description || '-' }}
                        </el-descriptions-item>
                        <el-descriptions-item label="创建时间">
                            {{ formatDate(sampleDetail.createdAt) }}
                        </el-descriptions-item>
                        <el-descriptions-item label="上传状态">
                            <el-tag :type="uploadStatusTag(sampleDetail.upload_status)" effect="light">
                                {{ uploadStatusText(sampleDetail.upload_status) }}
                            </el-tag>
                        </el-descriptions-item>
                        <el-descriptions-item label="分析状态">
                            <el-tag :type="analysisStatusTag(sampleDetail.analysis_status)" effect="light">
                                {{ analysisStatusText(sampleDetail.analysis_status) }}
                            </el-tag>
                        </el-descriptions-item>
                    </el-descriptions>
                </el-card>

                <el-card shadow="hover" class="detail-card">
                    <template #header>
                        <div class="card-header">关联文件</div>
                    </template>
                    <el-table
                        :data="sampleDetail?.files || []"
                        stripe
                        style="width: 100%"
                        empty-text="暂无文件记录"
                    >
                        <el-table-column label="角色" width="120">
                            <template #default="scope">
                                {{ fileRoleLabel(scope.row.fileRole) }}
                            </template>
                        </el-table-column>
                        <el-table-column prop="originalName" label="文件名" min-width="140" />
                        <el-table-column prop="storagePath" label="服务器路径" min-width="280" show-overflow-tooltip />
                        <el-table-column label="大小" width="100">
                            <template #default="scope">
                                {{ formatBytes(scope.row.fileSize) }}
                            </template>
                        </el-table-column>
                    </el-table>
                </el-card>
                </div>
            </el-col>

            <el-col :xs="24" :lg="8" class="detail-top-right">
                <div class="detail-right-stack">
                <el-card shadow="hover" class="detail-card detail-card--stretch">
                    <template #header>
                        <div class="card-header">状态概览</div>
                    </template>

                    <div class="overview-list" v-if="sampleDetail">
                        <div class="overview-item">
                            <span class="overview-label">分析状态</span>
                            <el-tag :type="analysisStatusTag(sampleDetail.analysis_status)" effect="light">
                                {{ analysisStatusText(sampleDetail.analysis_status) }}
                            </el-tag>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">任务数量</span>
                            <span class="overview-value">{{ sampleDetail.tasks?.length || 0 }}</span>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">最近任务</span>
                            <el-tag :type="taskTagType(latestTask?.status)" effect="light">
                                {{ taskStatusText(latestTask?.status) }}
                            </el-tag>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">任务开始</span>
                            <span class="overview-value">{{ formatDate(latestTask?.startedAt) }}</span>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">任务结束</span>
                            <span class="overview-value">{{ formatDate(latestTask?.finishedAt) }}</span>
                        </div>

                        <div v-if="latestTask?.resultPath" class="overview-item overview-item--stack">
                            <span class="overview-label">结果路径</span>
                            <span class="overview-path">{{ latestTask.resultPath }}</span>
                        </div>

                        <el-alert
                          v-if="taskAlert"
                          class="task-alert"
                          :type="taskAlert.type"
                          :title="taskAlert.title"
                          :description="taskAlert.description"
                          show-icon
                          :closable="false"
                        />
                    </div>
                </el-card>

                <el-card shadow="hover" class="detail-card detail-card--stretch result-card">
                    <template #header>
                        <div class="card-header">结果摘要</div>
                    </template>

                    <div v-if="sampleDetail?.result" class="result-list result-list--fill">
                        <div class="result-item">
                            <span class="result-label">HRD评分</span>
                            <span class="result-value">{{ sampleDetail.result.hrdScore ?? '-' }}</span>
                        </div>
                        <div class="result-item">
                            <span class="result-label">LOH评分</span>
                            <span class="result-value">{{ sampleDetail.result.lohScore ?? '-' }}</span>
                        </div>
                        <div class="result-item">
                            <span class="result-label">TAI评分</span>
                            <span class="result-value">{{ sampleDetail.result.taiScore ?? '-' }}</span>
                        </div>
                        <div class="result-item">
                            <span class="result-label">LST评分</span>
                            <span class="result-value">{{ sampleDetail.result.lstScore ?? '-' }}</span>
                        </div>
                        <div class="result-item">
                            <span class="result-label">BRCA状态</span>
                            <span class="result-value">{{ brcaLabel(sampleDetail.result.brcaStatus) }}</span>
                        </div>
                        <div class="result-item">
                            <span class="result-label">分析时间</span>
                            <span class="result-value">{{ formatDate(sampleDetail.result.analysisDate) }}</span>
                        </div>
                    </div>

                    <el-empty v-else description="暂无分析结果" class="result-empty-fill" />
                </el-card>
                </div>
            </el-col>
        </el-row>

        <el-row :gutter="20" class="detail-bottom-row">
            <el-col :span="24">
                <el-card shadow="hover" class="detail-card detail-card--tasks">
                    <template #header>
                        <div class="card-header">分析记录</div>
                    </template>

                    <el-table :data="sampleDetail?.tasks || []" stripe style="width: 100%" empty-text="暂无分析记录">
                        <el-table-column prop="id" label="任务ID" width="72" align="center" />
                        <el-table-column label="任务状态" width="96">
                            <template #default="scope">
                                <el-tag :type="taskTagType(scope.row.status)" effect="light">
                                    {{ taskStatusText(scope.row.status) }}
                                </el-tag>
                            </template>
                        </el-table-column>
                        <el-table-column label="创建时间" width="170">
                            <template #default="scope">
                                {{ formatDate(scope.row.createdAt) }}
                            </template>
                        </el-table-column>
                        <el-table-column label="开始时间" width="170">
                            <template #default="scope">
                                {{ formatDate(scope.row.startedAt) }}
                            </template>
                        </el-table-column>
                        <el-table-column label="结束时间" width="170">
                            <template #default="scope">
                                {{ formatDate(scope.row.finishedAt) }}
                            </template>
                        </el-table-column>
                        <el-table-column prop="resultPath" label="结果路径" min-width="260" show-overflow-tooltip />
                        <el-table-column label="失败原因" min-width="360">
                            <template #default="scope">
                                <div
                                  v-if="scope.row.errorMessage"
                                  class="task-log-text task-log-text--error"
                                >{{ scope.row.errorMessage }}</div>
                                <span v-else class="task-log-empty">-</span>
                            </template>
                        </el-table-column>
                        <el-table-column label="日志摘要" min-width="440">
                            <template #default="scope">
                                <div
                                  v-if="scope.row.logOutput"
                                  class="task-log-text"
                                >{{ scope.row.logOutput }}</div>
                                <span v-else class="task-log-empty">-</span>
                            </template>
                        </el-table-column>
                    </el-table>
                </el-card>
            </el-col>
        </el-row>
    </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getSampleDetail, startSampleAnalysis } from '../api/sample'

const POLL_MS = 8000
const pollIntervalSec = POLL_MS / 1000

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const actionLoading = ref(false)
const sampleDetail = ref(null)
let pollTimer = null

const sampleId = computed(() => route.params.id)

const shouldPollAnalysis = computed(() => {
  const st = sampleDetail.value?.analysis_status
  return st === 'QUEUED' || st === 'RUNNING'
})

const latestTask = computed(() => sampleDetail.value?.tasks?.[0] || null)

const taskAlert = computed(() => {
  const task = latestTask.value
  if (!task) return null

  if (task.status === 'FAILED') {
    return {
      type: 'error',
      title: '最近任务失败',
      description: task.errorMessage || '任务执行失败，未返回具体原因',
    }
  }

  if (task.status === 'RUNNING') {
    return {
      type: 'info',
      title: '最近任务运行中',
      description: task.logOutput ? taskLogPreview(task.logOutput) : '后台正在执行分析任务',
    }
  }

  if (task.status === 'QUEUED' || task.status === 'PENDING') {
    return {
      type: 'warning',
      title: '最近任务等待执行',
      description: '任务已创建，等待后台 Worker 处理',
    }
  }

  if (task.status === 'SUCCESS') {
    return {
      type: 'success',
      title: '最近任务已完成',
      description: task.resultPath || '分析任务已成功结束',
    }
  }

  return null
})

const taskLogPreview = (log) => {
  if (!log) return ''
  const text = String(log).trim()
  return text.length > 240 ? `${text.slice(-240)}` : text
}

const stopDetailPolling = () => {
  if (pollTimer != null) {
    clearInterval(pollTimer)
    pollTimer = null
  }
}

const startDetailPolling = () => {
  stopDetailPolling()
  pollTimer = window.setInterval(async () => {
    if (!shouldPollAnalysis.value) {
      stopDetailPolling()
      return
    }
    await fetchSampleDetail({ silent: true })
  }, POLL_MS)
}

watch(
  shouldPollAnalysis,
  (need) => {
    if (need) startDetailPolling()
    else stopDetailPolling()
  },
  { flush: 'post' }
)

const fetchSampleDetail = async (opts = {}) => {
  const silent = opts.silent === true
  if (!silent) loading.value = true
  try {
    sampleDetail.value = await getSampleDetail(sampleId.value)
  } catch (error) {
    console.error('获取样本详情失败:', error)
    if (!silent) ElMessage.error('获取样本详情失败')
  } finally {
    if (!silent) loading.value = false
  }
}

const canStartAnalysis = computed(() => {
  const s = sampleDetail.value
  if (!s) return false
  const dataReady = s.upload_status === 'UPLOADED'
  const analysisOk =
    s.analysis_status === 'NOT_STARTED' || s.analysis_status === 'FAILED'
  return dataReady && analysisOk
})

const handleStartAnalysis = async () => {
  try {
    actionLoading.value = true
    await startSampleAnalysis(sampleId.value)
    ElMessage.success('分析任务已启动')
    await fetchSampleDetail()
  } catch (error) {
    console.error('启动分析失败:', error)
    ElMessage.error('启动分析失败')
  } finally {
    actionLoading.value = false
  }
}

const goBack = () => {
  router.push('/samples')
}

const goToReport = () => {
  if (sampleId.value) router.push(`/samples/${sampleId.value}/report`)
}

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dateStr.replace('T', ' ').slice(0, 19)
}

const dataTypeLabel = (t) => {
  const map = { WGS: 'WGS', WES: 'WES', SNP_PANEL: 'Panel' }
  return map[t] || t || '-'
}

const uploadStatusText = (st) => {
  const map = {
    DRAFT: '草稿',
    UPLOADING: '上传中',
    UPLOADED: '已上传',
    UPLOAD_FAILED: '上传失败',
  }
  return map[st] || st || '-'
}

const uploadStatusTag = (st) => {
  const map = {
    DRAFT: 'info',
    UPLOADING: 'primary',
    UPLOADED: 'success',
    UPLOAD_FAILED: 'danger',
  }
  return map[st] || 'info'
}

const analysisStatusText = (st) => {
  const map = {
    NOT_STARTED: '未开始',
    QUEUED: '排队中',
    RUNNING: '分析中',
    COMPLETED: '已完成',
    FAILED: '分析失败',
  }
  return map[st] || st || '-'
}

const analysisStatusTag = (st) => {
  const map = {
    NOT_STARTED: 'info',
    QUEUED: 'warning',
    RUNNING: 'primary',
    COMPLETED: 'success',
    FAILED: 'danger',
  }
  return map[st] || 'info'
}

const fileRoleLabel = (role) => {
  const map = {
    TUMOR_R1: '肿瘤 R1',
    TUMOR_R2: '肿瘤 R2',
    NORMAL_R1: '对照 R1',
    NORMAL_R2: '对照 R2',
  }
  return map[role] || role || '-'
}

const formatBytes = (n) => {
  if (n == null || n === '') return '-'
  const v = Number(n)
  if (Number.isNaN(v)) return '-'
  if (v < 1024) return `${v} B`
  if (v < 1024 * 1024) return `${(v / 1024).toFixed(1)} KB`
  return `${(v / (1024 * 1024)).toFixed(1)} MB`
}

const brcaLabel = (raw) => {
  const map = {
    UNKNOWN: '未知',
    POSITIVE: '阳性',
    NEGATIVE: '阴性',
    VUS: 'VUS',
  }
  return map[raw] || raw || '-'
}

const taskStatusText = (st) => {
  const map = {
    PENDING: '待执行',
    QUEUED: '排队中',
    RUNNING: '运行中',
    SUCCESS: '成功',
    FAILED: '失败',
    CANCELLED: '已取消',
  }
  return map[st] || st || '-'
}

const taskTagType = (status) => {
  const map = {
    PENDING: 'warning',
    QUEUED: 'warning',
    RUNNING: 'primary',
    SUCCESS: 'success',
    FAILED: 'danger',
    CANCELLED: 'info',
  }
  return map[status] || 'info'
}

onMounted(() => {
  fetchSampleDetail()
})

onUnmounted(() => {
  stopDetailPolling()
})
</script>


<style scoped>
.detail-container {
  padding: 20px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.page-title {
  margin: 0;
  font-size: 24px;
  font-weight: 700;
  color: #1f2a44;
}

.page-subtitle {
  margin: 8px 0 0;
  color: #909399;
  font-size: 14px;
}

.poll-hint {
  margin: 6px 0 0;
  color: #a8abb2;
  font-size: 13px;
}

.header-actions {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
}

.header-btn-wrap {
  display: inline-block;
}

.detail-card {
  margin-bottom: 20px;
  border-radius: 16px;
}

.detail-top-row {
  align-items: stretch;
}

.detail-top-left {
  display: flex;
  flex-direction: column;
}

.detail-left-stack {
  display: flex;
  flex-direction: column;
  gap: 20px;
  height: 100%;
}

.detail-left-stack .detail-card {
  margin-bottom: 0;
}

.detail-top-right {
  display: flex;
  flex-direction: column;
}

.detail-right-stack {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.detail-right-stack .detail-card {
  margin-bottom: 0;
}

@media (min-width: 992px) {
  .detail-top-right {
    min-height: 100%;
  }

  .detail-right-stack {
    flex: 1;
    min-height: 100%;
  }

  .detail-card--stretch {
    flex: 1 1 0;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }

  .detail-card--stretch :deep(.el-card__body) {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }

  .detail-card--stretch .overview-list,
  .detail-card--stretch .result-list--fill {
    flex: 1;
  }

  .detail-card--stretch .result-empty-fill {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    margin: 0;
    padding: 24px 0;
  }
}

.detail-bottom-row {
  margin-top: 20px;
}

.detail-bottom-row .detail-card--tasks {
  margin-bottom: 20px;
}

.card-header {
  font-size: 16px;
  font-weight: 600;
  color: #1f2a44;
}

.overview-list,
.result-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.overview-item,
.result-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}

.overview-label,
.result-label {
  color: #606266;
  font-size: 14px;
}

.overview-value,
.result-value {
  color: #1f2a44;
  font-weight: 600;
  text-align: right;
  word-break: break-word;
}

.overview-item--stack {
  align-items: flex-start;
  flex-direction: column;
}

.overview-path {
  width: 100%;
  padding: 8px 10px;
  color: #303133;
  background: #f5f7fa;
  border: 1px solid #e4e7ed;
  border-radius: 6px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono',
    'Courier New', monospace;
  font-size: 12px;
  line-height: 1.5;
  word-break: break-all;
}

.task-alert {
  margin-top: 4px;
}

/* 与终端一致保留换行与空格 */
.task-log-text {
  margin: 0;
  padding: 8px 10px;
  max-height: 320px;
  overflow: auto;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono',
    'Courier New', monospace;
  font-size: 12px;
  line-height: 1.5;
  color: #303133;
  background: #f5f7fa;
  border-radius: 6px;
  border: 1px solid #e4e7ed;
}

.task-log-text--error {
  background: #fef0f0;
  border-color: #fde2e2;
  color: #c45656;
}

.task-log-empty {
  color: #909399;
}
</style>
