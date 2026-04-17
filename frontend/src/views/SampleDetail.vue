
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
                <el-button
                  v-if="sampleDetail?.result"
                  type="success"
                  @click="goToResult"
                >
                  查看结果报告
                </el-button>
                <el-button type="primary" :disabled="!canStartAnalysis" :loading="actionLoading" @click="handleStartAnalysis">开始分析</el-button>
            </div>
        </div>

        <el-row :gutter="20">
            <el-col :xs="24" :lg="16">
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

                <el-card shadow="hover" class="detail-card">
                    <template #header>
                        <div class="card-header">分析记录</div>
                    </template>

                    <el-table :data="sampleDetail?.tasks || []" stripe style="width: 100%" empty-text="暂无分析记录">
                        <el-table-column prop="id" label="任务ID" width="100" />
                        <el-table-column label="任务状态" width="140">
                            <template #default="scope">
                                <el-tag :type="taskTagType(scope.row.status)" effect="light">
                                    {{ taskStatusText(scope.row.status) }}
                                </el-tag>
                            </template>
                        </el-table-column>
                        <el-table-column label="创建时间" min-width="180">
                            <template #default="scope">
                                {{ formatDate(scope.row.createdAt) }}
                            </template>
                        </el-table-column>
                        <el-table-column label="失败原因" min-width="200" show-overflow-tooltip>
                            <template #default="scope">
                                {{ scope.row.errorMessage || '-' }}
                            </template>
                        </el-table-column>
                        <el-table-column label="日志摘要" min-width="240" show-overflow-tooltip>
                            <template #default="scope">
                                {{ scope.row.logOutput || '-' }}
                            </template>
                        </el-table-column>
                    </el-table>
                </el-card>
            </el-col>

            <el-col :xs="24" :lg="8">
                <el-card shadow="hover" class="detail-card">
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
                            <span class="overview-value">
                                {{ taskStatusText(sampleDetail.tasks?.[0]?.status) }}
                            </span>
                        </div>
                    </div>
                </el-card>

                <el-card shadow="hover" class="detail-card result-card">
                    <template #header>
                        <div class="card-header">结果摘要</div>
                    </template>

                    <div v-if="sampleDetail?.result" class="result-list">
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

                    <el-empty v-else description="暂无分析结果" />
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

const goToResult = () => {
  if (sampleId.value) router.push(`/results/${sampleId.value}`)
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
}

.detail-card {
  margin-bottom: 20px;
  border-radius: 16px;
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

.result-card {
  min-height: 320px;
}
</style>