export function adaptTask(task) {
  if (!task) return null

  return {
    id: task.id,
    taskType: task.task_type,
    status: task.status,
    celeryTaskId: task.celery_task_id,
    resultPath: task.result_path || '',
    createdAt: task.created_at,
    startedAt: task.started_at,
    finishedAt: task.finished_at,
    logOutput: task.log_output,
    errorMessage: task.error_message,
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
    inputType: result.input_type,
    genomeBuild: result.genome_build,
    pipelineVersion: result.pipeline_version,
    variantData: result.variant_data,
    qcMetrics: result.qc_metrics,
    reportPath: result.report_path || '',
    analysisDate: result.analysis_date,
  }
}

export function adaptSampleFile(file) {
  if (!file) return null
  return {
    id: file.id,
    fileRole: file.file_role,
    originalName: file.original_name,
    storagePath: file.storage_path,
    fileSize: file.file_size,
    uploadStatus: file.upload_status,
  }
}

export function adaptSample(sample) {
  if (!sample) return null

  return {
    id: sample.id,
    patientId: sample.patient_id,
    sampleCode: sample.sample_code,
    dataType: sample.data_type,
    description: sample.description ?? '',
    upload_status: sample.upload_status,
    analysis_status: sample.analysis_status,
    status: sample.status,
    createdAt: sample.created_at,
    result: adaptResult(sample.result),
    tasks: Array.isArray(sample.tasks)
      ? sample.tasks.map(adaptTask).filter(Boolean)
      : [],
    files: Array.isArray(sample.files)
      ? sample.files.map(adaptSampleFile).filter(Boolean)
      : [],
  }
}

export function adaptSampleList(sampleList) {
  if (!Array.isArray(sampleList)) return []
  return sampleList.map(adaptSample).filter(Boolean)
}