// Keep a renderer-safe copy of the host API catalog here so the mac renderer
// does not import CommonJS preload modules at runtime.
const HOST_API_CATALOG = Object.freeze({
  getAppInfo: { kind: 'invoke' },
  consumePendingSystemOpenFiles: { kind: 'invoke' },
  onSystemOpenFileRequest: { kind: 'subscribe' },
  onAppMenuAction: { kind: 'subscribe' },
  onSystemNotificationAction: { kind: 'subscribe' },
  getDiagnosticState: { kind: 'invoke' },
  setDiagnosticLoggingEnabled: { kind: 'invoke' },
  writeDiagnosticLog: { kind: 'invoke' },
  exportDiagnosticReport: { kind: 'invoke' },
  exportDiagnosticReportAuto: { kind: 'invoke' },
  openGitHubFeedback: { kind: 'invoke' },
  getAnalysisCache: { kind: 'invoke' },
  setAnalysisCache: { kind: 'invoke' },
  deleteAnalysisCache: { kind: 'invoke' },
  clearAnalysisCache: { kind: 'invoke' },
  getAnalysisCacheState: { kind: 'invoke' },
  pruneAnalysisCache: { kind: 'invoke' },
  openExternalUrl: { kind: 'invoke' },
  showPathInFolder: { kind: 'invoke' },
  consumeCrashRecoveryState: { kind: 'invoke' },
  showSystemNotification: { kind: 'invoke' },
  setWindowProgressState: { kind: 'invoke' },
  setWindowAttentionState: { kind: 'invoke' },
  getSmokeObserverState: { kind: 'invoke' },
  getPackagedSmokeConfig: { kind: 'invoke' },
  reportPackagedSmokeResult: { kind: 'invoke' },
  getAutoUpdateState: { kind: 'invoke' },
  checkForUpdates: { kind: 'invoke' },
  installDownloadedUpdate: { kind: 'invoke' },
  onAutoUpdateStatus: { kind: 'subscribe' },
  saveTableFile: { kind: 'invoke' },
  openQuickCorpus: { kind: 'invoke' },
  openQuickCorpusAtPath: { kind: 'invoke' },
  importAndSaveCorpus: { kind: 'invoke' },
  importCorpusPaths: { kind: 'invoke' },
  backupCorpusLibrary: { kind: 'invoke' },
  restoreCorpusLibrary: { kind: 'invoke' },
  repairCorpusLibrary: { kind: 'invoke' },
  listSavedCorpora: { kind: 'invoke' },
  listSearchableCorpora: { kind: 'invoke' },
  searchLibraryKWIC: { kind: 'invoke' },
  listRecycleBin: { kind: 'invoke' },
  restoreRecycleEntry: { kind: 'invoke' },
  purgeRecycleEntry: { kind: 'invoke' },
  createCorpusFolder: { kind: 'invoke' },
  renameCorpusFolder: { kind: 'invoke' },
  deleteCorpusFolder: { kind: 'invoke' },
  showSavedCorpusInFolder: { kind: 'invoke' },
  showRecycleEntryInFolder: { kind: 'invoke' },
  openSavedCorpus: { kind: 'invoke' },
  openSavedCorpora: { kind: 'invoke' },
  renameSavedCorpus: { kind: 'invoke' },
  moveSavedCorpus: { kind: 'invoke' },
  deleteSavedCorpus: { kind: 'invoke' },
  getSmokeAnalysisDelayMs: { kind: 'sync' },
  setZoomFactor: { kind: 'sync' },
  getZoomFactor: { kind: 'sync' }
})

const SYNC_FALLBACKS = Object.freeze({
  getSmokeAnalysisDelayMs: 0,
  getZoomFactor: 1,
  setZoomFactor: undefined
})

function getInvokeFallbackResult(methodName) {
  return {
    success: false,
    message: `${methodName} is unavailable in the current desktop host.`
  }
}

function bindHostMethod(sourceApi, methodName, descriptor = {}) {
  const rawMethod = sourceApi && typeof sourceApi[methodName] === 'function'
    ? sourceApi[methodName].bind(sourceApi)
    : null

  if (descriptor.kind === 'subscribe') {
    if (rawMethod) {
      return (...args) => {
        const unsubscribe = rawMethod(...args)
        return typeof unsubscribe === 'function' ? unsubscribe : () => {}
      }
    }
    return () => () => {}
  }

  if (descriptor.kind === 'sync') {
    if (rawMethod) {
      return (...args) => rawMethod(...args)
    }
    return () => SYNC_FALLBACKS[methodName]
  }

  if (rawMethod) {
    return (...args) => rawMethod(...args)
  }

  return async () => getInvokeFallbackResult(methodName)
}

export function createMacHost(sourceApi = globalThis.window?.electronAPI) {
  const host = {}
  for (const [methodName, descriptor] of Object.entries(HOST_API_CATALOG)) {
    host[methodName] = bindHostMethod(sourceApi, methodName, descriptor)
  }

  host.isMethodAvailable = methodName => typeof sourceApi?.[methodName] === 'function'
  host.raw = sourceApi || null
  return Object.freeze(host)
}
