<template>
    <div class="dashboard-container">
        <!-- 表示当前这一行中的列之间间隔为 20 像素 -->
        <el-row :gutter="20">
            <!-- 表示当前列占的栅格宽度 -->
            <el-col :span="8">
                <!-- 表示当前卡片阴影只在鼠标悬停时显示 -->
                <el-card shadow="hover">
                    <h3>累计分析样本</h3>
                    <p style="font-size: 24px; color: #409EFF; font-weight: bold;">128 份</p>
                </el-card>
            </el-col>
            <el-col :span="8">
                <el-card shadow="hover">
                    <h3>排队中任务</h3>
                    <p style="font-size: 24px; color: #E6A23C; font-weight: bold;">3 个</p>
                </el-card>
            </el-col>
            <el-col :span="8">
                <el-card shadow="hover">
                    <h3>系统状态</h3>
                    <p style="font-size: 24px; color: #67C23A; font-weight: bold;">Celery 运行中</p>
                </el-card>
            </el-col>
        </el-row>
    </div>
</template>

<script setup>
// 后续写获取样本列表的逻辑
</script>

<style scoped>
.dashboard-container {
    margin-top: 10px;
}
</style>