import request from '../utils/request'

/** @type {number | null} */
let cachedHrdPositiveMin = null

export async function getHrdThresholdConfig() {
  return await request.get('/api/config/hrd-threshold/')
}

/**
 * 阳性阈值：HRD 总分 >= 返回值为阳性。带内存缓存，默认 42。
 */
export async function getHrdPositiveMin() {
  if (cachedHrdPositiveMin != null) return cachedHrdPositiveMin
  try {
    const d = await getHrdThresholdConfig()
    const v = Number(d.hrd_positive_score_min)
    cachedHrdPositiveMin = Number.isFinite(v) && v > 0 ? v : 42
  } catch {
    cachedHrdPositiveMin = 42
  }
  return cachedHrdPositiveMin
}

export function clearHrdPositiveMinCache() {
  cachedHrdPositiveMin = null
}
