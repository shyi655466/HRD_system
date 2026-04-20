<!--
  HRD 统一报告页（原「分析结果」+ HTML 报告合并）
  字段说明见各节；导出 JSON/CSV 与原先结果页一致。
-->
<template>
  <div class="hrd-report-page" v-loading="loading">
    <header class="report-toolbar no-print">
      <div class="report-toolbar-left">
        <el-button @click="goBack">{{ backLabel }}</el-button>
      </div>
      <div class="report-toolbar-right">
        <el-button type="success" :disabled="!canExport" @click="downloadJson">下载 JSON</el-button>
        <el-button type="primary" :disabled="!canExport" @click="downloadCsv">导出 CSV</el-button>
        <el-button type="primary" plain @click="handlePrint">打印 / 另存 PDF</el-button>
      </div>
    </header>

    <div v-if="loadError" class="report-error">
      <el-alert type="error" :title="loadError" show-icon :closable="false" />
      <el-button class="mt-12" @click="goBack">返回</el-button>
    </div>

    <div v-else-if="!loading && sample && !sample.result" class="report-empty">
      <el-empty description="暂无 HRD 结果，请先在样本详情中完成分析" />
      <el-button type="primary" @click="goBack">返回样本详情</el-button>
    </div>

    <template v-else-if="!loading && sample?.result && display">
      <!-- 屏幕端速览（打印时隐藏） -->
      <div class="report-overview no-print">
        <el-row :gutter="16">
          <el-col :xs="24" :sm="12" :lg="6">
            <el-card shadow="hover" class="ov-card">
              <div class="ov-label">样本编号</div>
              <div class="ov-value text">{{ display.sampleCode }}</div>
              <div class="ov-foot">患者：{{ display.patientId }}</div>
            </el-card>
          </el-col>
          <el-col :xs="24" :sm="12" :lg="6">
            <el-card shadow="hover" class="ov-card">
              <div class="ov-label">HRD 总评分</div>
              <div class="ov-value primary">{{ display.hrdScore }}</div>
              <div class="ov-foot">阳性阈值：≥ {{ hrdPositiveMin }}</div>
            </el-card>
          </el-col>
          <el-col :xs="24" :sm="12" :lg="6">
            <el-card shadow="hover" class="ov-card">
              <div class="ov-label">结果判定</div>
              <div class="ov-value" :class="display.positive ? 'danger' : 'success'">
                {{ display.positive ? 'HRD 阳性' : 'HRD 阴性' }}
              </div>
              <div class="ov-foot">依据综合评分自动判定</div>
            </el-card>
          </el-col>
          <el-col :xs="24" :sm="12" :lg="6">
            <el-card shadow="hover" class="ov-card">
              <div class="ov-label">分析时间</div>
              <div class="ov-value text">{{ display.reportTime }}</div>
              <div class="ov-foot">BRCA：{{ display.brcaLabel }}</div>
            </el-card>
          </el-col>
        </el-row>

        <el-row :gutter="16" class="metric-row">
          <el-col :span="8">
            <div class="metric-tile">
              <div class="metric-tile-title">LOH</div>
              <div class="metric-tile-value">{{ display.loh }}</div>
              <div class="metric-tile-desc">杂合性缺失评分</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="metric-tile">
              <div class="metric-tile-title">TAI</div>
              <div class="metric-tile-value">{{ display.tai }}</div>
              <div class="metric-tile-desc">端粒等位基因失衡评分</div>
            </div>
          </el-col>
          <el-col :span="8">
            <div class="metric-tile">
              <div class="metric-tile-title">LST</div>
              <div class="metric-tile-value">{{ display.lst }}</div>
              <div class="metric-tile-desc">大片段状态转移评分</div>
            </div>
          </el-col>
        </el-row>
      </div>

      <article class="report-sheet">
        <h1 class="report-main-title">HRD 评分基因检测报告</h1>
        <p class="report-sub">整合 HRD 评分、解读与指标明细；打印时仅输出以下正式章节。</p>
        <p v-if="sample.result?.reportPath" class="report-file-hint no-print">
          异步生成的静态 HTML 报告文件：<code>{{ sample.result.reportPath }}</code>
        </p>

        <section class="report-section">
          <h2 class="report-section-title">一、样本与检测信息</h2>
          <el-descriptions :column="2" border size="small" class="report-desc">
            <el-descriptions-item label="样本编号">{{ sample.sampleCode || '—' }}</el-descriptions-item>
            <el-descriptions-item label="患者编号">{{ sample.patientId || '—' }}</el-descriptions-item>
            <el-descriptions-item label="数据类型">{{ dataTypeLabel(sample.dataType) }}</el-descriptions-item>
            <el-descriptions-item label="输入类型">{{ dataTypeLabel(sample.result.inputType) }}</el-descriptions-item>
            <el-descriptions-item label="参考基因组">{{ sample.result.genomeBuild || '—' }}</el-descriptions-item>
            <el-descriptions-item label="分析管道版本">{{ sample.result.pipelineVersion || '—' }}</el-descriptions-item>
            <el-descriptions-item label="分析时间" :span="2">{{ formatDate(sample.result.analysisDate) }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section class="report-section">
          <h2 class="report-section-title">二、HRD 评分结果</h2>
          <p class="report-threshold">
            阳性判定标准：HRD 综合评分 ≥ {{ hrdPositiveMin }} 为阳性；&lt; {{ hrdPositiveMin }} 为阴性。
          </p>
          <el-descriptions :column="2" border size="small" class="report-desc">
            <el-descriptions-item label="LOH">{{ fmtNum(sample.result.lohScore) }}</el-descriptions-item>
            <el-descriptions-item label="TAI">{{ fmtNum(sample.result.taiScore) }}</el-descriptions-item>
            <el-descriptions-item label="LST">{{ fmtNum(sample.result.lstScore) }}</el-descriptions-item>
            <el-descriptions-item label="HRD 综合评分">{{ fmtNum(sample.result.hrdScore) }}</el-descriptions-item>
            <el-descriptions-item label="HRD 判定">{{ hrdJudge }}</el-descriptions-item>
            <el-descriptions-item label="BRCA 状态（与 HRD 阈值一致）">{{ brcaLabelText(sample.result.brcaStatus) }}</el-descriptions-item>
          </el-descriptions>
        </section>

        <section class="report-section">
          <h2 class="report-section-title">三、结果解读与结论</h2>
          <el-descriptions :column="1" border size="small" class="report-desc">
            <el-descriptions-item label="HRD 总评分">{{ display.hrdScore }}</el-descriptions-item>
            <el-descriptions-item label="结果判定">
              <el-tag :type="display.positive ? 'danger' : 'success'" size="small">
                {{ display.positive ? 'HRD 阳性' : 'HRD 阴性' }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="结果说明">{{ display.summary }}</el-descriptions-item>
            <el-descriptions-item label="临床提示">{{ display.clinicalSuggestion }}</el-descriptions-item>
          </el-descriptions>
          <div class="conclusion-block">
            <div class="conclusion-line">
              <span class="conclusion-k">分析状态</span>
              <el-tag type="success" size="small">已完成</el-tag>
            </div>
            <div class="conclusion-line">
              <span class="conclusion-k">HRD 判定</span>
              <el-tag :type="display.positive ? 'danger' : 'success'" size="small">
                {{ display.positive ? '阳性' : '阴性' }}
              </el-tag>
            </div>
            <div class="conclusion-line">
              <span class="conclusion-k">风险提示</span>
              <span class="conclusion-v">{{ display.riskHint }}</span>
            </div>
            <div class="conclusion-line">
              <span class="conclusion-k">建议</span>
              <span class="conclusion-v">建议结合临床表现、病理信息及其他检测结果综合判断。</span>
            </div>
          </div>
        </section>

        <section class="report-section">
          <h2 class="report-section-title">四、指标明细</h2>
          <el-table :data="metricTableData" stripe border size="small" class="report-table">
            <el-table-column prop="item" label="检测项目" width="160" />
            <el-table-column prop="value" label="数值" width="100" />
            <el-table-column prop="status" label="状态" width="100">
              <template #default="scope">
                <el-tag :type="scope.row.status === '正常' ? 'success' : 'warning'" effect="light" size="small">
                  {{ scope.row.status }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="remark" label="说明" min-width="200" />
          </el-table>
        </section>

        <section v-if="hasQcMetrics" class="report-section">
          <h2 class="report-section-title">五、质控信息</h2>
          <pre class="report-pre">{{ qcMetricsFormatted }}</pre>
        </section>

        <section class="report-section">
          <h2 class="report-section-title">{{ methodSectionTitle }}、方法学说明</h2>
          <p class="report-body-text">
            HRD 综合评分基于 scarHRD 等方法对 LOH、TAI、LST 等指标整合计算；具体参数与参考基因组版本见上文。
            本报告仅供科研与演示用途，临床决策需结合病理及其他检测。
          </p>
        </section>
      </article>
    </template>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getSampleDetail } from '../api/sample'
import { getHrdPositiveMin } from '../api/config'

const route = useRoute()
const router = useRouter()

const loading = ref(true)
const loadError = ref('')
const sample = ref(null)
const hrdPositiveMin = ref(42)

const sampleId = computed(() => route.params.id)

const backLabel = computed(() =>
  route.query.from === 'reports' ? '返回报告入口' : '返回样本详情'
)

const fetchData = async () => {
  loading.value = true
  loadError.value = ''
  try {
    const [detail, thr] = await Promise.all([
      getSampleDetail(sampleId.value),
      getHrdPositiveMin(),
    ])
    sample.value = detail
    hrdPositiveMin.value = thr
  } catch (e) {
    console.error(e)
    loadError.value = '加载样本失败'
  } finally {
    loading.value = false
  }
}

const display = computed(() => {
  const s = sample.value
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
  const brcaLabel = brcaLabelText(r.brcaStatus)
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
    clinicalSuggestion: '建议结合患者临床信息、病理结果及其他分子检测结果进行综合评估。',
    riskHint: positive ? '提示存在同源重组修复缺陷倾向' : '未提示明显 HRD 倾向',
  }
})

const metricTableData = computed(() => {
  const d = display.value
  if (!d) return []
  const thr = hrdPositiveMin.value
  const high = (v) => (typeof v === 'number' && v >= 10 ? '偏高' : '正常')
  return [
    { item: 'LOH', value: d.loh, status: high(d.loh), remark: '杂合性缺失评分' },
    { item: 'TAI', value: d.tai, status: high(d.tai), remark: '端粒等位基因失衡评分' },
    { item: 'LST', value: d.lst, status: high(d.lst), remark: '大片段状态转移评分' },
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

const hrdJudge = computed(() => {
  const r = sample.value?.result
  if (!r || r.hrdScore == null || r.hrdScore === '') return '—'
  const v = Number(r.hrdScore)
  if (Number.isNaN(v)) return '—'
  return v >= hrdPositiveMin.value ? 'HRD 阳性' : 'HRD 阴性'
})

const hasQcMetrics = computed(() => {
  const q = sample.value?.result?.qcMetrics
  return q != null && typeof q === 'object' && Object.keys(q).length > 0
})

const qcMetricsFormatted = computed(() => {
  try {
    return JSON.stringify(sample.value?.result?.qcMetrics ?? {}, null, 2)
  } catch {
    return '—'
  }
})

const methodSectionTitle = computed(() => (hasQcMetrics.value ? '六' : '五'))

const goBack = () => {
  if (route.query.from === 'reports') {
    router.push('/reports')
    return
  }
  router.push(`/samples/${sampleId.value}`)
}

const handlePrint = () => {
  window.print()
}

const downloadJson = () => {
  const s = sample.value
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
  const s = sample.value
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

const formatDate = (dateStr) => {
  if (!dateStr) return '—'
  return String(dateStr).replace('T', ' ').slice(0, 19)
}

const dataTypeLabel = (t) => {
  const map = { WGS: 'WGS', WES: 'WES', SNP_PANEL: 'SNP Panel' }
  return map[t] || t || '—'
}

const fmtNum = (n) => {
  if (n == null || n === '') return '—'
  return n
}

const brcaLabelText = (raw) => {
  if (raw == null || raw === '') return '—'
  const map = {
    UNKNOWN: '未知',
    POSITIVE: '阳性',
    NEGATIVE: '阴性',
    VUS: 'VUS',
  }
  return map[raw] || raw
}

onMounted(() => {
  fetchData()
})
</script>

<style scoped>
.hrd-report-page {
  min-height: 100%;
  padding: 20px 24px 48px;
  background: #f0f2f5;
}

.report-toolbar {
  max-width: 1000px;
  margin: 0 auto 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 12px;
}

.report-toolbar-right {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.report-error,
.report-empty {
  max-width: 560px;
  margin: 48px auto;
  text-align: center;
}

.mt-12 {
  margin-top: 12px;
}

.report-overview {
  max-width: 1000px;
  margin: 0 auto 20px;
}

.ov-card {
  border-radius: 10px;
  margin-bottom: 16px;
}

.ov-label {
  color: #909399;
  font-size: 13px;
  margin-bottom: 8px;
}

.ov-value {
  font-size: 26px;
  font-weight: 700;
  margin-bottom: 8px;
}

.ov-value.text {
  font-size: 18px;
  font-weight: 600;
  color: #303133;
  word-break: break-all;
}

.ov-value.primary {
  color: #409eff;
}

.ov-value.success {
  color: #67c23a;
}

.ov-value.danger {
  color: #f56c6c;
}

.ov-foot {
  font-size: 12px;
  color: #909399;
}

.metric-row {
  margin-top: 4px;
}

.metric-tile {
  background: #f8f9fb;
  border-radius: 8px;
  padding: 16px;
  text-align: center;
  margin-bottom: 16px;
}

.metric-tile-title {
  color: #909399;
  font-size: 13px;
  margin-bottom: 8px;
}

.metric-tile-value {
  font-size: 28px;
  font-weight: 700;
  color: #409eff;
  margin-bottom: 6px;
}

.metric-tile-desc {
  font-size: 12px;
  color: #909399;
}

.report-sheet {
  max-width: 1000px;
  margin: 0 auto;
  padding: 32px 40px 40px;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 1px 8px rgba(31, 42, 68, 0.08);
}

.report-main-title {
  margin: 0 0 8px;
  font-size: 22px;
  font-weight: 700;
  color: #1f2a44;
  text-align: center;
}

.report-sub {
  margin: 0 0 28px;
  text-align: center;
  font-size: 13px;
  color: #909399;
}

.report-file-hint {
  margin: -16px 0 20px;
  text-align: center;
  font-size: 12px;
  color: #606266;
  word-break: break-all;
}

.report-file-hint code {
  font-size: 11px;
  background: #f5f7fa;
  padding: 2px 6px;
  border-radius: 4px;
}

.report-section {
  margin-bottom: 28px;
}

.report-section:last-child {
  margin-bottom: 0;
}

.report-section-title {
  margin: 0 0 14px;
  font-size: 16px;
  font-weight: 600;
  color: #1f2a44;
  padding-bottom: 8px;
  border-bottom: 1px solid #ebeef5;
}

.report-threshold {
  margin: 0 0 12px;
  font-size: 13px;
  color: #606266;
  line-height: 1.6;
}

.report-desc {
  margin-top: 0;
}

.report-body-text {
  font-size: 14px;
  color: #303133;
  line-height: 1.75;
  margin: 0;
}

.conclusion-block {
  margin-top: 16px;
  padding: 16px;
  background: #fafafa;
  border-radius: 8px;
  border: 1px solid #ebeef5;
}

.conclusion-line {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 10px;
  margin-bottom: 12px;
}

.conclusion-line:last-child {
  margin-bottom: 0;
}

.conclusion-k {
  min-width: 72px;
  font-size: 13px;
  color: #909399;
}

.conclusion-v {
  flex: 1;
  font-size: 14px;
  color: #303133;
  line-height: 1.7;
}

.report-table {
  width: 100%;
}

.report-pre {
  margin: 0;
  padding: 12px 14px;
  font-size: 12px;
  line-height: 1.5;
  background: #f5f7fa;
  border: 1px solid #ebeef5;
  border-radius: 8px;
  overflow: auto;
  white-space: pre-wrap;
  word-break: break-word;
  font-family: ui-monospace, Menlo, Monaco, Consolas, monospace;
}

@media print {
  .no-print {
    display: none !important;
  }

  .hrd-report-page {
    padding: 0;
    background: #fff;
  }

  .report-sheet {
    box-shadow: none;
    max-width: none;
    padding: 16px 0;
  }
}
</style>
