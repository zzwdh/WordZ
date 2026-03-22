const { PRELOAD_API_CATALOG, CRITICAL_PRELOAD_METHODS } = require('./shared/apiCatalog')
const { createAppBridge } = require('./bridges/appBridge')
const { createDiagnosticsBridge } = require('./bridges/diagnosticsBridge')
const { createLibraryBridge } = require('./bridges/libraryBridge')
const { createWindowBridge } = require('./bridges/windowBridge')
const { createUpdateBridge } = require('./bridges/updateBridge')
const { createSmokeBridge } = require('./bridges/smokeBridge')
const { createIpcClient } = require('./shared/ipcClient')
const guards = require('./shared/guards')

const DEFAULT_BRIDGE_FACTORIES = Object.freeze([
  { name: 'appBridge', factory: createAppBridge },
  { name: 'diagnosticsBridge', factory: createDiagnosticsBridge },
  { name: 'libraryBridge', factory: createLibraryBridge },
  { name: 'windowBridge', factory: createWindowBridge },
  { name: 'updateBridge', factory: createUpdateBridge },
  { name: 'smokeBridge', factory: createSmokeBridge }
])

function normalizeFailureError(error) {
  return error instanceof Error ? error : new Error(String(error || 'Unknown preload bridge failure'))
}

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

function createDegradedElectronApi({ preservedMethods = {} } = {}) {
  const electronApi = {}
  for (const [methodName, methodConfig] of Object.entries(PRELOAD_API_CATALOG)) {
    const preservedMethod = preservedMethods[methodName]
    electronApi[methodName] = typeof preservedMethod === 'function'
      ? preservedMethod
      : createFallbackMethod(methodName, methodConfig)
  }
  return electronApi
}

function pickCriticalMethods(methods = {}) {
  const criticalMethods = {}
  for (const methodName of CRITICAL_PRELOAD_METHODS) {
    if (typeof methods[methodName] === 'function') {
      criticalMethods[methodName] = methods[methodName]
    }
  }
  return criticalMethods
}

function buildElectronApi({
  ipcRenderer,
  platform = process.platform,
  sandboxed = Boolean(process.sandboxed),
  processEnv = process.env,
  electronModuleLoader = require,
  writePreloadLog = () => {},
  writePreloadError = () => {},
  bridgeFactories = DEFAULT_BRIDGE_FACTORIES
}) {
  const preloadState = {
    platform,
    sandboxed,
    status: 'booting',
    degraded: false,
    sharedReady: false,
    bridgesReady: false,
    exposed: false,
    methodCount: 0,
    failedBridges: [],
    duplicateMethods: [],
    missingMethods: []
  }

  const sharedContext = {
    ipcClient: createIpcClient({
      ipcRenderer,
      writeLog: writePreloadLog,
      writeError: writePreloadError
    }),
    electronModuleLoader,
    platform,
    processEnv,
    sandboxed,
    ...guards
  }

  preloadState.sharedReady = true
  writePreloadLog('shared-ready', {
    platform,
    sandboxed
  })

  const successfulBridgeMethods = {}
  for (const bridgeEntry of bridgeFactories) {
    try {
      const bridgeMethods = bridgeEntry.factory(sharedContext)
      if (!bridgeMethods || typeof bridgeMethods !== 'object') {
        throw new Error(`bridge "${bridgeEntry.name}" did not return an object`)
      }
      for (const [methodName, methodValue] of Object.entries(bridgeMethods)) {
        if (typeof methodValue !== 'function') {
          throw new Error(`bridge "${bridgeEntry.name}" exported non-function method "${methodName}"`)
        }
        if (Object.prototype.hasOwnProperty.call(successfulBridgeMethods, methodName)) {
          preloadState.duplicateMethods.push(methodName)
          continue
        }
        successfulBridgeMethods[methodName] = methodValue
      }
    } catch (error) {
      const normalizedError = normalizeFailureError(error)
      preloadState.failedBridges.push({
        bridge: bridgeEntry.name,
        message: normalizedError.message
      })
      writePreloadError('bridge-failed', normalizedError, {
        bridge: bridgeEntry.name
      })
    }
  }

  preloadState.missingMethods = Object.keys(PRELOAD_API_CATALOG).filter(
    methodName => !Object.prototype.hasOwnProperty.call(successfulBridgeMethods, methodName)
  )

  const hasDuplicateMethods = preloadState.duplicateMethods.length > 0
  const hasBridgeFailures = preloadState.failedBridges.length > 0
  const hasMissingMethods = preloadState.missingMethods.length > 0
  preloadState.degraded = hasDuplicateMethods || hasBridgeFailures || hasMissingMethods
  preloadState.bridgesReady = true

  let electronApi = null
  if (hasDuplicateMethods) {
    preloadState.failedBridges.push({
      bridge: 'bridge-aggregate',
      message: `duplicate methods: ${preloadState.duplicateMethods.join(', ')}`
    })
    electronApi = createDegradedElectronApi({
      preservedMethods: pickCriticalMethods(successfulBridgeMethods)
    })
  } else if (preloadState.degraded) {
    electronApi = createDegradedElectronApi({
      preservedMethods: successfulBridgeMethods
    })
  } else {
    electronApi = successfulBridgeMethods
  }

  preloadState.methodCount = Object.keys(electronApi).length
  preloadState.status = preloadState.degraded ? 'degraded' : 'ready'

  writePreloadLog('bridges-ready', {
    methodCount: preloadState.methodCount,
    degraded: preloadState.degraded,
    failedBridges: preloadState.failedBridges,
    duplicateMethods: preloadState.duplicateMethods,
    missingMethods: preloadState.missingMethods
  })

  if (preloadState.degraded) {
    writePreloadLog('degraded', {
      methodCount: preloadState.methodCount,
      failedBridges: preloadState.failedBridges,
      duplicateMethods: preloadState.duplicateMethods,
      missingMethods: preloadState.missingMethods
    })
  }

  return {
    electronApi: Object.freeze(electronApi),
    preloadState
  }
}

module.exports = {
  buildElectronApi,
  DEFAULT_BRIDGE_FACTORIES
}
