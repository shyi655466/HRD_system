<template>
    <div class="result-container">
        <!-- 页面头部 -->
        <div class="page-header">
            <div>
                <h2 class="page-title">结果分析报告</h2>
                <p class="page-subtitle">查看 HRD 检测结果、关键指标与分析解读</p>
            </div>
            <div class="header-actions">
                <el-button @click="goBack">返回详情</el-button>
                <el-button type="success">下载 JSON</el-button>
                <el-button type="primary">导出报告</el-button>
            </div>
        </div>

        <!-- 顶部概览 -->
        <el-row :gutter="20" class="overview-row">
            <el-col :span="6">
                <el-card shadow="hover" class="overview-card">
                    <div class="card-label">样本编号</div>
                    <div class="card-value text">{{ result.sampleId }}</div>
                    <div class="card-footer">患者：{{ result.patientName }}</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="overview-card">
                    <div class="card-label">HRD 总评分</div>
                    <div class="card-value primary">{{ result.hrdScore }}</div>
                    <div class="card-footer">阈值参考：42</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="overview-card">
                    <div class="card-label">结果判定</div>
                    <div class="card-value" :class="result.hrdScore >= 42 ? 'danger' : 'success'">
                        {{ result.hrdScore >= 42 ? 'HRD 阳性' : 'HRD 阴性' }}
                    </div>
                    <div class="card-footer">依据综合评分自动判定</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="overview-card">
                    <div class="card-label">生成时间</div>
                    <div class="card-value text">{{ result.reportTime }}</div>
                    <div class="card-footer">分析任务已完成</div>
                </el-card>
            </el-col>
        </el-row>

        <!-- 三大指标 -->
        <el-card shadow="never" class="section-card">
            <template #header>
                <div class="section-header">关键指标概览</div>
            </template>

            <el-row :gutter="20">
                <el-col :span="8">
                    <div class="metric-card">
                        <div class="metric-title">LOH</div>
                        <div class="metric-value">{{ result.loh }}</div>
                        <div class="metric-desc">杂合性缺失评分</div>
                    </div>
                </el-col>

                <el-col :span="8">
                    <div class="metric-card">
                        <div class="metric-title">TAI</div>
                        <div class="metric-value">{{ result.tai }}</div>
                        <div class="metric-desc">端粒等位基因失衡评分</div>
                    </div>
                </el-col>

                <el-col :span="8">
                    <div class="metric-card">
                        <div class="metric-title">LST</div>
                        <div class="metric-value">{{ result.lst }}</div>
                        <div class="metric-desc">大片段状态转移评分</div>
                    </div>
                </el-col>
            </el-row>
        </el-card>

        <!-- 结果解读 + 判定说明 -->
        <el-row :gutter="20" class="content-row" align="stretch">
            <el-col :span="14" class="stretch-col">
                <el-card shadow="never" class="section-card equal-card">
                    <template #header>
                        <div class="section-header">结果解读</div>
                    </template>

                    <el-descriptions :column="1" border>
                        <el-descriptions-item label="HRD 总评分">
                            {{ result.hrdScore }}
                        </el-descriptions-item>

                        <el-descriptions-item label="结果判定">
                            <el-tag :type="result.hrdScore >= 42 ? 'danger' : 'success'">
                                {{ result.hrdScore >= 42 ? 'HRD 阳性' : 'HRD 阴性' }}
                            </el-tag>
                        </el-descriptions-item>

                        <el-descriptions-item label="结果说明">
                            {{ result.summary }}
                        </el-descriptions-item>

                        <el-descriptions-item label="临床提示">
                            {{ result.clinicalSuggestion }}
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
                            <span class="conclusion-label">样本状态</span>
                            <el-tag type="success">分析完成</el-tag>
                        </div>

                        <div class="conclusion-item">
                            <span class="conclusion-label">HRD 判定</span>
                            <el-tag :type="result.hrdScore >= 42 ? 'danger' : 'success'">
                                {{ result.hrdScore >= 42 ? '阳性' : '阴性' }}
                            </el-tag>
                        </div>

                        <div class="conclusion-item">
                            <span class="conclusion-label">风险提示</span>
                            <span class="conclusion-text">
                                {{ result.hrdScore >= 42 ? '提示存在同源重组修复缺陷倾向' : '未提示明显 HRD 倾向' }}
                            </span>
                        </div>

                        <div class="conclusion-item">
                            <span class="conclusion-label">建议</span>
                            <span class="conclusion-text">建议结合临床表现、病理信息及其他检测结果综合判断。</span>
                        </div>
                    </div>
                </el-card>
            </el-col>
        </el-row>

        <!-- 指标明细 -->
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
    </div>
</template>

<script setup>
import { useRouter } from 'vue-router'

const router = useRouter()

const result = {
    sampleId: 'SEQ-20260318-01',
    patientName: '张**',
    hrdScore: 54,
    loh: 18,
    tai: 21,
    lst: 15,
    reportTime: '2026-03-18 09:53:02',
    summary: '该样本 HRD 综合评分较高，提示存在同源重组修复缺陷倾向。',
    clinicalSuggestion: '建议结合患者临床信息、病理结果及其他分子检测结果进行综合评估。'
}

const metricTableData = [
    { item: 'LOH', value: 18, status: '偏高', remark: '杂合性缺失事件数量较高' },
    { item: 'TAI', value: 21, status: '偏高', remark: '端粒等位基因失衡信号明显' },
    { item: 'LST', value: 15, status: '偏高', remark: '大片段状态转移事件较多' },
    { item: 'HRD 综合评分', value: 54, status: '偏高', remark: '超过阳性判定阈值 42' }
]

const goBack = () => {
    router.push('/samples/SEQ-20260318-01')
}
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
    color: #409EFF;
}

.card-value.success {
    color: #67C23A;
}

.card-value.danger {
    color: #F56C6C;
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
    color: #409EFF;
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