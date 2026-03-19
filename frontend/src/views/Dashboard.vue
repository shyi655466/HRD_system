<template>
    <div class="dashboard-container">
        <!-- 顶部欢迎区 -->
        <el-card shadow="never" class="welcome-card">
            <div class="welcome-content">
                <div>
                    <h2 class="welcome-title">欢迎使用 HRD 评分计算系统</h2>
                    <p class="welcome-subtitle">单细胞与基因组测序分析平台 · 今日共运行6个分析任务</p>
                </div>
                <el-tag type="success" size="large">系统运行正常</el-tag>
            </div>
        </el-card>

        <!-- 顶部统计卡片 -->
        <el-row :gutter="20" class="stats-row">
            <el-col :span="6">
                <el-card shadow="hover" class="stats-card">
                    <div class="card-header">累计分析样本</div>
                    <!-- 表示一个元素同时拥有两个类 将样式拆开复用 -->
                    <div class="card-value primary">128 份</div>
                    <div class="card-footer">较昨日 +12</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="stats-card">
                    <div class="card-header">已完成任务</div>
                    <div class="card-value success">96个</div>
                    <div class="card-footer">完成率 96%</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="stats-card">
                    <div class="card-header">排队中任务</div>
                    <div class="card-value warning">3 个</div>
                    <div class="card-footer">等待 Celery 调度</div>
                </el-card>
            </el-col>

            <el-col :span="6">
                <el-card shadow="hover" class="stats-card">
                    <div class="card-header">异常任务</div>
                    <div class="card-value danger">2 个</div>
                    <div class="card-footer">建议及时检查日志</div>
                </el-card>
            </el-col>
        </el-row>

        <!-- 中间区域 -->
        <el-row :gutter="20" class="content-row">
            <!-- 最近分析任务 -->
            <el-col :span="12">
                <el-card shadow="never" class="section-card">
                    <template #header>
                        <div class="section-header">
                            <span>最近分析任务</span>
                            <el-button type="primary" link>查看全部</el-button>
                        </div>
                    </template>

                    <el-table :data="recentTasks" style="width: 100%" stripe>
                        <el-table-column prop="sampleId" label="样本编号" width="180" />
                        <el-table-column prop="patientName" label="患者姓名" width="120" />
                        <el-table-column prop="submitTime" label="提交时间" width="180" />
                        <el-table-column prop="status" label="状态" width="120">
                            <template #default="scope">
                                <el-tag v-if="scope.row.status === 'success'" type="success" effect="light">已完成</el-tag>
                                <el-tag v-else-if="scope.row.status === 'running'" type="primary" effect="light">计算中</el-tag>
                                <el-tag v-else-if="scope.row.status === 'pending'" type="warning" effect="light">排队中</el-tag>
                                <el-tag v-else-if="scope.row.status === 'error'" type="danger" effect="light">失败</el-tag>
                            </template>
                        </el-table-column>
                        <el-table-column prop="hrdScore" label="HRD 评分" width="120">
                            <template #default="scope">
                                <span v-if="scope.row.status !== 'success'">--</span>
                                <span v-else :class="{ 'hrd-score': scope.row.hrdScore >=42 }">
                                    {{ scope.row.hrdScore }}
                                </span>
                            </template>
                        </el-table-column>
                    </el-table>
                </el-card>
            </el-col>

            <el-col :span="12">
                <el-card shadow="never" class="section-card">
                    <template #header>
                        <div class="section-header">
                            <span>系统运行状态</span>
                        </div>
                    </template>

                    <div class="status-list">
                        <div class="status-item">
                            <span>Web 服务</span>
                            <el-tag type="success">运行中</el-tag>
                        </div>
                        <div class="status-item">
                            <span>Celery Worker</span>
                            <el-tag type="success">运行中</el-tag>
                        </div>
                        <div class="status-item">
                            <span>Redis 队列</span>
                            <el-tag type="success">正常</el-tag>
                        </div>
                        <div class="status-item">
                            <span>数据库连接</span>
                            <el-tag type="success">正常</el-tag>
                        </div>
                        <div class="status-item">
                            <span>磁盘占用</span>
                            <el-tag type="success">72%</el-tag>
                        </div>
                    </div>

                    <el-divider />

                    <div class="queue-info">
                        <p><strong>当前排队任务：</strong>3 个</p>
                        <p><strong>正在运行任务：</strong>1 个</p>
                        <p><strong>今日平均耗时：</strong>18 分钟</p>
                    </div>
                </el-card>
            </el-col>
        </el-row>
        
        <!-- 底部区域 -->
        <el-row :gutter="20" class="bottom-row">
            <!-- 快捷操作 -->
            <el-col :span="12">
                <el-card shadow="never" class="section-card">
                    <!-- #header是el-card组件已经提前定义好的“占位区域” -->
                    <template #header>
                        <div class="section-header">
                            <span>快捷操作</span>
                        </div>
                    </template>

                    <div class="quick-actions">
                        <el-button>新建分析任务</el-button>
                        <el-button>查看样本列表</el-button>
                        <el-button>导出分析记录</el-button>
                        <el-button>查看系统日志</el-button>
                    </div>
                </el-card>
            </el-col>

            <!-- 系统公告 -->
            <el-col :span="12">
                <el-card shadow="never" class="section-card">
                    <template #header>
                        <div class="section-header">
                            <span>系统公告</span>
                        </div>
                    </template>

                    <ul class="notice-list">
                        <li>2026-03-18：新增 BAM / VCF 文件上传支持</li>
                        <li>2026-03-17：样本管理页面完成第一版开发</li>
                        <li>2026-03-16：Celery 异步分析任务模块已接入</li>
                        <li>2026-03-15：HRD 评分计算系统初始化完成</li>
                    </ul>
                </el-card>
            </el-col>
        </el-row>
    </div>
</template>

<script setup>
const recentTasks = [
    { sampleId: 'SEQ-20260318-01', patientName: '张**', submitTime: '2026-03-18 09:30:21', status: 'success', hrdScore: 54 },
    { sampleId: 'SEQ-20260318-02', patientName: '李**', submitTime: '2026-03-18 10:15:42', status: 'running', hrdScore: null },
    { sampleId: 'SEQ-20260318-03', patientName: '王**', submitTime: '2026-03-18 10:48:09', status: 'pending', hrdScore: null },
    { sampleId: 'SEQ-20260318-04', patientName: '赵**', submitTime: '2026-03-18 11:12:55', status: 'error', hrdScore: null },
    { sampleId: 'SEQ-20260318-05', patientName: '陈**', submitTime: '2026-03-18 11:40:33', status: 'success', hrdScore: 61 }
]
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
    align-items: center;
}

.welcome-title {
    margin: 0;
    font-size: 22px;
    color: #303133;
}

.welcome-subtitle {
    margin-top: 8px;
    color: #909399;
    font-size: 14px;
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
    color: #409EFF;
}

.success {
    color: #67C23A;
}

.warning {
    color: #E6A23C;
}

.danger {
    color: #F56C6C;
}

.section-card {
    border-radius: 10px;
    min-height: 320px;
}

.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-weight: bold;
}

.status-list {
    display: flex;
    flex-direction: column;
    gap: 14px;
}

.status-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.queue-info p {
    margin: 8px 0;
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
    line-height: 2;
}

.high-score {
    color: #F56C6C;
    font-weight: bold;
}
</style>