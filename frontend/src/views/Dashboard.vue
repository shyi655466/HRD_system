<template>
  <div class="dashboard-container" v-loading="loading">
    <el-card shadow="never" class="welcome-card">
      <div class="welcome-content">
        <div>
          <h2 class="welcome-title">HRD 评分计算与报告管理系统</h2>
          <p class="welcome-subtitle">
            面向 WGS/WES 肿瘤-正常配对测序数据，完成样本导入、异步分析、HRD 结果解析与报告展示的完整流程。
          </p>
        </div>
      </div>
    </el-card>

    <el-row :gutter="20" class="stats-row align-row">
      <el-col :xs="24" :sm="12" :lg="6" class="dashboard-col">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">我的样本</div>
          <div class="card-value primary">{{ stats.total_samples }}</div>
          <div class="card-footer">全部上传/分析状态合计</div>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="12" :lg="6" class="dashboard-col">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">分析已完成</div>
          <div class="card-value success">{{ completedSamples }}</div>
          <div class="card-footer">样本维度 · 状态为「已完成」</div>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="12" :lg="6" class="dashboard-col">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">排队或分析中</div>
          <div class="card-value warning">{{ queuedOrRunningSamples }}</div>
          <div class="card-footer">样本维度 · 排队中 + 分析中</div>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="12" :lg="6" class="dashboard-col">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">分析失败（样本）</div>
          <div class="card-value danger">{{ failedSamples }}</div>
          <div class="card-footer">样本维度 · 状态为「分析失败」</div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="content-row align-row">
      <el-col :xs="24" :lg="16" class="dashboard-col">
        <el-card shadow="never" class="section-card task-card">
          <template #header>
            <div class="section-header">
              <span>最近分析任务</span>
              <el-button type="primary" link @click="goSamples">查看样本列表</el-button>
            </div>
          </template>

          <el-table
            v-if="recentTasks.length"
            :data="recentTasks"
            style="width: 100%"
            stripe
            @row-click="onTaskRowClick"
            class="clickable-table"
          >
            <el-table-column prop="sample_code" label="样本编号" min-width="180" show-overflow-tooltip />
            <el-table-column prop="patient_id" label="患者编号" width="130" show-overflow-tooltip />
            <el-table-column label="任务状态" width="100">
              <template #default="scope">
                <el-tag :type="taskTagType(scope.row.task_status)" effect="light" size="small">
                  {{ taskStatusLabel(scope.row.task_status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="样本分析状态" width="110">
              <template #default="scope">
                <el-tag :type="analysisTagType(scope.row.sample_analysis_status)" effect="light" size="small">
                  {{ analysisStatusLabel(scope.row.sample_analysis_status) }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column label="创建时间" width="170">
              <template #default="scope">
                {{ formatTime(scope.row.created_at) }}
              </template>
            </el-table-column>
            <el-table-column label="HRD 评分" width="100">
              <template #default="scope">
                <span v-if="scope.row.hrd_score == null">-</span>
                <span v-else :class="{ 'hrd-high': scope.row.hrd_score >= hrdPositiveMin }">
                  {{ scope.row.hrd_score }}
                </span>
              </template>
            </el-table-column>
          </el-table>
          <el-empty v-else description="暂无分析任务记录" />
          <p v-if="recentTasks.length" class="table-hint">点击行可打开对应样本详情</p>
        </el-card>
      </el-col>

      <el-col :xs="24" :lg="8" class="dashboard-col">
        <el-card shadow="never" class="section-card dist-card">
          <template #header>
            <div class="section-header">
              <span>状态分布（真实计数）</span>
            </div>
          </template>

          <div class="dist-block">
            <div class="dist-title">分析任务（Celery 任务表）</div>
            <ul class="dist-list">
              <li v-for="(label, key) in taskStatusLabels" :key="'t-' + key">
                <span>{{ label }}</span>
                <strong>{{ stats.task_status_counts[key] ?? 0 }}</strong>
              </li>
            </ul>
          </div>
          <el-divider />
          <div class="dist-block">
            <div class="dist-title">样本分析状态</div>
            <ul class="dist-list">
              <li v-for="(label, key) in analysisStatusLabels" :key="'a-' + key">
                <span>{{ label }}</span>
                <strong>{{ stats.analysis_status_counts[key] ?? 0 }}</strong>
              </li>
            </ul>
          </div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="bottom-row align-row">
      <el-col :xs="24" :lg="12" class="dashboard-col">
        <el-card shadow="never" class="section-card compact-card">
          <template #header>
            <div class="section-header">
              <span>待处理队列</span>
              <el-button type="primary" link @click="goSamples">处理样本</el-button>
            </div>
          </template>
          <div class="queue-list">
            <div v-for="item in workQueueItems" :key="item.label" class="queue-item">
              <div>
                <div class="queue-label">{{ item.label }}</div>
                <div class="queue-desc">{{ item.desc }}</div>
              </div>
              <el-tag :type="item.type" effect="light">{{ item.value }}</el-tag>
            </div>
          </div>
        </el-card>
      </el-col>
      <el-col :xs="24" :lg="12" class="dashboard-col">
        <el-card shadow="never" class="section-card compact-card">
          <template #header>
            <div class="section-header">
              <span>结果与报告概览</span>
              <el-button type="success" link @click="goReports">查看报告</el-button>
            </div>
          </template>
          <div class="result-summary">
            <div v-for="item in resultSummaryItems" :key="item.label" class="summary-item">
              <span class="summary-label">{{ item.label }}</span>
              <strong :class="item.className">{{ item.value }}</strong>
            </div>
          </div>
          <p class="summary-hint">
            最近任务中已有 HRD 评分的记录会参与阳性数量统计；完整报告从报告中心进入。
          </p>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getDashboardStats } from '../api/dashboard'
import { getHrdPositiveMin } from '../api/config'

const router = useRouter()
const loading = ref(true)
const hrdPositiveMin = ref(42)

const stats = reactive({
  total_samples: 0,
  analysis_status_counts: {},
  task_status_counts: {},
  recent_tasks: [],
})

const recentTasks = computed(() => stats.recent_tasks || [])

const completedSamples = computed(() => stats.analysis_status_counts?.COMPLETED ?? 0)
const notStartedSamples = computed(() => stats.analysis_status_counts?.NOT_STARTED ?? 0)
const queuedOrRunningSamples = computed(() => {
  const c = stats.analysis_status_counts || {}
  return (c.QUEUED ?? 0) + (c.RUNNING ?? 0)
})
const failedSamples = computed(() => stats.analysis_status_counts?.FAILED ?? 0)
const failedTasks = computed(() => stats.task_status_counts?.FAILED ?? 0)
const pendingOrQueuedTasks = computed(() => {
  const c = stats.task_status_counts || {}
  return (c.PENDING ?? 0) + (c.QUEUED ?? 0)
})
const runningTasks = computed(() => stats.task_status_counts?.RUNNING ?? 0)
const recentScoredTasks = computed(() =>
  recentTasks.value.filter((task) => task.hrd_score != null)
)
const recentPositiveTasks = computed(() =>
  recentScoredTasks.value.filter((task) => Number(task.hrd_score) >= hrdPositiveMin.value)
)

const workQueueItems = computed(() => [
  {
    label: '未开始分析',
    desc: '已建样本但尚未启动分析，适合进入样本详情后排队',
    value: notStartedSamples.value,
    type: notStartedSamples.value > 0 ? 'warning' : 'info',
  },
  {
    label: '排队/运行中',
    desc: '需要关注 Celery Worker、Redis 与生信环境是否在线',
    value: queuedOrRunningSamples.value,
    type: queuedOrRunningSamples.value > 0 ? 'primary' : 'info',
  },
  {
    label: '失败样本',
    desc: '优先查看失败原因和 run.log，修复后可重新启动',
    value: failedSamples.value,
    type: failedSamples.value > 0 ? 'danger' : 'success',
  },
  {
    label: '待执行任务',
    desc: '任务表中仍处于待执行或排队状态的任务数量',
    value: pendingOrQueuedTasks.value,
    type: pendingOrQueuedTasks.value > 0 ? 'warning' : 'info',
  },
])

const resultSummaryItems = computed(() => [
  {
    label: '已完成样本',
    value: completedSamples.value,
    className: 'success',
  },
  {
    label: '最近有评分任务',
    value: recentScoredTasks.value.length,
    className: 'primary',
  },
  {
    label: '最近 HRD 阳性',
    value: recentPositiveTasks.value.length,
    className: recentPositiveTasks.value.length > 0 ? 'danger' : 'success',
  },
  {
    label: '当前阳性阈值',
    value: hrdPositiveMin.value,
    className: 'warning',
  },
  {
    label: '运行中任务',
    value: runningTasks.value,
    className: runningTasks.value > 0 ? 'primary' : '',
  },
  {
    label: '失败任务',
    value: failedTasks.value,
    className: failedTasks.value > 0 ? 'danger' : 'success',
  },
])

const taskStatusLabels = {
  PENDING: '待执行',
  QUEUED: '排队中',
  RUNNING: '运行中',
  SUCCESS: '成功',
  FAILED: '失败',
  CANCELLED: '已取消',
}

const analysisStatusLabels = {
  NOT_STARTED: '未开始',
  QUEUED: '排队中',
  RUNNING: '分析中',
  COMPLETED: '已完成',
  FAILED: '分析失败',
}

const taskStatusLabel = (s) => taskStatusLabels[s] || s || '-'
const analysisStatusLabel = (s) => analysisStatusLabels[s] || s || '-'

const taskTagType = (s) => {
  const m = {
    PENDING: 'warning',
    QUEUED: 'warning',
    RUNNING: 'primary',
    SUCCESS: 'success',
    FAILED: 'danger',
    CANCELLED: 'info',
  }
  return m[s] || 'info'
}

const analysisTagType = (s) => {
  const m = {
    NOT_STARTED: 'info',
    QUEUED: 'warning',
    RUNNING: 'primary',
    COMPLETED: 'success',
    FAILED: 'danger',
  }
  return m[s] || 'info'
}

const formatTime = (iso) => {
  if (!iso) return '-'
  return String(iso).replace('T', ' ').slice(0, 19)
}

const goSamples = () => router.push('/samples')
const goReports = () => router.push('/reports')

const onTaskRowClick = (row) => {
  if (row?.sample_id) router.push(`/samples/${row.sample_id}`)
}

const loadStats = async () => {
  loading.value = true
  try {
    const [data, thr] = await Promise.all([getDashboardStats(), getHrdPositiveMin()])
    hrdPositiveMin.value = thr
    stats.total_samples = data.total_samples ?? 0
    stats.analysis_status_counts = data.analysis_status_counts || {}
    stats.task_status_counts = data.task_status_counts || {}
    stats.recent_tasks = Array.isArray(data.recent_tasks) ? data.recent_tasks : []
  } catch (e) {
    console.error(e)
    ElMessage.error('加载仪表盘数据失败')
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadStats()
})
</script>

<style scoped>
.dashboard-container {
  margin-top: 10px;
}

.welcome-card {
  margin-bottom: 16px;
  border-radius: 10px;
}

.welcome-content {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
}

.welcome-title {
  margin: 0;
  font-size: 22px;
  color: #303133;
}

.welcome-subtitle {
  margin-top: 8px;
  color: #606266;
  font-size: 14px;
  line-height: 1.5;
}

.welcome-note {
  margin: 8px 0 0;
  color: #909399;
  font-size: 13px;
  line-height: 1.5;
}

.stats-row,
.content-row,
.bottom-row {
  margin-bottom: 16px;
}

.bottom-row {
  margin-bottom: 0;
}

.align-row {
  align-items: stretch;
}

.dashboard-col {
  display: flex;
  margin-bottom: 0;
}

.stats-card {
  border-radius: 10px;
  width: 100%;
}

.card-header {
  color: #909399;
  font-size: 14px;
  margin-bottom: 8px;
}

.card-value {
  font-size: 28px;
  font-weight: bold;
  margin-bottom: 6px;
}

.card-footer {
  font-size: 13px;
  color: #909399;
}

.primary {
  color: #409eff;
}

.success {
  color: #67c23a;
}

.warning {
  color: #e6a23c;
}

.danger {
  color: #f56c6c;
}

.section-card {
  border-radius: 10px;
  width: 100%;
}

.section-card :deep(.el-card__body) {
  height: calc(100% - 57px);
}

.task-card {
  min-height: 360px;
}

.dist-card {
  min-height: 360px;
}

.compact-card {
  min-height: 0;
}

.compact-card :deep(.el-card__body) {
  padding-top: 14px;
  padding-bottom: 14px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: bold;
}

.dist-block {
  margin-bottom: 4px;
}

.dist-title {
  font-size: 13px;
  color: #909399;
  margin-bottom: 6px;
}

.dist-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.dist-list li {
  display: flex;
  justify-content: space-between;
  padding: 5px 0;
  border-bottom: 1px solid #ebeef5;
  font-size: 14px;
  color: #606266;
}

.dist-card :deep(.el-divider--horizontal) {
  margin: 12px 0;
}

.hrd-high {
  color: #f56c6c;
  font-weight: 600;
}

.table-hint {
  margin: 10px 0 0;
  font-size: 12px;
  color: #909399;
}

.clickable-table :deep(tbody tr) {
  cursor: pointer;
}

.clickable-table :deep(.cell) {
  white-space: nowrap;
}

.queue-list {
  display: flex;
  flex-direction: column;
}

.queue-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 14px;
  min-height: 58px;
  padding: 8px 0;
  border-bottom: 1px solid #ebeef5;
}

.queue-item:last-child {
  border-bottom: 0;
}

.queue-label {
  color: #303133;
  font-weight: 600;
  margin-bottom: 2px;
}

.queue-desc {
  color: #909399;
  font-size: 13px;
  line-height: 1.35;
}

.result-summary {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px;
}

.summary-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  min-height: 58px;
  padding: 10px 12px;
  background: #f5f7fa;
  border: 1px solid #ebeef5;
  border-radius: 8px;
}

.summary-label {
  color: #606266;
  font-size: 13px;
}

.summary-item strong {
  color: #303133;
  font-size: 18px;
}

.summary-hint {
  margin: 10px 0 0;
  color: #909399;
  font-size: 12px;
  line-height: 1.6;
}

@media (max-width: 991px) {
  .dashboard-col {
    margin-bottom: 16px;
  }

  .align-row .dashboard-col:last-child {
    margin-bottom: 0;
  }

  .task-card,
  .dist-card {
    min-height: 0;
  }
}
</style>
