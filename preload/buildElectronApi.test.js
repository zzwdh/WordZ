const test = require('node:test')
const assert = require('node:assert/strict')

const { buildElectronApi } = require('./buildElectronApi')
const { PRELOAD_API_CATALOG } = require('./shared/apiCatalog')

function createFakeIpcRenderer() {
  return {
    invoke(channel, payload) {
      return Promise.resolve({
        success: true,
        channel,
        payload
      })
    },
    on() {},
    removeListener() {}
  }
}

test('buildElectronApi exposes the full flat API without duplicate keys', () => {
  const { electronApi, preloadState } = buildElectronApi({
    ipcRenderer: createFakeIpcRenderer(),
    writePreloadLog() {},
    writePreloadError() {}
  })

  const apiMethodNames = Object.keys(electronApi).sort()
  const catalogMethodNames = Object.keys(PRELOAD_API_CATALOG).sort()
  assert.deepEqual(apiMethodNames, catalogMethodNames)
  assert.equal(preloadState.degraded, false)
  assert.deepEqual(preloadState.duplicateMethods, [])
  assert.deepEqual(preloadState.missingMethods, [])
})

test('buildElectronApi degrades gracefully and still exposes every method', async () => {
  const { electronApi, preloadState } = buildElectronApi({
    ipcRenderer: createFakeIpcRenderer(),
    bridgeFactories: [
      {
        name: 'diagnosticsBridge',
        factory: () => ({
          getDiagnosticState: async () => ({ success: true, diagnostics: { sessionId: 'ok' } }),
          exportDiagnosticReportAuto: async () => ({ success: true, filePath: '/tmp/report.md' }),
          openGitHubFeedback: async () => ({ success: true, issueUrl: 'https://example.com' }),
          resetWindowsCompatProfile: async () => ({ success: true }),
          consumeCrashRecoveryState: async () => ({ success: true, recoveryState: null })
        })
      },
      {
        name: 'brokenBridge',
        factory: () => {
          throw new Error('boom')
        }
      }
    ],
    writePreloadLog() {},
    writePreloadError() {}
  })

  assert.equal(preloadState.degraded, true)
  assert.equal(typeof electronApi.onSystemOpenFileRequest(() => {}), 'function')
  assert.deepEqual(await electronApi.getDiagnosticState(), { success: true, diagnostics: { sessionId: 'ok' } })
  assert.deepEqual(await electronApi.getAppInfo(), {
    success: false,
    message: 'bridge unavailable',
    method: 'getAppInfo'
  })
})

test('subscribe fallback always returns a callable unsubscribe function', () => {
  const { electronApi } = buildElectronApi({
    ipcRenderer: createFakeIpcRenderer(),
    bridgeFactories: [],
    writePreloadLog() {},
    writePreloadError() {}
  })

  const unsubscribe = electronApi.onAutoUpdateStatus(() => {})
  assert.equal(typeof unsubscribe, 'function')
  unsubscribe()
})

test('zoom bridge lazily loads webFrame only when zoom APIs are used', () => {
  let electronRequireCount = 0
  const fakeWebFrame = {
    setZoomFactor() {},
    getZoomFactor() {
      return 1.12
    }
  }

  const { electronApi } = buildElectronApi({
    ipcRenderer: createFakeIpcRenderer(),
    electronModuleLoader(moduleName) {
      if (moduleName === 'electron') {
        electronRequireCount += 1
        return { webFrame: fakeWebFrame }
      }
      throw new Error(`unexpected module request: ${moduleName}`)
    },
    writePreloadLog() {},
    writePreloadError() {}
  })

  assert.equal(electronRequireCount, 0)
  assert.equal(electronApi.getZoomFactor(), 1.12)
  assert.equal(electronRequireCount, 1)
  electronApi.setZoomFactor(1.1)
  assert.equal(electronRequireCount, 1)
})
