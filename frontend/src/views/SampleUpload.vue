<template>
  <div class="upload-page">
    <el-card shadow="never" class="page-card">
      <template #header>
        <div class="card-header">
          <div>
            <h2 class="page-title">服务器导入样本</h2>
          </div>
          <el-tag type="success" effect="light">服务器导入模式</el-tag>
        </div>
      </template>

      <!-- 样本基础信息 -->
      <el-form
        ref="sampleFormRef"
        :model="sampleForm"
        :rules="rules"
        label-width="110px"
        class="sample-form"
      >
        <el-row :gutter="20">
          <el-col :span="8">
            <el-form-item label="患者编号" prop="patient_id">
              <el-input v-model="sampleForm.patient_id" placeholder="如：JZ26056481" clearable />
            </el-form-item>
          </el-col>

          <el-col :span="8">
            <el-form-item label="样本编号" prop="sample_code">
              <el-input v-model="sampleForm.sample_code" placeholder="如：S-JZ26056481-20260321" clearable />
            </el-form-item>
          </el-col>

          <el-col :span="8">
            <el-form-item label="数据类型" prop="data_type">
              <el-select v-model="sampleForm.data_type" placeholder="请选择数据类型" style="width: 100%">
                <el-option label="WGS" value="WGS" />
                <el-option label="WES" value="WES" />
                <el-option label="Panel" value="SNP_PANEL" />
              </el-select>
            </el-form-item>
          </el-col>
        </el-row>

        <el-form-item label="备注说明">
          <el-input
            v-model="sampleForm.description"
            type="textarea"
            :rows="2"
            placeholder="可选：填写样本来源、批次信息等"
          />
        </el-form-item>
      </el-form>

      <el-divider content-position="left">FASTQ 路径配置</el-divider>

      <!-- 文件路径输入 -->
      <div class="path-grid">
        <el-card shadow="hover" class="path-card">
          <template #header>
            <div class="path-card-header">
              <span>Tumor R1</span>
              <el-tag size="small" type="danger" effect="plain">必填</el-tag>
            </div>
          </template>
          <el-input
            v-model="sampleForm.files.TUMOR_R1"
            placeholder="请输入 Tumor R1 在服务器上的绝对路径"
            clearable
          />
          <div class="path-status">
            <el-tag v-if="validationMap.TUMOR_R1 === true" type="success">校验通过</el-tag>
            <el-tag v-else-if="validationMap.TUMOR_R1 === false" type="danger">校验失败</el-tag>
          </div>
        </el-card>

        <el-card shadow="hover" class="path-card">
          <template #header>
            <div class="path-card-header">
              <span>Tumor R2</span>
              <el-tag size="small" type="danger" effect="plain">必填</el-tag>
            </div>
          </template>
          <el-input
            v-model="sampleForm.files.TUMOR_R2"
            placeholder="请输入 Tumor R2 在服务器上的绝对路径"
            clearable
          />
          <div class="path-status">
            <el-tag v-if="validationMap.TUMOR_R2 === true" type="success">校验通过</el-tag>
            <el-tag v-else-if="validationMap.TUMOR_R2 === false" type="danger">校验失败</el-tag>
          </div>
        </el-card>

        <el-card shadow="hover" class="path-card">
          <template #header>
            <div class="path-card-header">
              <span>Normal R1</span>
              <el-tag size="small" type="danger" effect="plain">必填</el-tag>
            </div>
          </template>
          <el-input
            v-model="sampleForm.files.NORMAL_R1"
            placeholder="请输入 Normal R1 在服务器上的绝对路径"
            clearable
          />
          <div class="path-status">
            <el-tag v-if="validationMap.NORMAL_R1 === true" type="success">校验通过</el-tag>
            <el-tag v-else-if="validationMap.NORMAL_R1 === false" type="danger">校验失败</el-tag>
          </div>
        </el-card>

        <el-card shadow="hover" class="path-card">
          <template #header>
            <div class="path-card-header">
              <span>Normal R2</span>
              <el-tag size="small" type="danger" effect="plain">必填</el-tag>
            </div>
          </template>
          <el-input
            v-model="sampleForm.files.NORMAL_R2"
            placeholder="请输入 Normal R2 在服务器上的绝对路径"
            clearable
          />
          <div class="path-status">
            <el-tag v-if="validationMap.NORMAL_R2 === true" type="success">校验通过</el-tag>
            <el-tag v-else-if="validationMap.NORMAL_R2 === false" type="danger">校验失败</el-tag>
          </div>
        </el-card>
      </div>

      <!-- 校验结果 -->
      <el-alert
        v-if="validateSummary"
        :title="validateSummary"
        :type="validateSuccess ? 'success' : 'warning'"
        show-icon
        :closable="false"
        class="result-alert"
      />

      <el-table
        v-if="validateResults.length > 0"
        :data="validateResults"
        border
        style="width: 100%; margin-top: 16px"
      >
        <el-table-column prop="file_role" label="文件角色" width="140" />
        <el-table-column prop="file_name" label="文件名" min-width="260" />
        <el-table-column prop="file_size" label="文件大小(Byte)" min-width="180" />
        <el-table-column prop="message" label="校验结果" min-width="160">
          <template #default="scope">
            <el-tag :type="scope.row.is_valid ? 'success' : 'danger'">
              {{ scope.row.message }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>

      <!-- 操作按钮 -->
      <div class="action-bar">
        <el-button @click="fillDemoPaths">填充测试路径</el-button>
        <el-button type="primary" :loading="validating" @click="handleValidate">
          校验路径
        </el-button>
        <el-button
          type="success"
          :loading="importing"
          :disabled="!validateSuccess"
          @click="handleImport"
        >
          导入样本
        </el-button>
      </div>

      <!-- 导入成功信息 -->
      <el-card v-if="importResult" shadow="never" class="success-card">
        <template #header>
          <div class="path-card-header">
            <span>导入成功</span>
            <el-tag type="success">已入库</el-tag>
          </div>
        </template>

        <el-descriptions :column="2" border>
          <el-descriptions-item label="样本ID">
            {{ importResult.sample.id }}
          </el-descriptions-item>
          <el-descriptions-item label="患者编号">
            {{ importResult.sample.patient_id }}
          </el-descriptions-item>
          <el-descriptions-item label="样本编号">
            {{ importResult.sample.sample_code }}
          </el-descriptions-item>
          <el-descriptions-item label="数据类型">
            {{ importResult.sample.data_type }}
          </el-descriptions-item>
          <el-descriptions-item label="上传状态">
            {{ importResult.sample.upload_status }}
          </el-descriptions-item>
          <el-descriptions-item label="分析状态">
            {{ importResult.sample.analysis_status }}
          </el-descriptions-item>
        </el-descriptions>

        <div class="success-actions">
          <el-button type="primary" @click="goToSampleDetail">查看样本详情</el-button>
        </div>
      </el-card>
    </el-card>
  </div>
</template>

<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { validateServerPaths, importSampleFromServer } from '../api/serverImport'

const router = useRouter()
const sampleFormRef = ref(null)

const validating = ref(false)
const importing = ref(false)
const validateResults = ref([])
const validateSuccess = ref(false)
const validateSummary = ref('')
const importResult = ref(null)

const validationMap = reactive({
  TUMOR_R1: null,
  TUMOR_R2: null,
  NORMAL_R1: null,
  NORMAL_R2: null
})

const sampleForm = reactive({
  patient_id: '',
  sample_code: '',
  data_type: 'WGS',
  description: '',
  files: {
    TUMOR_R1: '',
    TUMOR_R2: '',
    NORMAL_R1: '',
    NORMAL_R2: ''
  }
})

const rules = {
  patient_id: [{ required: true, message: '请输入患者编号', trigger: 'blur' }],
  sample_code: [{ required: true, message: '请输入样本编号', trigger: 'blur' }],
  data_type: [{ required: true, message: '请选择数据类型', trigger: 'change' }]
}

function buildFilesPayload() {
  return [
    { file_role: 'TUMOR_R1', path: sampleForm.files.TUMOR_R1.trim() },
    { file_role: 'TUMOR_R2', path: sampleForm.files.TUMOR_R2.trim() },
    { file_role: 'NORMAL_R1', path: sampleForm.files.NORMAL_R1.trim() },
    { file_role: 'NORMAL_R2', path: sampleForm.files.NORMAL_R2.trim() }
  ]
}

function checkFilePathsFilled() {
  const files = buildFilesPayload()
  return files.every(item => item.path)
}

function resetValidationState() {
  validateResults.value = []
  validateSuccess.value = false
  validateSummary.value = ''
  importResult.value = null

  Object.keys(validationMap).forEach(key => {
    validationMap[key] = null
  })
}

async function handleValidate() {
  try {
    await sampleFormRef.value.validate()
  } catch {
    return
  }

  if (!checkFilePathsFilled()) {
    ElMessage.warning('请先填写完整的 4 个 FASTQ 路径')
    return
  }

  validating.value = true
  resetValidationState()

  try {
    const payload = {
      files: buildFilesPayload()
    }

    const res = await validateServerPaths(payload)
    const data = res.data ?? res

    validateResults.value = data.results || []
    validateSuccess.value = !!data.all_valid
    validateSummary.value = data.all_valid
      ? '路径校验全部通过，可以继续导入样本'
      : '部分路径校验失败，请检查后重试'

    ;(data.results || []).forEach(item => {
      validationMap[item.file_role] = item.is_valid
    })

    if (data.all_valid) {
      ElMessage.success('路径校验通过')
    } else {
      ElMessage.warning('部分路径校验失败')
    }
  } catch (error) {
    console.error(error)
    ElMessage.error(error?.response?.data?.detail || '路径校验失败')
  } finally {
    validating.value = false
  }
}

async function handleImport() {
  try {
    await sampleFormRef.value.validate()
  } catch {
    return
  }

  if (!validateSuccess.value) {
    ElMessage.warning('请先完成路径校验并确保全部通过')
    return
  }

  importing.value = true

  try {
    const payload = {
      patient_id: sampleForm.patient_id.trim(),
      sample_code: sampleForm.sample_code.trim(),
      data_type: sampleForm.data_type,
      description: sampleForm.description.trim(),
      files: buildFilesPayload()
    }

    const res = await importSampleFromServer(payload)
    const data = res.data ?? res

    importResult.value = data
    ElMessage.success('样本导入成功')
  } catch (error) {
    console.error(error)
    ElMessage.error(error?.response?.data?.detail || '样本导入失败')
  } finally {
    importing.value = false
  }
}

function goToSampleDetail() {
  if (!importResult.value?.sample?.id) return
  router.push(`/samples/${importResult.value.sample.id}`)
}

function fillDemoPaths() {
  sampleForm.patient_id = 'JZ26056481'
  sampleForm.sample_code = 'S-JZ26056481-20260321-DEMO'
  sampleForm.data_type = 'WGS'
  sampleForm.description = '服务器导入测试样本'
  sampleForm.files.TUMOR_R1 =
    '/data_storage2/shiyi/git_repo/work_repo/HRD_system/hrd_data/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2T-01_combined_R1.fastq.gz'
  sampleForm.files.TUMOR_R2 =
    '/data_storage2/shiyi/git_repo/work_repo/HRD_system/hrd_data/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2T-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2T-01_combined_R2.fastq.gz'
  sampleForm.files.NORMAL_R1 =
    '/data_storage2/shiyi/git_repo/work_repo/HRD_system/hrd_data/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2N-01_combined_R1.fastq.gz'
  sampleForm.files.NORMAL_R2 =
    '/data_storage2/shiyi/git_repo/work_repo/HRD_system/hrd_data/20260321/Sample_JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2N-01/JZ26056481-wisgen-xj-0319-1-ReasD-HRD-P2N-01_combined_R2.fastq.gz'

  resetValidationState()
}
</script>

<style scoped>
.upload-page {
  padding: 20px;
}

.page-card {
  border-radius: 16px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.page-title {
  margin: 0;
  font-size: 22px;
  font-weight: 600;
  color: #303133;
}

.page-subtitle {
  margin: 8px 0 0;
  color: #909399;
  font-size: 14px;
}

.sample-form {
  margin-top: 8px;
}

.path-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.path-card {
  border-radius: 14px;
}

.path-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.path-status {
  margin-top: 12px;
  min-height: 24px;
}

.result-alert {
  margin-top: 16px;
}

.action-bar {
  display: flex;
  gap: 12px;
  margin-top: 20px;
}

.success-card {
  margin-top: 24px;
  border-radius: 14px;
}

.success-actions {
  margin-top: 16px;
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 992px) {
  .path-grid {
    grid-template-columns: 1fr;
  }
}
</style>