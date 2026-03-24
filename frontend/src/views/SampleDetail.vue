
<template>
    <div class="detail-container" v-loading="loading">
        <!-- 页面头部 -->
        <div class="page-header">
            <div>
                <h2 class="page-title">样本详情</h2>
                <p class="page-subtitle">查看样本基础信息、分析进度与 HRD 结果摘要</p>
            </div>
            <div class="header-actions">
                <el-button @click="goBack">返回列表</el-button>
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
                        <el-descriptions-item label="创建时间">
                            {{ formatDate(sampleDetail.createdAt) }}
                        </el-descriptions-item>
                        <el-descriptions-item label="当前状态">
                            <el-tag :type="statusTagType(sampleDetail.status)" effect="light">
                                {{ statusText(sampleDetail.status) }}
                            </el-tag>
                        </el-descriptions-item>
                    </el-descriptions>
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
                                    {{ scope.row.status }}
                                </el-tag>
                            </template>
                        </el-table-column>
                        <el-table-column label="创建时间" min-width="180">
                            <template #default="scope">
                                {{ formatDate(scope.row.createdAt) }}
                            </template>
                        </el-table-column>
                        <el-table-column label="日志输出" min-width="240">
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
                            <span class="overview-label">分析状态
                                <el-tag :type="statusTagType(sampleDetail.status)" effect="light">
                                    {{ statusText(sampleDetail.status) }}
                                </el-tag>
                            </span>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">任务数量</span>
                            <span class="overview-value">{{ sampleDetail.tasks?.length || 0 }}</span>
                        </div>

                        <div class="overview-item">
                            <span class="overview-label">最近任务</span>
                            <span class="overview-value">
                                {{ sampleDetail.tasks?.[0]?.status || '-' }}
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
                            <span class="result-value">{{ sampleDetail.result.brcaStatus ?? '-' }}</span>
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
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getSampleDetail, startSampleAnalysis } from '../api/sample'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const actionLoading = ref(false)
const sampleDetail = ref(null)

const sampleId = computed(() => route.params.id)

const fetchSampleDetail = async () => {
  loading.value = true
  try {
    sampleDetail.value = await getSampleDetail(sampleId.value)
  } catch (error) {
    console.error('获取样本详情失败:', error)
    ElMessage.error('获取样本详情失败')
  } finally {
    loading.value = false
  }
}

const canStartAnalysis = computed(() => {
  const status = sampleDetail.value?.status
  return status === 'uploaded' || status === 'failed'
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

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dateStr.replace('T', ' ').slice(0, 19)
}

const statusText = (status) => {
  const map = {
    uploaded: '已上传',
    running: '分析中',
    completed: '已完成',
    failed: '失败',
  }
  return map[status] || status || '-'
}

const statusTagType = (status) => {
  const map = {
    uploaded: 'warning',
    running: 'primary',
    completed: 'success',
    failed: 'danger',
  }
  return map[status] || 'info'
}

const taskTagType = (status) => {
  const map = {
    PENDING: 'warning',
    STARTED: 'primary',
    SUCCESS: 'success',
    FAILURE: 'danger',
    running: 'primary',
    completed: 'success',
    failed: 'danger',
  }
  return map[status] || 'info'
}

onMounted(() => {
  fetchSampleDetail()
})
</script>


<style scoped>
.sample-detail-container {
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