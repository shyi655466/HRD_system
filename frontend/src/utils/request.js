// 统一封装axios
// 请求前自动带 token
// 401 自动回登录页
// 其他错误统一弹提示
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { getToken, removeToken } from './auth'
import router from '../router'

const request = axios.create({
  baseURL: '/',
  timeout: 10000,
})

request.interceptors.request.use(
  (config) => {
    const token = getToken()
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

request.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const status = error?.response?.status

    if (status === 401) {
      removeToken()
      ElMessage.error('登录已失效，请重新登录')
      router.push('/login')
    } else {
      ElMessage.error(error?.response?.data?.detail || '请求失败，请稍后重试')
    }

    return Promise.reject(error)
  }
)

export default request