import request from '../utils/request'

/**
 * @returns {Promise<{
 *   total_samples: number,
 *   analysis_status_counts: Record<string, number>,
 *   task_status_counts: Record<string, number>,
 *   recent_tasks: Array<object>
 * }>}
 */
export async function getDashboardStats() {
  return await request.get('/api/dashboard/stats/')
}
