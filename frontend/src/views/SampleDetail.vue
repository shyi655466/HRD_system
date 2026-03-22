
<template>
    <div class="detail-container">
        <!-- 页面头部 -->
        <div class="page-header">
            <div>
                <h2 class="page-title">样本详情</h2>
                <p class="page-subtitle">查看样本基础信息、分析进度与 HRD 结果摘要</p>
            </div>
            <div class="header-actions">
                <el-button @click="goBack">返回列表</el-button>
                <el-button type="primary" :disabled="sample.status !== 'success'">查看完整报告</el-button>
            </div>
        </div>

         <!-- 操作区 -->
        <el-card shadow="never" class="section-card action-card">
            <template #header>
                <div class="section-header">操作区</div>
            </template>

            <div class="action-buttons">
                <el-button>重新加载状态</el-button>
                <el-button>重新分析</el-button>
                <el-button>下载 JSON</el-button>
                <el-button @click="goToResult">查看完整报告</el-button>
            </div>
        </el-card>

        <!-- 基础信息 -->
        <el-card shadow="never" class="section-card">
            <template #header>
                <div class="section-header">基础信息</div>
            </template>

            <el-row :gutter="20">
                <el-col :span="8">
                    <div class="info-item">
                        <span class="label">样本编号</span>
                        <span class="value">{{ sample.sampleId }}</span>
                    </div>
                </el-col>
                <el-col :span="8">
                    <div class="info-item">
                        <span class="label">患者姓名</span>
                        <span class="value">{{ sample.patientName }}</span>
                    </div>
                </el-col>
                <el-col :span="8">
                    <div class="info-item">
                       <span class="label">操作人</span>
                       <span class="value">{{ sample.operator }}</span>
                    </div>
                </el-col>
                <el-col :span="8">
                    <div class="info-item">
                        <span class="label">上传时间</span>
                        <span class="value">{{ sample.uploadTime }}</span>
                    </div>
                </el-col>
                <el-col :span="8">
                    <div class="info-item">
                        <span class="label">文件名称</span>
                        <span class="value">{{ sample.fileName }}</span>
                    </div>
                </el-col>
                <el-col :span="8">
                    <div class="info-item">
                        <span class="label">文件大小</span>
                        <span class="value">{{ sample.fileSize }}</span>
                    </div>
                </el-col>
            </el-row>
        </el-card>

        <!-- 状态概览 -->
        <el-row :gutter="20" class="overview-card">
            <el-col :span="8">
                <el-card shadow="hover" class="overview-card">
                    <div class="overview-label">当前分析状态</div>
                    <div class="overview-value">
                        <el-tag v-if="sample.status === 'success'" type="success" size="large">已完成</el-tag>
                        <el-tag v-else-if="sample.status === 'running'" type="primary" size="large">计算中</el-tag>
                        <el-tag v-else-if="sample.status === 'pending'" type="warning" size="large">排队中</el-tag>
                        <el-tag v-else-if="sample.status === 'error'" type="danger" size="large">失败</el-tag>
                    </div>
                    <div class="overview-footer">任务提交后由 Celery 异步调度执行</div>
                </el-card>
            </el-col>

            <el-col :span="8">
                <el-card shadow="hover" class="overview-card">
                    <div class="overview-label">HRD 评分</div>
                    <div class="overview-value">
                        <span v-if="sample.status !== 'success'">--</span>
                        <span v-else :class="{ 'high-score': sample.hrdscore >= 42 }">
                            {{ sample.hrdScore }}
                        </span>
                    </div>
                    <div class="overview-footer">
                        <span v-if="sample.status !== 'success'">分析完成后显示</span>
                        <span v-else>
                            {{ sample.hrdScore >=42 ? '提示 HRD 阳性倾向' : '提示 HRD 阴性倾向' }}
                        </span>
                    </div>
                </el-card>
            </el-col>

            <el-col :span="8">
                <el-card shadow="hover" class="overview-card">
                    <div class="overview-label">任务进度</div>
                    <div class="overview-value">
                        {{ progressText }}
                    </div>
                    <div class="overview-footer">
                        <el-progress :percentage="progressPercentage" :status="progressStatus" :stroke-width="14" />
                    </div>
                </el-card>
            </el-col>
        </el-row>

        <!-- 详细结果 + 运行记录 -->
        <el-row :gutter="20" class="content-row">
            <!-- 结果摘要 -->
            <el-col :span="16">
                <el-card shadow="never" class="section-card">
                    <template #header>
                        <div class="section-header">分析结果摘要</div>
                    </template>

                    <div v-if="sample.status === 'success'">
                        <el-row :gutter="20" class="metric-row">
                            <el-col :span="8">
                                <div class="metric-card">
                                    <div class="metric-label">LOH</div>
                                    <div class="metric-value">{{ result.loh }}</div>
                                </div>
                            </el-col>
                            <el-col :span="8">
                                <div class="metric-card">
                                    <div class="metric-label">TAI</div>
                                    <div class="metric-value">{{ result.tai }}</div>
                                </div>
                            </el-col>
                            <el-col :span="8">
                                <div class="metric-card">
                                    <div class="metric-label">LST</div>
                                    <div class="metric-value">{{ result.lst }}</div>
                                </div>
                            </el-col>
                        </el-row>

                        <el-descriptions :column="1" border class="result-desc">
                            <el-descriptions-item label="HRD 评分">
                                {{ sample.hrdScore }}
                            </el-descriptions-item>
                            <el-descriptions-item label="结果判定">
                                <el-tag :type="sample.hrdScore >= 42 ? 'danger' : 'success'">
                                    {{ sample.hrdScore >= 42 ? 'HRD 阳性' : 'HRD 阴性' }}
                                </el-tag>
                            </el-descriptions-item>
                            <el-descriptions-item label="结果说明">
                                {{ result.summary }}
                            </el-descriptions-item>
                        </el-descriptions>
                    </div>

                    <el-empty v-else description="当前样本尚未生成分析结果" />
                </el-card>
            </el-col>

            <!-- 运行记录 -->
            <el-col :span="8">
                <el-card shadow="never" class="section-card">
                    <template #header>
                        <div class="section-header">运行记录</div>
                    </template>

                    <el-timeline>
                        <el-timeline-item v-for="(item, index) in timeline" :key="index" :timestamp="item.time" :type="item.type" >
                            {{ item.content }}
                        </el-timeline-item>
                    </el-timeline>
                </el-card>
            </el-col>
        </el-row>
    </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()

const sample = {
    sampleId: 'SEQ-20260318-01',
    patientName: '张**',
    uploadTime: '2026-03-18 09:30:21',
    status: 'success',
    hrdScore: 54,
    operator: 'Dr. Admin',
    fileName: 'patient_001.vcf.gz',
    fileSize: '1.86 GB'
}

const result = {
    loh: 18,
    tai: 21,
    lst: 15,
    summary: '该样本 HRD 综合评分较高，提示存在同源重组修复缺陷倾向，建议结合临床信息与其他检测结果进一步评估。'
}

const timeline = [
    { time: '2026-03-18 09:30:21', content: '样本上传成功，任务已创建', type: 'primary' },
    { time: '2026-03-18 09:32:10', content: '任务进入 Celery 队列，等待调度', type: 'warning' },
    { time: '2026-03-18 09:35:48', content: '分析任务开始执行', type: 'primary' },
    { time: '2026-03-18 09:52:16', content: 'HRD 评分计算完成', type: 'success' },
    { time: '2026-03-18 09:53:02', content: '结果写入数据库并可供查看', type: 'success' }
]

const progressPercentage = computed(() => {
    if (sample.status === 'pending') return 20
    if (sample.status === 'running') return 65
    if (sample.status === 'success') return 100
    if (sample.status === 'error') return 100
    return 0
})

const progressStatus = computed(() => {
    if (sample.status === 'error') return 'exception'
    if (sample.status === 'success') return 'success'
    return ''
})

const progressText = computed(() => {
    if (sample.status === 'pending') return '20%'
    if (sample.status === 'running') return '65%'
    if (sample.status === 'success') return '100%'
    if (sample.status === 'error') return '失败'
    return '--'
})

const goBack = () => {
    router.push('/sample')
}

const goToResult = () => {
    router.push(`/results/${sample.sampleId}`)
}
</script>


<style scoped>
.detail-container {
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

.content-row {
    margin-bottom: 20px;
}

.section-card {
    margin-bottom: 20px;
    border-radius: 10px;
}

.section-header {
    font-weight: bold;
    color: #303133;
}

.info-item {
    display: flex;
    flex-direction: column;
    margin-bottom: 20px;
}

.label {
    font-size: 13px;
    color: #909399;
    margin-bottom: 6px;
}

.value {
    font-size: 15px;
    color: #303133;
    font-weight: 500;
}

.overview-row {
    margin-bottom: 20px;
}

.overview-card {
    border-radius: 10px;
    min-height: 160px;
    /* margin-bottom: 10px; */
}

.overview-label {
    font-size: 14px;
    color: #909399;
    margin-bottom: 16px;
}

.overview-value {
    font-size: 28px;
    font-weight: bold;
    color: #303133;
    margin-bottom: 14px;
}

.overview-footer {
    font-size: 13px;
    color: #909399;
}

.metric-row {
    margin-bottom: 20px;
}

.metric-card {
    background: #f8f9fb;
    border-radius: 8px;
    padding: 18px;
    text-align: center;
}

.metric-label {
    font-size: 13px;
    color: #909399;
    margin-bottom: 8px;
}

.metric-value {
    font-size: 26px;
    font-weight: bold;
    color: #409EFF;
}

.result-desc {
    margin-top: 10px;
}

.action-card {
    margin-bottom: 0;
}

.action-buttons {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
}

.high-score {
    color: #F56C6C;
    font-weight: bold;
}
</style>