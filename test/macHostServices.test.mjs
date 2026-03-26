import test from 'node:test'
import assert from 'node:assert/strict'

import { createMacHostServices } from '../renderer/macHostServices.mjs'

test('mac host services group methods by domain', async () => {
  const sourceApi = {
    getAppInfo: async () => ({ success: true }),
    openSavedCorpus: async id => ({ success: true, id }),
    setWindowDocumentState: async payload => ({ success: true, payload }),
    checkForUpdates: async () => ({ success: true }),
    getSmokeObserverState: async () => ({ success: true })
  }

  const services = createMacHostServices(sourceApi)

  assert.equal(typeof services.app.getAppInfo, 'function')
  assert.equal(typeof services.library.openSavedCorpus, 'function')
  assert.equal(typeof services.window.setWindowDocumentState, 'function')
  assert.equal(typeof services.update.checkForUpdates, 'function')
  assert.equal(typeof services.smoke.getSmokeObserverState, 'function')
  assert.equal(typeof services.library.getAppInfo, 'undefined')

  const result = await services.library.openSavedCorpus('demo')
  assert.deepEqual(result, { success: true, id: 'demo' })
})

