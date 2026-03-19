
<template>
    <div class="samples-container">
        <el-card shadow="never" class="table-card">
            <!-- 顶部工具栏区域 -->
            <div class="toolbar">
                <!-- 工具栏左侧放搜索框和状态筛选框 -->
                <div class="toolbar-left">
                    <el-input v-model="searchQuery" placeholder="搜索样本编号 / 患者姓名" :prefix-icon="Search" style="width: 250px; margin-right: 15px;" clearable />
                    <!-- label表示用户在界面上看到的显示文字 value表示每个选项绑定的值 statusFilter则会切换到对应的值 -->
                    <el-select v-model="statusFilter" placeholder="运行状态" style="width: 120px;" clearable>
                        <el-option label="已完成" value="success" />
                        <el-option label="计算中" value="running" />
                        <el-option label="排队中" value="pending" />
                        <el-option label="失败" value="error" />
                    </el-select>
                </div>
                <!-- 工具栏右侧放操作按钮 -->
                <div class="toolbar-right">
                    <el-button type="primary" :icon="Plus" @click="openCreateDialog">新建分析任务</el-button>
                    <el-button :icon="Download">导出记录</el-button>
                </div>
            </div>

            <!-- 表格组件 展示样本记录列表 -->
            <!-- :data 表示表格数据源 传入的是JS表达式 -->
            <!-- v-loading 是指令 表示当 loading 为真时 在这个元素表面挂一个加载遮罩层 -->
            <el-table :data="filteredTableData" style="width: 100%" stripe border v-loading="loading">
                <el-table-column prop="sampleId" label="样本编号" width="150" fixed="left" />
                <el-table-column prop="patientName" label="患者姓名" width="120" />
                <el-table-column prop="uploadTime" label="上传时间" width="180" />

                <el-table-column prop="status" label="分析状态" width="120">
                    <!-- 自定义这一列的单元格显示内容 如果不加插槽 会直接显示status的英文值 -->
                    <template #default="scope">
                        <!-- 只有当当前行的status字段值等于等号右边 才会渲染该标签 -->
                        <!-- '==='是JS的严格相等运算符 不仅值要相等类型也要相同 -->
                        <el-tag v-if="scope.row.status === 'success'" type="success" effect="light">已完成</el-tag>
                        <el-tag v-else-if="scope.row.status === 'running'" type="primary" effect="light">计算中</el-tag>
                        <el-tag v-else-if="scope.row.status === 'pending'" type="warning" effect="light">排队中</el-tag>
                        <el-tag v-else-if="scope.row.status === 'error'" type="danger" effect="light">失败</el-tag>
                    </template>
                </el-table-column>

                <el-table-column prop="hrdScore" label="HRD 评分" width="120">
                    <template #default="scope">
                        <span v-if="scope.row.status !== 'success'">--</span>
                        <!-- 对象语法 动态绑定class: 前面是类名，后面是条件 -->
                        <span v-else :class="{'high-score': scope.row.hrdScore >=42}">
                            <!-- 插值表达式 作用是把JS数据显示到页面上 -->
                            {{ scope.row.hrdScore }}
                        </span>
                    </template>
                </el-table-column>

                <el-table-column prop="operator" label="操作人" width="120" />
                
                <el-table-column label="操作" min-width="180" fixed="right">
                    <template #default="scope">
                        <!-- type表示按钮风格样式 link表示按钮为链接样式-->
                        <el-button size="small" type="primary" link :disabled="scope.row.status !== 'success'">查看报告</el-button>
                        <el-button size="small" type="primary" link :disabled="scope.row.status !== 'success'">下载JSON</el-button>
                    </template>
                </el-table-column>                                                                                           
            </el-table>

            <!-- 分页器外层容器 作用是包住分页组件 便于后续布局-->
            <div class="pagination-wrapper">
                <!-- layout 定义分页器显示哪些功能模块以及显示顺序 -->
                <el-pagination v-model:current-page="currentPage" v-model:page-size="pageSize"
                :page-sizes="[10, 20, 50]" background layout="total, sizes, prev, pager, next, jumper" :total="128" />
            </div>
        </el-card>

        <el-dialog v-model="dialogVisible" title="新建 HRD 分析任务" width="600px" destroy-on-close>
            <el-form label-width="100px">
                <el-form-item label="患者姓名" required>
                    <el-input v-model="newTask.patientName" placeholder="请输入患者姓名" />     
                </el-form-item>
                
                <el-form-item label="测序数据" required>
                    <el-upload class="upload-demo" drag action="#" :auto-upload="false" :on-change="handleFileChange" :show-file-list="false">
                        <el-icon class="el-icon--upload"><UploadFilled /></el-icon>
                        <div class="el-upload__text">
                            将测序文件拖到此处，或<em>点击上传</em>
                        </div>
                        <template #tip>
                            <div class="el-upload__tip">
                                支持 .vcf / .gz / .bam 格式文件，文件大小不限（支持断点续传）
                            </div>
                        </template>
                    </el-upload>
                </el-form-item>

                <el-form-item label="上传进度" v-if="selectedFile">
                    <div style="width: 100%;">
                        <div style="margin-bottom: 5px; color: #606266; font-size: 13px;">
                            已选择： {{ selectedFile.name }} ({{ (selectedFile.size / 1024 /1024).toFixed(2) }} MB)
                        </div> 
                        <el-progress :percentage="uploadProgress" :status="uploadStatus" :stroke-width="15" text-inside />
                        <div v-if="uploading" style="margin-top: 5px; color: #E6A23C; font-size: 12px;">
                            正在进行文件切片与校验（模拟）
                        </div>
                    </div>
                </el-form-item>
            </el-form>

            <template #footer>
                <span class="dialog-footer">
                    <el-button @click="dialogVisible = false" :disabled="uploading">取消</el-button>
                    <el-button type="primary" @click="startMockUpload" :loading="uploading">
                        开始上传并分析
                    </el-button>
                </span>
            </template>
        </el-dialog>
    </div>
</template>

<script setup>
import { ref, computed, reactive } from 'vue'
import { Search, Plus, Download, UploadFilled } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'

const searchQuery = ref('')  // 搜索框
const statusFilter = ref('')  // 状态筛选框
const loading = ref(false)

const currentPage = ref(1)
const pageSize = ref(10)

const tableData = ref([
    { sampleId: 'SEQ-20260315-01', patientName: '张**', uploadTime: '2026-03-15 10:23:11', status: 'success', hrdScore: 54, operator: 'Dr. Admin' },
    { sampleId: 'SEQ-20260315-02', patientName: '李**', uploadTime: '2026-03-15 11:05:42', status: 'success', hrdScore: 28, operator: 'Dr. Admin' },
    { sampleId: 'SEQ-20260316-01', patientName: '王**', uploadTime: '2026-03-16 09:12:00', status: 'running', hrdScore: null, operator: 'Dr. Admin' },
    { sampleId: 'SEQ-20260316-02', patientName: '赵**', uploadTime: '2026-03-16 09:15:30', status: 'pending', hrdScore: null, operator: 'Dr. Admin' },
    { sampleId: 'SEQ-20260316-03', patientName: '陈**', uploadTime: '2026-03-16 09:40:11', status: 'error', hrdScore: null, operator: 'Dr. Admin' },
    { sampleId: 'SEQ-20260317-01', patientName: '刘**', uploadTime: '2026-03-17 08:30:00', status: 'success', hrdScore: 61, operator: 'Dr. Admin' },
])

const filteredTableData = computed(() => {
    return tableData.value.filter(item => {
        const matchQuery = item.sampleId.includes(searchQuery.value) || item.patientName.includes(searchQuery.value)
        const matchStatus = statusFilter.value ? item.status === statusFilter.value : true
        return matchQuery && matchStatus
    })
})

const dialogVisible = ref(false)
const uploading = ref(false)
const uploadProgress = ref(0)
const uploadStatus = ref('')
const selectedFile = ref(null)

const newTask = reactive({
    patientName: ''
})

const openCreateDialog = () => {
    dialogVisible.value = true
    uploading.value = false
    uploadProgress.value = 0
    uploadStatus.value = ''
    selectedFile.value = null
    newTask.patientName = ''
}

const handleFileChange = (uploadFile) => {
    const file = uploadFile.raw
    const validExtensions = ['.vcf', '.gz', '.bam']
    const isValid = validExtensions.some(ext => file.name.toLowerCase().endsWith(ext))

    if (!isValid) {
        ElMessage.error('只能上传 .vcf / .vcf.gz / .bam 格式的测序文件')
        return
    }

    selectedFile.value = file
    uploadProgress.value = 0
    uploadStatus.value = ''

    // 这里我们用定时器模拟分片上传的进度
    let currentChunk = 0
    const totalChunks = 100 // 假装切了 100 片
    
    const timer = setInterval(() => {
        currentChunk += Math.floor(Math.random() * 10) + 1 // 模拟网速波动
        if (currentChunk >= totalChunks) {
        currentChunk = totalChunks
        clearInterval(timer)
        uploadStatus.value = 'success'
        uploading.value = false
        ElMessage.success('文件上传完毕！任务已加入 Celery 队列进行分析。')
        
        // 模拟将新任务加到表格里
        setTimeout(() => {
            dialogVisible.value = false
            tableData.value.unshift({
            sampleId: `SEQ-202603${Math.floor(Math.random() * 100)}`,
            patientName: newTask.patientName,
            uploadTime: new Date().toLocaleString(),
            status: 'pending',
            hrdScore: null,
            operator: 'Dr. Admin'
            })
        }, 1000)
        }
        uploadProgress.value = currentChunk
    }, 200) // 每 0.2 秒推进一次进度
}

const startMockUpload = () => {
    if (!newTask.patientName.trim()) {
        ElMessage.warning('请先输入患者姓名')
        return
    }

    if (!selectedFile.value) {
        ElMessage.warning('请先选择测序文件')
    }

    uploading.value = true
    uploadProgress.value = 0
    uploadStatus.value = 100

    // 模拟分片上传
    let currentChunk = 0
    const totalChunks = 100

    const timer = setInterval(() => {
        currentChunk += Math.floor(Math.random() * 10) + 1

        if (currentChunk >= totalChunks ) {
            currentChunk = totalChunks
            clearInterval(timer)

            uploadProgress.value = 100
            uploadStatus.value = 'success'
            uploading.value = false

            ElMessage.success('文件上传完毕！任务已加入分析队列。')

            tableData.value.unshift({
                sampleId: 'SEQ-${Date.now()}',
                patientName: newTask.patientName,
                uploadTime: new Date().toLocaleString(),
                status: 'pending',
                hrdScore: null,
                operator: 'Dr. Admin'
            })
            
            setTimeout(() => {
                dialogVisible.value = false
            }, 800)
        } else {
            uploadProgress.value = currentChunk
        }
    }, 200)
}

</script>

<style scoped>
.samples-container {
    padding: 10px;
}
.table-card {
    border-radius: 8px;
}
.toolbar {
    display: flex;
    justify-content: space-between;
    margin-bottom: 20px;
}
.toolbar-left {
    display: flex;
    align-items: center;
}
.pagination-wrapper {
    margin-top: 20px;
    display: flex;
    justify-content: flex-end;
}
.high-score {
    color: #F56C6C;
    font-weight: bold;
}
/* 上传组件样式重置 */
:deep(.el-upload-dragger) {
  padding: 20px;
}
</style>