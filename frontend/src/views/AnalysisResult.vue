<template>
  <div class="result-container" v-loading="loading">
    <div class="page-header">
      <div>
        <h2 class="page-title">结果分析报告</h2>
        <p class="page-subtitle">
          查看 HRD 检测结果、关键指标与分析解读（初版不含 PDF）。阳性判定：HRD 总分 ≥ {{ hrdPositiveMin }}。
        </p>
      </div>
      <div class="header-actions">
        <el-button @click="goBack">返回详情</el-button>
        <el-button type="success" :disabled="!canExport" @click="downloadJson">下载 JSON</el-button>
        <el-button type="primary" :disabled="!canExport" @click="downloadCsv">导出 CSV</el-button>
      </div>
    </div>

    <el-empty v-if="!loading && loadError" :description="loadError" />
    <el-empty v-else-if="!loading && sampleDetail && !sampleDetail.result" description="暂无 HRD 结果，请先在样本详情中完成分析" />

    <template v-else-if="!loading && display">
      <el-row :gutter="20" class="overview-row">
        <el-col :span="6">
          <el-card shadow="hover" class="overview-card">
            <div class="card-label">样本编号</div>
            <div class="card-value text">{{ display.sampleCode }}</div>
            <div class="card-footer">患者：{{ display.patientId }}</div>
          </el-card>
        </el-col>

        <el-col :span="6">
          <el-card shadow="hover" class="overview-card">
            <div class="card-label">HRD 总评分</div>
            <div class="card-value primary">{{ display.hrdScore }}</div>
            <div class="card-footer">阳性阈值：≥ {{ hrdPositiveMin }}（含等于）</div>
          </el-card>
        </el-col>

        <el-col :span="6">
          <el-card shadow="hover" class="overview-card">
            <div class="card-label">结果判定</div>
            <div class="card-value" :class="display.positive ? 'danger' : 'success'">
              {{ display.positive ? 'HRD 阳性' : 'HRD 阴性' }}
            </div>
            <div class="card-footer">依据综合评分自动判定</div>
          </el-card>
        </el-col>

        <el-col :span="6">
          <el-card shadow="hover" class="overview-card">
            <div class="card-label">分析时间</div>
            <div class="card-value text">{{ display.reportTime }}</div>
            <div class="card-footer">BRCA：{{ display.brcaLabel }}</div>
          </el-card>
        </el-col>
      </el-row>

      <el-card shadow="never" class="section-card">
        <template #header>
          <div class="section-header">关键指标概览</div>
        </template>

        <el-row :gutter="20">
          <el-col :span="8">
            <div class="metric-card">
              <div class="metric-title">LOH</div>
              <div class="metric-value">{{ display.loh }}</div>
              <div class="metric-desc">杂合性缺失评分</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="metric-card">
              <div class="metric-title">TAI</div>
              <div class="metric-value">{{ display.tai }}</div>
              <div class="metric-desc">端粒等位基因失衡评分</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="metric-card">
              <div class="metric-title">LST</div>
              <div class="metric-value">{{ display.lst }}</div>
              <div class="metric-desc">大片段状态转移评分</div>
            </div>
          </el-col>
        </el-row>
      </el-card>

      <el-row :gutter="20" class="content-row" align="stretch">
        <el-col :span="14" class="stretch-col">
          <el-card shadow="never" class="section-card equal-card">
            <template #header>
              <div class="section-header">结果解读</div>
            </template>

            <el-descriptions :column="1" border>
              <el-descriptions-item label="HRD 总评分">
                {{ display.hrdScore }}
              </el-descriptions-item>
              <el-descriptions-item label="结果判定">
                <el-tag :type="display.positive ? 'danger' : 'success'">
                  {{ display.positive ? 'HRD 阳性' : 'HRD 阴性' }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="结果说明">
                {{ display.summary }}
              </el-descriptions-item>
              <el-descriptions-item label="临床提示">
                {{ display.clinicalSuggestion }}
              </el-descriptions-item>
            </el-descriptions>
          </el-card>
        </el-col>

        <el-col :span="10" class="stretch-col">
          <el-card shadow="never" class="section-card equal-card">
            <template #header>
              <div class="section-header">分析结论</div>
            </template>

            <div class="conclusion-box">
              <div class="conclusion-item">
                <span class="conclusion-label">分析状态</span>
                <el-tag type="success">已完成</el-tag>
              </div>
              <div class="conclusion-item">
                <span class="conclusion-label">HRD 判定</span>
                <el-tag :type="display.positive ? 'danger' : 'success'">
                  {{ display.positive ? '阳性' : '阴性' }}
                </el-tag>
              </div>
              <div class="conclusion-item">
                <span class="conclusion-label">风险提示</span>
                <span class="conclusion-text">{{ display.riskHint }}</span>
              </div>
              <div class="conclusion-item">
                <span class="conclusion-label">建议</span>
                <span class="conclusion-text">
                  建议结合临床表现、病理信息及其他检测结果综合判断。
                </span>
              </div>
            </div>
          </el-card>
        </el-col>
      </el-row>

      <el-card shadow="never" class="section-card">
        <template #header>
          <div class="section-header">指标明细表</div>
        </template>

        <el-table :data="metricTableData" stripe border style="width: 100%">
          <el-table-column prop="item" label="检测项目" width="180" />
          <el-table-column prop="value" label="数值" width="120" />
          <el-table-column prop="status" label="状态" width="140">
            <template #default="scope">
              <el-tag
                :type="scope.row.status === '正常' ? 'success' : 'warning'"
                effect="light"
              >
                {{ scope.row.status }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="remark" label="说明" />
        </el-table>
      </el-card>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getSampleDetail } from '../api/sample'
import { getHrdPositiveMin } from '../api/config'

const route = useRoute()
const router = useRouter()

const loading = ref(false)
const loadError = ref('')
const sampleDetail = ref(null)
const hrdPositiveMin = ref(42)

const sampleId = computed(() => route.params.id)

const fetchData = async () => {
  loading.value = true
  loadError.value = ''
  try {
    const [detail, thr] = await Promise.all([
      getSampleDetail(sampleId.value),
      getHrdPositiveMin(),
    ])
    sampleDetail.value = detail
    hrdPositiveMin.value = thr
  } catch (e) {
    console.error(e)
    loadError.value = '加载样本或结果失败'
    ElMessage.error(loadError.value)
  } finally {
    loading.value = false
  }
}

const display = computed(() => {
  const s = sampleDetail.value
  const r = s?.result
  if (!s || !r) return null
  const hrdRaw = r.hrdScore
  if (hrdRaw == null || hrdRaw === '') return null
  const hrdScore = Number(hrdRaw)
  if (Number.isNaN(hrdScore)) return null
  const thr = hrdPositiveMin.value
  const loh = r.lohScore ?? '-'
  const tai = r.taiScore ?? '-'
  const lst = r.lstScore ?? '-'
  const positive = hrdScore >= thr
  const reportTime = formatDate(r.analysisDate)
  const brcaLabel = brcaText(r.brcaStatus)
  return {
    sampleCode: s.sampleCode || '-',
    patientId: s.patientId || '-',
    hrdScore,
    loh,
    tai,
    lst,
    positive,
    reportTime,
    brcaLabel,
    summary: positive
      ? '该样本 HRD 综合评分达到阳性阈值，提示存在同源重组修复缺陷倾向。'
      : '该样本 HRD 综合评分未达到阳性阈值，未提示明显 HRD 倾向。',
    clinicalSuggestion:
      '建议结合患者临床信息、病理结果及其他分子检测结果进行综合评估。',
    riskHint: positive
      ? '提示存在同源重组修复缺陷倾向'
      : '未提示明显 HRD 倾向',
  }
})

const metricTableData = computed(() => {
  const d = display.value
  if (!d) return []
  const thr = hrdPositiveMin.value
  const high = (v) => (typeof v === 'number' && v >= 10 ? '偏高' : '正常')
  return [
    {
      item: 'LOH',
      value: d.loh,
      status: high(d.loh),
      remark: '杂合性缺失评分',
    },
    {
      item: 'TAI',
      value: d.tai,
      status: high(d.tai),
      remark: '端粒等位基因失衡评分',
    },
    {
      item: 'LST',
      value: d.lst,
      status: high(d.lst),
      remark: '大片段状态转移评分',
    },
    {
      item: 'HRD 综合评分',
      value: d.hrdScore,
      status: d.positive ? '偏高' : '正常',
      remark: d.positive
        ? `达到或超过阳性阈值 ${thr}（≥ 为阳性）`
        : `未达阳性阈值 ${thr}`,
    },
  ]
})

const canExport = computed(() => !!display.value)

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return String(dateStr).replace('T', ' ').slice(0, 19)
}

const brcaText = (raw) => {
  if (raw == null || raw === '') return '未知'
  const map = {
    UNKNOWN: '未知',
    POSITIVE: '阳性',
    NEGATIVE: '阴性',
    VUS: 'VUS',
  }
  return map[raw] || raw
}

const goBack = () => {
  router.push(`/samples/${sampleId.value}`)
}

const downloadJson = () => {
  const s = sampleDetail.value
  if (!s?.result) return
  const payload = {
    sampleId: s.id,
    patientId: s.patientId,
    sampleCode: s.sampleCode,
    dataType: s.dataType,
    result: s.result,
  }
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `${s.sampleCode || s.id}_hrd.json`
  a.click()
  URL.revokeObjectURL(a.href)
}

const downloadCsv = () => {
  const d = display.value
  const s = sampleDetail.value
  if (!d || !s) return
  const header = 'SampleID,LOH,TAI,LST,HRD_Score,BRCA_Status'
  const line = [
    s.sampleCode || s.id,
    d.loh,
    d.tai,
    d.lst,
    d.hrdScore,
    s.result?.brcaStatus || 'UNKNOWN',
  ].join(',')
  const blob = new Blob([`${header}\n${line}\n`], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `${s.sampleCode || s.id}_hrd.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

onMounted(() => {
  fetchData()
})
</script>

<style scoped>
.result-container {
  padding: 10px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.page-title {
  margin: 0;
  font-size: 24px;
  color: #303133;
}

.page-subtitle {
  margin: 6px 0 0;
  color: #909399;
  font-size: 14px;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.overview-row,
.content-row {
  margin-bottom: 20px;
}

.overview-card {
  border-radius: 10px;
}

.card-label {
  color: #909399;
  font-size: 14px;
  margin-bottom: 12px;
}

.card-value {
  font-size: 30px;
  font-weight: bold;
  margin-bottom: 10px;
}

.card-value.text {
  font-size: 20px;
  color: #303133;
  word-break: break-all;
}

.card-value.primary {
  color: #409eff;
}

.card-value.success {
  color: #67c23a;
}

.card-value.danger {
  color: #f56c6c;
}

.card-footer {
  color: #909399;
  font-size: 13px;
}

.section-card {
  margin-bottom: 20px;
  border-radius: 10px;
}

.section-header {
  font-weight: bold;
  color: #303133;
}

.metric-card {
  background: #f8f9fb;
  border-radius: 8px;
  padding: 24px 16px;
  text-align: center;
}

.metric-title {
  color: #909399;
  font-size: 14px;
  margin-bottom: 12px;
}

.metric-value {
  font-size: 34px;
  font-weight: bold;
  color: #409eff;
  margin-bottom: 8px;
}

.metric-desc {
  color: #909399;
  font-size: 13px;
}

.stretch-col {
  display: flex;
}

.equal-card {
  width: 100%;
}

.equal-card :deep(.el-card__body) {
  height: 100%;
  box-sizing: border-box;
}

.conclusion-box {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.conclusion-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.conclusion-label {
  font-size: 14px;
  color: #909399;
}

.conclusion-text {
  color: #303133;
  line-height: 1.8;
}
</style>
