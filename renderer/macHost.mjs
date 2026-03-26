import { HOST_API_CATALOG } from './hostContracts.mjs'

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
