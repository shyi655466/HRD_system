
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
                    <el-select v-model="statusFilter" placeholder="筛选状态" style="width: 160px;" clearable>
                        <el-option label="已上传" value="uploaded" />
                        <el-option label="分析中" value="running" />
                        <el-option label="已完成" value="completed" />
                        <el-option label="失败" value="failed" />
                    </el-select>
                </div>
            </div>

            <!-- 表格组件 展示样本记录列表 -->
            <!-- :data 表示表格数据源 传入的是JS表达式 -->
            <!-- v-loading 是指令 表示当 loading 为真时 在这个元素表面挂一个加载遮罩层 -->
            <el-table :data="filteredTableData" style="width: 100%" stripe v-loading="loading">
                <el-table-column prop="patientId" label="患者编号" min-width="160" />
                <el-table-column prop="sampleCode" label="样本编号" min-width="160" />

                <el-table-column prop="status" label="分析状态" width="120">
                    <!-- 自定义这一列的单元格显示内容 如果不加插槽 会直接显示status的英文值 -->
                    <template #default="scope">
                        <!-- 只有当当前行的status字段值等于等号右边 才会渲染该标签 -->
                        <!-- '==='是JS的严格相等运算符 不仅值要相等类型也要相同 -->
                        <el-tag v-if="scope.row.status === 'completed'" type="success" effect="light">已完成</el-tag>
                        <el-tag v-else-if="scope.row.status === 'running'" type="primary" effect="light">分析中</el-tag>
                        <el-tag v-else-if="scope.row.status === 'uploaded'" type="warning" effect="light">已上传</el-tag>
                        <el-tag v-else-if="scope.row.status === 'failed'" type="danger" effect="light">失败</el-tag>
                        <el-tag v-else effect="light">
                            {{ scope.row.status }}
                        </el-tag>
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
const statusFilter = ref('')  // 状态筛选框
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

    const matchStatus =
      !statusFilter.value || item.status === statusFilter.value

    return matchQuery && matchStatus
  })
})

const formatDate = (dateStr) => {
  if (!dateStr) return '-'
  return dateStr.replace('T', ' ').slice(0, 19)
}

const goToDetail = (id) => {
  router.push(`/samples/${id}`)
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

.filter-bar {
  display: flex;
  gap: 12px;
  flex-wrap: wrap;
}
</style>