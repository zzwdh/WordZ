function createPreloadState({ platform = process.platform, sandboxed = Boolean(process.sandboxed) } = {}) {
  return {
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
}

function finalizePreloadState(preloadState, {
  electronApi,
  failedBridges = [],
  duplicateMethods = [],
  missingMethods = []
} = {}) {
  preloadState.failedBridges = failedBridges
  preloadState.duplicateMethods = duplicateMethods
  preloadState.missingMethods = missingMethods
  preloadState.degraded =
    failedBridges.length > 0 ||
    duplicateMethods.length > 0 ||
    missingMethods.length > 0
  preloadState.bridgesReady = true
  preloadState.methodCount = Object.keys(electronApi || {}).length
  preloadState.status = preloadState.degraded ? 'degraded' : 'ready'
  return preloadState
}

module.exports = {
  createPreloadState,
  finalizePreloadState
}
