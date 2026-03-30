
<template>
    <div class="samples-container">
        <el-card shadow="never" class="page-card">
            <div class="page-header">
                <div>
                    <h2 class="page-title">样本列表</h2>
                    <p class="page-subtitle">查看样本状态、分析进度与结果概览</p>
                </div>
                <div class="filter-bar">
                    <el-input v-model="searchQuery" placeholder="搜索样本编号或患者编号" style="width: 240px" clearable />
                    <!-- label表示用户在界面上看到的显示文字 value表示每个选项绑定的值 statusFilter则会切换到对应的值 -->
                    <el-select v-model="uploadStatusFilter" placeholder="筛选上传状态" style="width: 160px" clearable>
                      <el-option label="草稿" value="DRAFT" />
                      <el-option label="上传中" value="UPLOADING" />
                      <el-option label="已上传" value="UPLOADED" />
                      <el-option label="上传失败" value="UPLOAD_FAILED" />
                    </el-select>

                    <el-select v-model="analysisStatusFilter" placeholder="筛选分析状态" style="width: 160px" clearable>
                      <el-option label="未开始" value="NOT_STARTED" />
                      <el-option label="排队中" value="QUEUED" />
                      <el-option label="分析中" value="RUNNING" />
                      <el-option label="已完成" value="COMPLETED" />
                      <el-option label="分析失败" value="FAILED" />
                    </el-select>
              
                    <el-button @click="fetchSamples">刷新</el-button>
                    <el-button type="primary" @click="goToServerImport">服务器导入</el-button>
                </div>
            </div>

            <!-- 表格组件 展示样本记录列表 -->
            <!-- :data 表示表格数据源 传入的是JS表达式 -->
            <!-- v-loading 是指令 表示当 loading 为真时 在这个元素表面挂一个加载遮罩层 -->
            <el-table :data="filteredTableData" style="width: 100%" stripe v-loading="loading">
                <el-table-column prop="patientId" label="患者编号" min-width="160" />
                <el-table-column prop="sampleCode" label="样本编号" min-width="160" />

                <el-table-column prop="upload_status" label="上传状态" width="140">
                  <template #default="scope">
                    <el-tag v-if="scope.row.upload_status === 'UPLOADED'" type="success">已上传</el-tag>
                    <el-tag v-else-if="scope.row.upload_status === 'UPLOADING'" type="primary">上传中</el-tag>
                    <el-tag v-else type="info">{{ scope.row.upload_status }}</el-tag>
                  </template>
                </el-table-column>

                <el-table-column prop="analysis_status" label="分析状态" width="140">
                  <template #default="scope">
                    <el-tag v-if="scope.row.analysis_status === 'COMPLETED'" type="success">已完成</el-tag>
                    <el-tag v-else-if="scope.row.analysis_status === 'RUNNING'" type="primary">分析中</el-tag>
                    <el-tag v-else-if="scope.row.analysis_status === 'QUEUED'" type="warning">排队中</el-tag>
                    <el-tag v-else type="info">{{ scope.row.analysis_status }}</el-tag>
                  </template>
                </el-table-column>

                <el-table-column label="HRD评分" width="120">
                    <template #default="scope">
                        {{ scope.row.result?.hrdScore ?? '-' }}
                    </template>
                </el-table-column>

                 <el-table-column label="BRCA状态" width="140">
                    <template #default="scope">
                        {{ scope.row.result?.brcaStatus ?? '-' }}
                    </template>
                </el-table-column>
                
                 <el-table-column label="创建时间" width="180">
                    <template #default="scope">
                        {{ formatDate(scope.row.createAt) }}
                    </template>
                </el-table-column>

                <el-table-column label="操作" min-width="140" fixed="right">
                    <template #default="scope">
                        <!-- type表示按钮风格样式 link表示按钮为链接样式-->
                        <el-button type="primary" link @click="goToDetail(scope.row.id)">查看详情</el-button>
                    </template>
                </el-table-column>                                                                                           
            </el-table>

            <el-empty v-if="!loading && filteredTableData.length === 0" description="暂无样本数据" />
        </el-card>
    </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { useRouter } from 'vue-router'
import { getSampleList } from '../api/sample'

const router = useRouter()

const searchQuery = ref('')  // 搜索框
const uploadStatusFilter = ref('')
const analysisStatusFilter = ref('')
const loading = ref(false)
const tableData = ref([])

const fetchSamples = async () => {
  loading.value = true
  try {
    tableData.value = await getSampleList()
  } catch (error) {
    console.error('获取样本列表失败:', error)
    ElMessage.error('获取样本列表失败')
  } finally {
    loading.value = false
  }
}

const filteredTableData = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()

  return tableData.value.filter((item) => {
    const matchQuery =
      !keyword ||
      item.patientId?.toLowerCase().includes(keyword) ||
      item.sampleCode?.toLowerCase().includes(keyword)

    const matchUploadStatus =
      !uploadStatusFilter.value || item.upload_status === uploadStatusFilter.value

    const matchAnalysisStatus =
      !analysisStatusFilter.value || item.analysis_status === analysisStatusFilter.value

    return matchQuery && matchUploadStatus && matchAnalysisStatus
  })
})

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dateStr.replace('T', ' ').slice(0, 19)
}

const goToDetail = (id) => {
  router.push(`/samples/${id}`)
}

const goToServerImport = () => {
  router.push('/samples/import')
}

onMounted(() => {
  fetchSamples()
})
</script>

<style scoped>
.samples-container {
  padding: 20px;
}

.page-card {
  border-radius: 16px;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
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

.filter-bar {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}
</style>