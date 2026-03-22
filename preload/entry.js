function fallbackWritePreloadLog(scope, details = null) {
  try {
    if (details && typeof details === 'object') {
      console.warn(`[startup.preload] ${scope}`, JSON.stringify(details))
      return
    }
    console.warn(`[startup.preload] ${scope}`)
  } catch {
    // ignore preload logging failures
  }
}

function fallbackWritePreloadError(scope, error, details = null) {
  const normalizedError = error instanceof Error ? error : new Error(String(error || 'Unknown preload error'))
  try {
    if (details && typeof details === 'object') {
      console.error(`[startup.preload] ${scope}`, {
        message: normalizedError.message,
        stack: normalizedError.stack || '',
        ...details
      })
      return
    }
    console.error(`[startup.preload] ${scope}`, normalizedError)
  } catch {
    // ignore preload logging failures
  }
}

function fallbackDeepFreeze(value, seen = new WeakSet()) {
  if (!value || typeof value !== 'object') return value
  if (seen.has(value)) return value
  seen.add(value)
  Object.freeze(value)
  for (const nestedValue of Object.values(value)) {
    fallbackDeepFreeze(nestedValue, seen)
  }
  return value
}

let writePreloadLog = fallbackWritePreloadLog
let writePreloadError = fallbackWritePreloadError
let deepFreeze = fallbackDeepFreeze

try {
  const loggingHelpers = require('./shared/logging')
  writePreloadLog = loggingHelpers.writePreloadLog
  writePreloadError = loggingHelpers.writePreloadError
  deepFreeze = loggingHelpers.deepFreeze
} catch (error) {
  fallbackWritePreloadError('logging-module-failed', error)
}

const EMERGENCY_SYNC_FALLBACKS = Object.freeze({
  getSmokeAnalysisDelayMs: 0,
  getZoomFactor: 1,
  setZoomFactor: undefined
})

const EMERGENCY_METHOD_NAMES = Object.freeze([
  'getAppInfo',
  'consumePendingSystemOpenFiles',
  'onSystemOpenFileRequest',
  'onAppMenuAction',
  'onSystemNotificationAction',
  'getDiagnosticState',
  'setDiagnosticLoggingEnabled',
  'writeDiagnosticLog',
  'exportDiagnosticReport',
  'exportDiagnosticReportAuto',
  'resetWindowsCompatProfile',
  'openGitHubFeedback',
  'getAnalysisCache',
  'setAnalysisCache',
  'deleteAnalysisCache',
  'clearAnalysisCache',
  'getAnalysisCacheState',
  'pruneAnalysisCache',
  'openExternalUrl',
  'showPathInFolder',
  'consumeCrashRecoveryState',
  'showSystemNotification',
  'setWindowProgressState',
  'setWindowAttentionState',
  'getSmokeObserverState',
  'getPackagedSmokeConfig',
  'reportPackagedSmokeResult',
  'getAutoUpdateState',
  'checkForUpdates',
  'installDownloadedUpdate',
  'onAutoUpdateStatus',
  'saveTableFile',
  'openQuickCorpus',
  'openQuickCorpusAtPath',
  'importAndSaveCorpus',
  'importCorpusPaths',
  'backupCorpusLibrary',
  'restoreCorpusLibrary',
  'repairCorpusLibrary',
  'listSavedCorpora',
  'listSearchableCorpora',
  'searchLibraryKWIC',
  'listRecycleBin',
  'restoreRecycleEntry',
  'purgeRecycleEntry',
  'createCorpusFolder',
  'renameCorpusFolder',
  'deleteCorpusFolder',
  'showSavedCorpusInFolder',
  'showRecycleEntryInFolder',
  'openSavedCorpus',
  'openSavedCorpora',
  'renameSavedCorpus',
  'moveSavedCorpus',
  'deleteSavedCorpus',
  'getSmokeAnalysisDelayMs',
  'setZoomFactor',
  'getZoomFactor'
])

function createEmergencyFallbackMethod(methodName, methodConfig = null) {
  if (methodConfig?.kind === 'subscribe' || methodName.startsWith('on')) {
    return () => () => {}
  }
  if (methodConfig?.kind === 'sync' || Object.prototype.hasOwnProperty.call(EMERGENCY_SYNC_FALLBACKS, methodName)) {
    return () => EMERGENCY_SYNC_FALLBACKS[methodName]
  }
  return async () => ({
    success: false,
    message: 'bridge unavailable',
    method: methodName
  })
}

function createEmergencyPreservedMethods(ipcRenderer) {
  try {
    const { createIpcClient } = require('./shared/ipcClient')
    const guards = require('./shared/guards')
    const { createDiagnosticsBridge } = require('./bridges/diagnosticsBridge')
    const ipcClient = createIpcClient({
      ipcRenderer,
      writeLog: writePreloadLog,
      writeError: writePreloadError
    })
    return createDiagnosticsBridge({
      ipcClient,
      ...guards
    })
  } catch (error) {
    writePreloadError('emergency-diagnostics-failed', error)
    return {}
  }
}

function createEmergencyElectronApi(ipcRenderer) {
  let apiCatalog = null
  try {
    apiCatalog = require('./shared/apiCatalog').PRELOAD_API_CATALOG
  } catch (error) {
    writePreloadError('api-catalog-failed', error)
  }

  const preservedMethods = createEmergencyPreservedMethods(ipcRenderer)
  const methodNames = apiCatalog
    ? Object.keys(apiCatalog)
    : EMERGENCY_METHOD_NAMES
  const electronApi = {}

  for (const methodName of methodNames) {
    const preservedMethod = preservedMethods[methodName]
    electronApi[methodName] = typeof preservedMethod === 'function'
      ? preservedMethod
      : createEmergencyFallbackMethod(methodName, apiCatalog?.[methodName] ?? null)
  }

  return {
    electronApi: Object.freeze(electronApi),
    preloadState: {
      platform: process.platform,
      sandboxed: Boolean(process.sandboxed),
      status: 'degraded',
      degraded: true,
      sharedReady: false,
      bridgesReady: false,
      exposed: false,
      methodCount: Object.keys(electronApi).length,
      failedBridges: [
        {
          bridge: 'preload-entry',
          message: 'buildElectronApi failed'
        }
      ],
      duplicateMethods: [],
      missingMethods: []
    }
  }
}

function exposePreload({ contextBridge, ipcRenderer }) {
  process.once('uncaughtException', error => {
    writePreloadError('uncaughtException', error)
  })

  process.once('unhandledRejection', reason => {
    const normalizedError = reason instanceof Error ? reason : new Error(String(reason || 'Promise rejected'))
    writePreloadError('unhandledRejection', normalizedError)
  })

  writePreloadLog('begin', {
    pid: process.pid,
    platform: process.platform,
    sandboxed: Boolean(process.sandboxed)
  })

  let electronApi = null
  let preloadState = null

  try {
    const { buildElectronApi } = require('./buildElectronApi')
    const result = buildElectronApi({
      ipcRenderer,
      platform: process.platform,
      sandboxed: Boolean(process.sandboxed),
      processEnv: process.env,
      writePreloadLog,
      writePreloadError
    })
    electronApi = result.electronApi
    preloadState = result.preloadState
  } catch (error) {
    writePreloadError('build-failed', error)
    const emergencyFallback = createEmergencyElectronApi(ipcRenderer)
    electronApi = emergencyFallback.electronApi
    preloadState = emergencyFallback.preloadState
    writePreloadLog('degraded', {
      methodCount: preloadState.methodCount,
      failedBridges: preloadState.failedBridges
    })
  }

  try {
    preloadState.exposed = true
    const exposedState = deepFreeze({
      ...preloadState
    })
    contextBridge.exposeInMainWorld('electronAPI', electronApi)
    contextBridge.exposeInMainWorld('__WORDZ_PRELOAD_STATE__', exposedState)
    writePreloadLog('exposed', {
      methodCount: preloadState.methodCount,
      degraded: preloadState.degraded,
      status: preloadState.status
    })
  } catch (error) {
    writePreloadError('expose-failed', error, {
      methodCount: preloadState?.methodCount || 0,
      degraded: preloadState?.degraded ?? true
    })
    throw error
  }
}

module.exports = {
  exposePreload
}
