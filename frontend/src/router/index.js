import { createRouter, createWebHistory } from 'vue-router'
import Layout from '../layout/index.vue'

// 定义常量 routes 为数组，数组中的每一个对象，代表一条路由规则
const routes = [
    {
        path: '/',    // 表示访问路径
        component: Layout,  // 表示这个路径 / 对应显示的组件是 Layout
        children: [  // 子路由
            {
                path: '',
                name: 'Dashboard',
                component: () => import('../views/Dashboard.vue')
            }
        ]
    },
    {
        path: '/login',
        name: 'Login',
        component: () => import('../views/Login.vue')
    }
]

const router = createRouter({
    history: createWebHistory(),
    routes
})

export default router