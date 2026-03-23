const { PRELOAD_API_CATALOG, CRITICAL_PRELOAD_METHODS } = require('./apiCatalog')

function buildFailureResult(methodName) {
  return {
    success: false,
    message: 'bridge unavailable',
    method: methodName
  }
}

function createFallbackMethod(methodName, methodConfig = {}) {
  if (methodConfig.kind === 'subscribe') {
    return () => () => {}
  }
  if (methodConfig.kind === 'sync') {
    return () => methodConfig.fallbackValue
  }
  return async () => buildFailureResult(methodName)
}

function createDegradedElectronApi({ preservedMethods = {}, apiCatalog = PRELOAD_API_CATALOG } = {}) {
  const electronApi = {}
  for (const [methodName, methodConfig] of Object.entries(apiCatalog)) {
    const preservedMethod = preservedMethods[methodName]
    electronApi[methodName] = typeof preservedMethod === 'function'
      ? preservedMethod
      : createFallbackMethod(methodName, methodConfig)
  }
  return electronApi
}

function pickCriticalMethods(methods = {}, criticalMethods = CRITICAL_PRELOAD_METHODS) {
  const criticalMethodMap = {}
  for (const methodName of criticalMethods) {
    if (typeof methods[methodName] === 'function') {
      criticalMethodMap[methodName] = methods[methodName]
    }
  }
  return criticalMethodMap
}

function createEmergencyPreservedMethods({ ipcRenderer, writeLog, writeError }) {
  try {
    const { createIpcClient } = require('./ipcClient')
    const guards = require('./guards')
    const { createDiagnosticsBridge } = require('../bridges/diagnosticsBridge')
    const ipcClient = createIpcClient({
      ipcRenderer,
      writeLog,
      writeError
    })
    return createDiagnosticsBridge({
      ipcClient,
      ...guards
    })
  } catch (error) {
    writeError('emergency-diagnostics-failed', error)
    return {}
  }
}

function createEmergencyElectronApi({ ipcRenderer, writeLog, writeError, apiCatalog = PRELOAD_API_CATALOG } = {}) {
  const preservedMethods = createEmergencyPreservedMethods({
    ipcRenderer,
    writeLog,
    writeError
  })
  const electronApi = createDegradedElectronApi({
    preservedMethods,
    apiCatalog
  })

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

module.exports = {
  buildFailureResult,
  createDegradedElectronApi,
  createEmergencyElectronApi,
  createFallbackMethod,
  pickCriticalMethods
}
