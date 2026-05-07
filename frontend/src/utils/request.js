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

const getBusinessMessage = (data) => {
  if (!data) return ''
  if (typeof data === 'string') return data
  return data.message || data.detail || data.error || ''
}

const isBusinessError = (response) => {
  const data = response?.data
  const originalStatus = Number(response?.headers?.['x-original-status-code'])

  if (Number.isFinite(originalStatus) && originalStatus >= 400) return true
  if (data?.status === 'error') return true
  if (Number(data?.code) >= 4000) return true

  return false
}

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
  (response) => {
    if (!isBusinessError(response)) return response.data

    const originalStatus = Number(response.headers?.['x-original-status-code'])
    const message = getBusinessMessage(response.data) || '请求失败，请稍后重试'
    const businessError = new Error(message)
    businessError.response = response
    businessError.data = response.data
    businessError.status = Number.isFinite(originalStatus)
      ? originalStatus
      : response.status

    if (businessError.status === 401) {
      removeToken()
      ElMessage.error('登录已失效，请重新登录')
      router.push('/login')
    } else {
      ElMessage.error(message)
    }

    return Promise.reject(businessError)
  },
  (error) => {
    const status = error?.response?.status

    if (status === 401) {
      removeToken()
      ElMessage.error('登录已失效，请重新登录')
      router.push('/login')
    } else {
      ElMessage.error(getBusinessMessage(error?.response?.data) || '请求失败，请稍后重试')
    }

    return Promise.reject(error)
  }
)

export default request
