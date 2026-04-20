<template>
  <div class="report-hub" v-loading="loading">
    <el-card shadow="never" class="hub-card">
      <div class="hub-header">
        <div>
          <h2 class="hub-title">查看报告</h2>
          <p class="hub-subtitle">
            选择分析已完成且具备 HRD 结果的样本，打开同一份「HRD 评分基因检测报告」（含解读、明细与导出）。
          </p>
        </div>
        <el-button type="primary" plain @click="fetchSamples">刷新</el-button>
      </div>

      <el-table :data="samplesWithResult" stripe style="width: 100%" empty-text="暂无可用报告（需分析完成且有 HRD 结果）">
        <el-table-column prop="sampleCode" label="样本编号" min-width="160" />
        <el-table-column prop="patientId" label="患者编号" min-width="140" />
        <el-table-column label="数据类型" width="100">
          <template #default="scope">
            {{ dataTypeLabel(scope.row.dataType) }}
          </template>
        </el-table-column>
        <el-table-column label="HRD 评分" width="110">
          <template #default="scope">
            {{ scope.row.result?.hrdScore ?? '—' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="scope">
            <el-button type="primary" link @click="openReport(scope.row.id)">查看报告</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { getSampleList } from '../api/sample'

const router = useRouter()
const loading = ref(false)
const tableData = ref([])

const samplesWithResult = computed(() =>
  tableData.value.filter((s) => s.result && s.analysis_status === 'COMPLETED')
)

const fetchSamples = async () => {
  loading.value = true
  try {
    tableData.value = await getSampleList()
  } catch (e) {
    console.error(e)
    ElMessage.error('加载样本列表失败')
  } finally {
    loading.value = false
  }
}

const dataTypeLabel = (t) => {
  const map = { WGS: 'WGS', WES: 'WES', SNP_PANEL: 'Panel' }
  return map[t] || t || '—'
}

const openReport = (id) => {
  router.push({ path: `/samples/${id}/report`, query: { from: 'reports' } })
}

onMounted(() => {
  fetchSamples()
})
</script>

<style scoped>
.report-hub {
  max-width: 1100px;
  margin: 0 auto;
}

.hub-card {
  border-radius: 12px;
}

.hub-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  margin-bottom: 20px;
}

.hub-title {
  margin: 0 0 8px;
  font-size: 22px;
  font-weight: 700;
  color: #1f2a44;
}

.hub-subtitle {
  margin: 0;
  font-size: 14px;
  color: #909399;
  line-height: 1.6;
  max-width: 720px;
}
</style>
