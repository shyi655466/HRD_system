import request from '../utils/request'
import { adaptSample, adaptSampleList } from './adapters/sample'

export async function getSampleList() {
  const res = await request.get('/api/samples/')
  return adaptSampleList(res)
}

export async function getSampleDetail(id) {
  const res = await request.get(`/api/samples/${id}/`)
  return adaptSample(res)
}

export async function startSampleAnalysis(id) {
  return await request.post(`/api/samples/${id}/start-analysis/`)
}

export async function createSample(data) {
  const res = await request.post('/api/samples/', data)
  return adaptSample(res)
}
