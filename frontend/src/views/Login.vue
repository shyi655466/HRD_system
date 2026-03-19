<!--
    页面中间显示一个登录卡片
    用户输入用户名和密码
    点击登录按钮或按 Enter
    先进行表单验证
    验证通过后显示 loading
    模拟请求 1 秒
    弹出登录成功提示
    跳转到首页 /
-->

<template>
    <!-- 定义外层容器包住整个登录页面 -->
    <div class="login-container">
        <!-- 创建登录面板 -->
        <el-card class="login-card" shadow="always">
            <!-- 把这部分内容插到卡片头部显示 -->
            <!-- 具名插槽 等价于 <template v-slot:header> -->
            <template #header>
                <div class="login-header">
                    <h2>HRD 系统登录</h2>
                    <p>单细胞与基因组测序分析平台</p>
                </div>
            </template>
            
            <!-- 给表单指定引用名并绑定数据对象和校验规则对象-->
            <el-form ref="loginFormRef" :model="loginForm" :rules="loginRules" size="large">
                <!-- v-model双向绑定数据 prop定义字段名 -->
                <el-form-item prop="username">
                    <el-input v-model="loginForm.username" placeholder="请输入用户名" :prefix-icon="User" clearable />
                </el-form-item>

                <el-form-item prop="password">
                    <el-input v-model="loginForm.password" type="password" placeholder="请输入密码" :prefix-icon="Lock" show-password @keyup.enter="handleLogin" />
                </el-form-item>

                <el-form-item>
                    <el-button type="primary" class="login-button" :loading="loading" @click="handleLogin">
                        <!-- 按钮里的显示文本 如果变量loading为真显示登录中 否则显示登录 -->
                        {{ loading ? '登录中...' : '登 录' }}
                    </el-button>
                </el-form-item>
            </el-form>
        </el-card>
    </div>
</template>

<script setup>
// 从Vue中导入两个组合式API
// ref 用于定义基本类型或单值响应式数据
// reactive 用于定义对象类型响应式数据
import { ref, reactive } from 'vue' 
// 获取路由实例 用来做页面跳转
import { useRouter } from 'vue-router'
// 导入两个图标组件
import { User, Lock } from '@element-plus/icons-vue'
// 导入消息提示组件 作用是弹出登录成功/失败提示
import { ElMessage } from 'element-plus'

const router = useRouter()
const loginFormRef = ref(null)
const loading = ref(false)
// 定义表单的数据对象 为响应式 
// 因为双向绑定 所以输入框内容会自动同步到这里
const loginForm = reactive({
    username: '',
    password: ''
})

const loginRules = reactive({
    username: [
        // 必填 校验失败时的提示 在失去焦点时触发校验
        { required: true, message: '用户名不能为空', trigger: 'blur' },
        { min: 8, max: 20, message: '用户名长度需在8到20个字符之间', trigger: 'blur' }
    ],
    password: [
        { required: true, message: '密码不能为空', trigger: 'blur' },
        { min: 8, max: 20, message: '密码长度需在8到20个字符之间', trigger: 'blur' }
    ]
})

const handleLogin = () => {
    if(!loginFormRef.value) return

    loginFormRef.value.validate((valid) => {
        if(valid) {
            loading.value = true
            // 模拟向后端发送API请求的过程（延时1秒）
            setTimeout(() => {
                loading.value = false
                ElMessage.success('登录成功！欢迎回来')
                router.push('/')
            }, 1000)
        } else {
            ElMessage.error('请正确填写账号和密码格式')
            return false
        }
    })
}
</script>

<style scoped>
.login-container {
    height: 100vh;
    display: flex;
    justify-content: center;
    align-items: center;
    background: linear-gradient(135deg, #2b333e 0%, #1a1f26 100%);
}

.login-card {
    width: 420px;
    border-radius: 12px;
    border: none;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
}

.login-header {
    text-align: center;
}

.login-header h2 {
    margin: 0;
    color: #2b333e;
    font-size: 24px;
}

.login-header p {
    margin: 10px 0 0 0;
    color: #909399;
    font-size: 14px;
}

.login-button {
    width: 100%;
    font-size: 16px;
    letter-spacing: 4px;
    border-radius: 6px;
}
</style>