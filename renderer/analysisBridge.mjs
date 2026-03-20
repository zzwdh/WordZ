import { yieldToUI } from './utils.mjs'

function createAbortError(message = '任务已取消') {
  const error = new Error(message)
  error.name = 'AbortError'
  return error
}

function isAbortError(error) {
  return error?.name === 'AbortError'
}

export function createAnalysisBridge({ systemStatus, systemStatusText }) {
  let analysisWorker = null
  let analysisWorkerDisabled = false
  let analysisRequestSeq = 0
  const pendingAnalysisRequests = new Map()
  const busyStateTokens = new Map()
  let busyStateSeq = 0
  const analysisRunIds = {
    loadCorpus: 0,
    stats: 0,
    kwic: 0,
    collocate: 0
  }
  const activeAnalysisTasks = new Map()
  let latestCorpusText = null
  let workerCorpusText = null

  function updateSystemStatus() {
    if (!systemStatus || !systemStatusText) return
    if (busyStateTokens.size === 0) {
      systemStatus.classList.add('hidden')
      systemStatusText.textContent = ''
      return
    }
    const latestMessage = Array.from(busyStateTokens.values()).at(-1)
    systemStatusText.textContent = latestMessage || '处理中...'
    systemStatus.classList.remove('hidden')
  }

  function beginBusyState(message) {
    const token = ++busyStateSeq
    busyStateTokens.set(token, message)
    updateSystemStatus()
    return () => {
      busyStateTokens.delete(token)
      updateSystemStatus()
    }
  }

  function nextAnalysisRun(name) {
    analysisRunIds[name] = (analysisRunIds[name] || 0) + 1
    return analysisRunIds[name]
  }

  function isLatestAnalysisRun(name, runId) {
    return analysisRunIds[name] === runId
  }

  function rejectPendingAnalysisRequests(error) {
    for (const pendingRequest of [...pendingAnalysisRequests.values()]) {
      pendingRequest.reject(error)
    }
    pendingAnalysisRequests.clear()
  }

  function disposeAnalysisWorker(error) {
    if (analysisWorker) {
      analysisWorker.terminate()
      analysisWorker = null
    }
    workerCorpusText = null
    if (error) rejectPendingAnalysisRequests(error)
  }

  function getAnalysisWorker() {
    if (analysisWorkerDisabled || typeof Worker === 'undefined') return null
    if (analysisWorker) return analysisWorker

    try {
      const workerUrl = new URL('../analysisWorker.mjs', import.meta.url)
      const smokeDelayMs = Number(window.electronAPI?.getSmokeAnalysisDelayMs?.() || 0)
      if (Number.isFinite(smokeDelayMs) && smokeDelayMs > 0) {
        workerUrl.searchParams.set('delayMs', String(smokeDelayMs))
      }

      const worker = new Worker(workerUrl, { type: 'module' })
      worker.onmessage = event => {
        const { id, success, result, message } = event.data || {}
        const pendingRequest = pendingAnalysisRequests.get(id)
        if (!pendingRequest) return
        pendingAnalysisRequests.delete(id)
        if (success) pendingRequest.resolve(result)
        else pendingRequest.reject(new Error(message || '分析任务失败'))
      }
      worker.onerror = error => {
        console.error('[analysis-worker.onerror]', error)
        analysisWorkerDisabled = true
        const workerError = error instanceof Error ? error : new Error('分析 worker 初始化失败')
        disposeAnalysisWorker(workerError)
      }
      analysisWorker = worker
      return analysisWorker
    } catch (error) {
      console.error('[analysis-worker.init]', error)
      analysisWorkerDisabled = true
      disposeAnalysisWorker()
      return null
    }
  }

  function postAnalysisTask(type, payload = {}, { signal } = {}) {
    const worker = getAnalysisWorker()
    if (!worker) return null

    return new Promise((resolve, reject) => {
      const id = ++analysisRequestSeq
      let settled = false

      const finishResolve = result => {
        if (settled) return
        settled = true
        pendingAnalysisRequests.delete(id)
        if (signal) signal.removeEventListener('abort', handleAbort)
        resolve(result)
      }

      const finishReject = error => {
        if (settled) return
        settled = true
        pendingAnalysisRequests.delete(id)
        if (signal) signal.removeEventListener('abort', handleAbort)
        reject(error)
      }

      const handleAbort = () => {
        const abortError = signal?.reason instanceof Error ? signal.reason : createAbortError()
        finishReject(abortError)
        disposeAnalysisWorker(abortError)
      }

      pendingAnalysisRequests.set(id, { resolve: finishResolve, reject: finishReject })
      if (signal?.aborted) {
        handleAbort()
        return
      }
      if (signal) signal.addEventListener('abort', handleAbort, { once: true })
      worker.postMessage({ id, type, payload })
    })
  }

  async function ensureWorkerCorpusLoaded(signal) {
    if (latestCorpusText === null) return false

    const worker = getAnalysisWorker()
    if (!worker) return false
    if (workerCorpusText === latestCorpusText) return true

    await postAnalysisTask('load-corpus', { text: latestCorpusText }, { signal })
    workerCorpusText = latestCorpusText
    return true
  }

  async function runAnalysisTask(type, payload, fallback, { taskName } = {}) {
    let releaseTask = () => {}
    let taskSignal = null

    if (taskName) {
      const controller = new AbortController()
      const cancel = (message = '任务已取消') => {
        if (!controller.signal.aborted) {
          controller.abort(createAbortError(message))
        }
      }
      activeAnalysisTasks.set(taskName, { cancel })
      taskSignal = controller.signal
      releaseTask = () => {
        const activeTask = activeAnalysisTasks.get(taskName)
        if (activeTask?.cancel === cancel) {
          activeAnalysisTasks.delete(taskName)
        }
      }
    }

    try {
      const worker = getAnalysisWorker()
      const workerTask = worker
        ? (async () => {
            if (type !== 'load-corpus') {
              await ensureWorkerCorpusLoaded(taskSignal)
            }
            return postAnalysisTask(type, payload, { signal: taskSignal })
          })()
        : null

      if (workerTask) {
        try {
          const result = await workerTask
          if (type === 'load-corpus') {
            latestCorpusText = String(payload?.text || '')
            workerCorpusText = latestCorpusText
          }
          return result
        } catch (error) {
          if (isAbortError(error)) throw error
          console.error(`[${type}]`, error)
          disposeAnalysisWorker()
        }
      }

      await yieldToUI()
      if (taskSignal?.aborted) {
        throw taskSignal.reason instanceof Error ? taskSignal.reason : createAbortError()
      }
      const result = await fallback()
      if (taskSignal?.aborted) {
        throw taskSignal.reason instanceof Error ? taskSignal.reason : createAbortError()
      }
      if (type === 'load-corpus') {
        latestCorpusText = String(payload?.text || '')
        workerCorpusText = null
      }
      return result
    } finally {
      releaseTask()
    }
  }

  function cancelAnalysisTask(taskName, message = '任务已取消') {
    const activeTask = activeAnalysisTasks.get(taskName)
    if (!activeTask) return false
    activeTask.cancel(message)
    return true
  }

  function cancelAllAnalysisTasks(message = '任务已取消') {
    let cancelled = false
    for (const taskName of [...activeAnalysisTasks.keys()]) {
      cancelled = cancelAnalysisTask(taskName, message) || cancelled
    }
    return cancelled
  }

  function isAnalysisTaskActive(taskName) {
    return activeAnalysisTasks.has(taskName)
  }

  return {
    beginBusyState,
    nextAnalysisRun,
    isLatestAnalysisRun,
    runAnalysisTask,
    cancelAnalysisTask,
    cancelAllAnalysisTasks,
    isAnalysisTaskActive,
    isAbortError
  }
}
