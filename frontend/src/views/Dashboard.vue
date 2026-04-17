<template>
  <div class="dashboard-container" v-loading="loading">
    <el-card shadow="never" class="welcome-card">
      <div class="welcome-content">
        <div>
          <h2 class="welcome-title">欢迎使用 HRD 评分计算系统</h2>
          <p class="welcome-subtitle">
            以下统计与列表均为<strong>当前登录账号</strong>下的真实数据；刷新页面即可更新。
          </p>
          <p class="welcome-note">
            Web/API 能打开本页仅说明前端与接口可用；Celery、Redis、数据库等请在服务器侧自行巡检。
          </p>
        </div>
        <el-tag type="info" size="large">数据已接入后端</el-tag>
      </div>
    </el-card>

    <el-row :gutter="20" class="stats-row">
      <el-col :span="6">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">我的样本</div>
          <div class="card-value primary">{{ stats.total_samples }}</div>
          <div class="card-footer">全部上传/分析状态合计</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">分析已完成</div>
          <div class="card-value success">{{ completedSamples }}</div>
          <div class="card-footer">样本维度 · 状态为「已完成」</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">排队或分析中</div>
          <div class="card-value warning">{{ queuedOrRunningSamples }}</div>
          <div class="card-footer">样本维度 · 排队中 + 分析中</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card shadow="hover" class="stats-card">
          <div class="card-header">分析失败（样本）</div>
          <div class="card-value danger">{{ failedSamples }}</div>
          <div class="card-footer">样本维度 · 状态为「分析失败」</div>
        </el-card>
      </el-col>
    </el-row>

    <el-row :gutter="20" class="content-row">
      <el-col :span="14">
        <el-card shadow="never" class="section-card">
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
            <el-table-column prop="sample_code" label="样本编号" min-width="140" />
            <el-table-column prop="patient_id" label="患者编号" width="120" />
            <el-table-column label="任务状态" width="110">
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
            <el-table-column label="创建时间" min-width="160">
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

      <el-col :span="10">
        <el-card shadow="never" class="section-card">
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

    <el-row :gutter="20" class="bottom-row">
      <el-col :span="12">
        <el-card shadow="never" class="section-card">
          <template #header>
            <div class="section-header">
              <span>快捷操作</span>
            </div>
          </template>
          <div class="quick-actions">
            <el-button type="primary" @click="goImport">服务器导入样本</el-button>
            <el-button @click="goSamples">样本列表</el-button>
          </div>
        </el-card>
      </el-col>
      <el-col :span="12">
        <el-card shadow="never" class="section-card">
          <template #header>
            <div class="section-header">
              <span>当前版本能力说明</span>
            </div>
          </template>
          <ul class="notice-list">
            <li>初版：WGS 全流程分析（服务器路径导入 FASTQ）；结果页支持 JSON/CSV 导出。</li>
            <li>非 WGS 样本可录入，但「开始分析」将提示仅支持 WGS。</li>
            <li>大文件浏览器分片上传、PDF 报告等未在本版本实现。</li>
          </ul>
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
const queuedOrRunningSamples = computed(() => {
  const c = stats.analysis_status_counts || {}
  return (c.QUEUED ?? 0) + (c.RUNNING ?? 0)
})
const failedSamples = computed(() => stats.analysis_status_counts?.FAILED ?? 0)

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
const goImport = () => router.push('/samples/import')

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
  margin-bottom: 20px;
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
  margin-bottom: 20px;
}

.stats-card {
  border-radius: 10px;
}

.card-header {
  color: #909399;
  font-size: 14px;
  margin-bottom: 12px;
}

.card-value {
  font-size: 28px;
  font-weight: bold;
  margin-bottom: 8px;
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
  min-height: 280px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-weight: bold;
}

.dist-block {
  margin-bottom: 8px;
}

.dist-title {
  font-size: 13px;
  color: #909399;
  margin-bottom: 8px;
}

.dist-list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.dist-list li {
  display: flex;
  justify-content: space-between;
  padding: 6px 0;
  border-bottom: 1px solid #ebeef5;
  font-size: 14px;
  color: #606266;
}

.quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.notice-list {
  margin: 0;
  padding-left: 18px;
  color: #606266;
  line-height: 1.9;
  font-size: 14px;
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
</style>
