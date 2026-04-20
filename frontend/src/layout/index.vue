<template>
    <el-container class="layout-container">
        <el-aside width="220px" class="aside">
            <div class="logo">HRD 评分计算系统</div>
            <!--
                左侧导航菜单
                default-active="/" 表示默认高亮路径为 /
                router 表示启用 vue-router 路由模式
                点击菜单项时，会根据 index 自动跳转到对应路由
            -->
            <el-menu
                :default-active="menuActive"
                router
                class="el-menu-vertical"
            >
                <el-menu-item index="/">
                    <el-icon><DataLine /></el-icon>
                    <span>工作台概览</span>
                </el-menu-item>
                <el-menu-item index="/samples">
                    <el-icon><Files /></el-icon>
                    <span>临床样本管理</span>
                </el-menu-item>
                <el-menu-item index="/reports">
                    <el-icon><Document /></el-icon>
                    <span>查看报告</span>
                </el-menu-item>
            </el-menu>
        </el-aside>

        <el-container>
            <el-header class="header">
                <div class="header-left">欢迎回来</div>
                <div class="header-right">
                    <!-- @click 表示点击时执行 logout 函数 -->
                    <el-button type="danger" plain size="small" @click="logout">退出系统</el-button>
                </div>
            </el-header>

            <el-main class="main">
                <!--
                    路由出口
                    当前路由对应的页面组件会渲染在这里
                    比如访问 / 时显示首页组件
                    访问 /samples 时显示样本管理组件
                -->
                <router-view></router-view>
            </el-main>
        </el-container>
    </el-container>
</template>

<script setup>
// 从 @element-plus/icons-vue 中导入两个图标组件
// DataLine：数据分析类图标 Files：文件类图标
import { DataLine, Files, Document } from '@element-plus/icons-vue'

import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { removeToken } from '../utils/auth'

const router = useRouter()
const route = useRoute()

const menuActive = computed(() => {
  const p = route.path
  if (p === '/reports' || p.startsWith('/reports/')) return '/reports'
  if (/\/samples\/[^/]+\/report/.test(p)) return '/reports'
  if (p.startsWith('/samples')) return '/samples'
  if (p === '/' || p === '') return '/'
  return p
})

const logout = () => {
    removeToken()
    router.push('/login')
}
</script>

<style scoped>
/*
  scoped 表示当前样式只作用于本组件
  不会轻易污染其他页面
*/

/* 最外层布局容器，高度占满整个浏览器可视区域 */
.layout-container {
    height: 100vh;
}
/* 侧边栏样式 */
.aside {
    /*背景颜色*/
    background-color: #2b333e;
    /*字体颜色*/
    color: white;
}
/* 标题区域样式 */
.logo {
    height: 60px;
    line-height: 60px;
    text-align: center;
    font-size: 18px;
    font-weight: bold;
    /* 底部加分割线 */
    border-bottom: 1px solid #1f252d;
    color: #fff;
    /* 字间距 */
    letter-spacing: 1px;
}
/* 菜单整体样式 */
.el-menu-vertical {
    border-right: none;
    background-color: transparent;
}

/*
  深度穿透修改 Element Plus 内部生成的菜单项样式
  因为普通 scoped 样式默认不能直接影响子组件内部结构
*/

/* 选中所有类名为 el-menu-item 的元素 */
:deep(.el-menu-item) {
    color: #a3b1c2;
}
/* 选中同时具有两个类的元素 */
:deep(.el-menu-item.is-active) {
    color: #fff;
    background-color: #409EFF;
}
/* 选中鼠标悬停状态下的 .el-menu-item 元素 */
:deep(.el-menu-item:hover) {
    background-color: #3b4655;
}
.header {
    background-color: #fff;
    border-bottom: 1px solid #e6e666;
    display: flex;
    justify-content: space-between;
    align-items: center;
    box-shadow: 0 1px 4px rgba(0,21,41,.08);
}
.main {
    background-color: #f0f2f5;
    padding: 20px;
}
</style>