const { PRELOAD_API_CATALOG, CRITICAL_PRELOAD_METHODS } = require('./shared/apiCatalog')
const { DEFAULT_BRIDGE_FACTORIES } = require('./bridgeRegistry')
const {
  createDegradedElectronApi,
  pickCriticalMethods
} = require('./shared/fallbackApi')
const { createIpcClient } = require('./shared/ipcClient')
const { createPreloadState, finalizePreloadState } = require('./shared/preloadState')
const guards = require('./shared/guards')

function normalizeFailureError(error) {
  return error instanceof Error ? error : new Error(String(error || 'Unknown preload bridge failure'))
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
  const preloadState = createPreloadState({
    platform,
    sandboxed
  })

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

  const missingMethods = Object.keys(PRELOAD_API_CATALOG).filter(
    methodName => !Object.prototype.hasOwnProperty.call(successfulBridgeMethods, methodName)
  )

  const duplicateMethods = [...preloadState.duplicateMethods]
  const failedBridges = [...preloadState.failedBridges]
  const hasDuplicateMethods = duplicateMethods.length > 0
  const hasBridgeFailures = failedBridges.length > 0
  const hasMissingMethods = missingMethods.length > 0

  let electronApi = null
  if (hasDuplicateMethods) {
    failedBridges.push({
      bridge: 'bridge-aggregate',
      message: `duplicate methods: ${duplicateMethods.join(', ')}`
    })
    electronApi = createDegradedElectronApi({
      preservedMethods: pickCriticalMethods(successfulBridgeMethods, CRITICAL_PRELOAD_METHODS)
    })
  } else if (hasBridgeFailures || hasMissingMethods) {
    electronApi = createDegradedElectronApi({
      preservedMethods: successfulBridgeMethods
    })
  } else {
    electronApi = successfulBridgeMethods
  }

  finalizePreloadState(preloadState, {
    electronApi,
    failedBridges,
    duplicateMethods,
    missingMethods
  })

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
