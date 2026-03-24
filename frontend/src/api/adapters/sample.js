export function adaptTask(task) {
  if (!task) return null

  return {
    id: task.id,
    status: task.status,
    createdAt: task.created_at,
    logOutput: task.log_output,
  }
}

export function adaptResult(result) {
  if (!result) return null

  return {
    hrdScore: result.hrd_score,
    lohScore: result.loh_score,
    taiScore: result.tai_score,
    lstScore: result.lst_score,
    brcaStatus: result.brca_status,
    variantData: result.variant_data,
    analysisDate: result.analysis_date,
  }
}

export function adaptSample(sample) {
  if (!sample) return null

  return {
    id: sample.id,
    patientId: sample.patient_id,
    sampleCode: sample.sample_code,
    status: sample.status,
    createdAt: sample.created_at,
    result: adaptResult(sample.result),
    tasks: Array.isArray(sample.tasks)
      ? sample.tasks.map(adaptTask).filter(Boolean)
      : [],
  }
}

export function adaptSampleList(sampleList) {
  if (!Array.isArray(sampleList)) return []
  return sampleList.map(adaptSample).filter(Boolean)
}