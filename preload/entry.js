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

function createEmergencyElectronApi(ipcRenderer) {
  try {
    const { createEmergencyElectronApi: createFallbackApi } = require('./shared/fallbackApi')
    return createFallbackApi({
      ipcRenderer,
      writeLog: writePreloadLog,
      writeError: writePreloadError
    })
  } catch (error) {
    writePreloadError('emergency-fallback-failed', error)
    return {
      electronApi: Object.freeze({}),
      preloadState: {
        platform: process.platform,
        sandboxed: Boolean(process.sandboxed),
        status: 'degraded',
        degraded: true,
        sharedReady: false,
        bridgesReady: false,
        exposed: false,
        methodCount: 0,
        failedBridges: [
          {
            bridge: 'preload-entry',
            message: 'emergency fallback failed'
          }
        ],
        duplicateMethods: [],
        missingMethods: []
      }
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
