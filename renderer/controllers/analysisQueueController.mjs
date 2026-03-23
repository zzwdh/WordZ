export function createAnalysisQueueController({
  dom,
  taskCenter,
  maxQueueLength,
  formatCount,
  getErrorMessage,
  setButtonLabel,
  showAlert,
  showToast,
  finishTaskEntryWithAttention,
  recordDiagnosticError,
  getActiveCancelableAnalysis
}) {
  const {
    queueToggleButton,
    retryFailedTaskButton,
    cancelQueuedTaskButton
  } = dom

  let analysisQueuePaused = false
  let analysisQueueRunning = false
  let analysisQueueSeq = 0
  let analysisQueue = []
  let analysisQueueFailedItems = []

  function ensureTaskCenterRunningEntry(taskKey, title, detail) {
    if (!taskKey) return
    if (!taskCenter.promoteQueuedEntry(taskKey, detail)) {
      taskCenter.startEntryWithStatus(taskKey, title, detail, 'running')
    }
  }

  function inferTaskTypeFromTaskCenterEntry(entry) {
    const taskKey = String(entry?.taskKey || '')
    if (taskKey.includes('stats')) return 'stats'
    if (taskKey.includes('kwic')) return 'kwic'
    if (taskKey.includes('collocate')) return 'collocate'
    return ''
  }

  function formatEstimatedDuration(durationMs) {
    const safeDuration = Math.max(0, Number(durationMs) || 0)
    if (safeDuration < 1000) return '<1s'
    if (safeDuration < 60000) return `${Math.round(safeDuration / 1000)}s`
    const minutes = Math.floor(safeDuration / 60000)
    const seconds = Math.round((safeDuration % 60000) / 1000)
    return `${minutes}m ${seconds}s`
  }

  function estimateAnalysisQueueDurationMs() {
    if (analysisQueue.length === 0) return 0
    const completedEntries = taskCenter
      .getEntries()
      .filter(entry => entry.status === 'success' && Number(entry.durationMs) > 0)
    const durationBuckets = {
      stats: [],
      kwic: [],
      collocate: []
    }
    for (const entry of completedEntries) {
      const taskType = inferTaskTypeFromTaskCenterEntry(entry)
      if (!taskType || !durationBuckets[taskType]) continue
      durationBuckets[taskType].push(Number(entry.durationMs) || 0)
    }

    const fallbackDurationByTaskType = {
      stats: 3500,
      kwic: 4800,
      collocate: 5200
    }
    let totalEstimatedMs = 0
    for (const task of analysisQueue) {
      const taskType = String(task?.type || '').trim()
      const bucket = durationBuckets[taskType] || []
      const averageDuration = bucket.length > 0
        ? bucket.reduce((sum, value) => sum + value, 0) / bucket.length
        : (fallbackDurationByTaskType[taskType] || 4000)
      totalEstimatedMs += averageDuration
    }
    return Math.max(0, totalEstimatedMs)
  }

  function updateAnalysisQueueControls() {
    const queuedCount = analysisQueue.length
    const failedCount = analysisQueueFailedItems.length

    if (cancelQueuedTaskButton) {
      cancelQueuedTaskButton.disabled = queuedCount === 0
      setButtonLabel(
        cancelQueuedTaskButton,
        queuedCount > 0 ? `取消排队任务（${queuedCount}）` : '取消排队任务'
      )
    }
    if (queueToggleButton) {
      const label = analysisQueuePaused ? '恢复队列' : '暂停队列'
      setButtonLabel(queueToggleButton, label)
      queueToggleButton.disabled = !analysisQueuePaused && queuedCount === 0 && !analysisQueueRunning
    }
    if (retryFailedTaskButton) {
      retryFailedTaskButton.disabled = failedCount === 0
      setButtonLabel(
        retryFailedTaskButton,
        failedCount > 0 ? `重试失败任务（${failedCount}）` : '重试失败任务'
      )
    }
    if (queuedCount > 0) {
      const etaMs = estimateAnalysisQueueDurationMs()
      taskCenter.setMetaSuffix(`预计排队耗时 ${formatEstimatedDuration(etaMs)}`)
    } else {
      taskCenter.setMetaSuffix('')
    }
  }

  function appendFailedQueueTask(task, status = 'failed') {
    if (!task) return
    analysisQueueFailedItems = [
      {
        type: task.type,
        title: task.title,
        detail: task.detail,
        run: task.run,
        status,
        failedAt: Date.now()
      },
      ...analysisQueueFailedItems
    ].slice(0, maxQueueLength)
  }

  async function runAnalysisQueueIfNeeded() {
    if (analysisQueuePaused || analysisQueueRunning || getActiveCancelableAnalysis()) return
    const nextTask = analysisQueue.shift()
    if (!nextTask) {
      updateAnalysisQueueControls()
      return
    }

    analysisQueueRunning = true
    updateAnalysisQueueControls()
    ensureTaskCenterRunningEntry(nextTask.queueTaskKey, nextTask.title, nextTask.detail)

    try {
      const status = await nextTask.run({
        taskCenterTaskKey: nextTask.queueTaskKey,
        fromQueue: true
      })
      if (status === 'failed') {
        appendFailedQueueTask(nextTask, status)
      }
    } catch (error) {
      appendFailedQueueTask(nextTask, 'failed')
      finishTaskEntryWithAttention(
        nextTask.queueTaskKey,
        nextTask.title,
        'failed',
        getErrorMessage(error, '队列任务执行失败'),
        'analysis-complete'
      )
      recordDiagnosticError('analysis.queue.run', error, { type: nextTask.type })
    } finally {
      analysisQueueRunning = false
      updateAnalysisQueueControls()
      if (!analysisQueuePaused && analysisQueue.length > 0) {
        void runAnalysisQueueIfNeeded()
      }
    }
  }

  async function enqueueOrRunAnalysisTask({ type, title, detail, run }) {
    if (!type || typeof run !== 'function') return 'failed'
    if (!analysisQueuePaused && !analysisQueueRunning && !getActiveCancelableAnalysis() && analysisQueue.length === 0) {
      return run({ taskCenterTaskKey: type, fromQueue: false })
    }

    if (analysisQueue.length >= maxQueueLength) {
      await showAlert({
        title: '任务队列已满',
        message: `当前最多允许排队 ${maxQueueLength} 项，请先等待部分任务完成。`
      })
      return 'failed'
    }

    const queueTaskKey = `queue-${type}-${++analysisQueueSeq}`
    const queuedTask = {
      type,
      title,
      detail,
      queueTaskKey,
      run
    }
    analysisQueue.push(queuedTask)
    taskCenter.startEntryWithStatus(queueTaskKey, title, detail, 'queued')
    updateAnalysisQueueControls()
    showToast(`${title} 已加入任务队列。`, {
      title: analysisQueuePaused ? '队列已暂停' : '已排队',
      duration: 1800
    })
    if (!analysisQueuePaused) {
      void runAnalysisQueueIfNeeded()
    }
    return 'queued'
  }

  function retryFailedQueueTasks() {
    if (analysisQueueFailedItems.length === 0) {
      showToast('当前没有失败任务可重试。', {
        title: '任务队列'
      })
      return 0
    }

    const failedTasks = analysisQueueFailedItems.slice()
    analysisQueueFailedItems = []
    for (const task of failedTasks.reverse()) {
      const queueTaskKey = `queue-${task.type}-${++analysisQueueSeq}`
      const detail = `${task.detail}（重试）`
      analysisQueue.push({
        type: task.type,
        title: task.title,
        detail,
        queueTaskKey,
        run: task.run
      })
      taskCenter.startEntryWithStatus(queueTaskKey, task.title, detail, 'queued')
    }
    updateAnalysisQueueControls()
    if (!analysisQueuePaused) {
      void runAnalysisQueueIfNeeded()
    }
    return failedTasks.length
  }

  function cancelQueuedAnalysisTasks(detail = '已取消排队任务') {
    const queuedCount = analysisQueue.length
    analysisQueue = []
    const cancelledCount = taskCenter.cancelQueuedEntries(detail)
    updateAnalysisQueueControls()
    return Math.max(queuedCount, cancelledCount)
  }

  function toggleAnalysisQueuePaused() {
    analysisQueuePaused = !analysisQueuePaused
    updateAnalysisQueueControls()
    if (!analysisQueuePaused) {
      void runAnalysisQueueIfNeeded()
    }
    return analysisQueuePaused
  }

  return {
    cancelQueuedAnalysisTasks,
    enqueueOrRunAnalysisTask,
    ensureTaskCenterRunningEntry,
    getFailedQueueCount: () => analysisQueueFailedItems.length,
    getQueuedTaskCount: () => analysisQueue.length,
    isAnalysisQueuePaused: () => analysisQueuePaused,
    isAnalysisQueueRunning: () => analysisQueueRunning,
    retryFailedQueueTasks,
    runAnalysisQueueIfNeeded,
    toggleAnalysisQueuePaused,
    updateAnalysisQueueControls
  }
}
