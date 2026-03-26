import { createMacHost } from './macHost.mjs'
import { getHostServiceMethodNames } from './hostContracts.mjs'

function pickHostMethods(api, methodNames = []) {
  const service = {}
  for (const methodName of methodNames) {
    if (typeof api?.[methodName] === 'function') {
      service[methodName] = api[methodName]
    }
  }
  return Object.freeze(service)
}

export function createMacHostServices(sourceApi = globalThis.window?.electronAPI) {
  const api = createMacHost(sourceApi)

  const services = {
    api,
    app: pickHostMethods(api, getHostServiceMethodNames('app')),
    settings: pickHostMethods(api, getHostServiceMethodNames('settings')),
    update: pickHostMethods(api, getHostServiceMethodNames('update')),
    diagnostics: pickHostMethods(api, getHostServiceMethodNames('diagnostics')),
    cache: pickHostMethods(api, getHostServiceMethodNames('cache')),
    library: pickHostMethods(api, getHostServiceMethodNames('library')),
    workspace: pickHostMethods(api, getHostServiceMethodNames('workspace')),
    window: pickHostMethods(api, getHostServiceMethodNames('window')),
    files: pickHostMethods(api, getHostServiceMethodNames('files')),
    smoke: pickHostMethods(api, getHostServiceMethodNames('smoke')),
    raw: api.raw,
    isMethodAvailable: api.isMethodAvailable
  }

  return Object.freeze(services)
}
