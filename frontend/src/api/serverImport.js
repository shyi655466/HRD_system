import request from '../utils/request'

// 校验服务器路径
export function validateServerPaths(data) {
  return request({
    url: '/api/server-files/validate-paths/',
    method: 'post',
    data
  })
}

// 从服务器导入样本
export function importSampleFromServer(data) {
  return request({
    url: '/api/samples/import-from-server/',
    method: 'post',
    data
  })
}

// 浏览服务器目录（V2 再用）
export function browseServerFiles(path = '') {
  return request({
    url: '/api/server-files/browse/',
    method: 'get',
    params: { path }
  })
}