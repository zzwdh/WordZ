import test from 'node:test'
import assert from 'node:assert/strict'

import {
  getHostServiceMethodNames,
  HOST_API_CATALOG,
  HOST_SERVICE_GROUPS
} from '../renderer/hostContracts.mjs'

test('host contracts expose grouped service method names', () => {
  assert.equal(HOST_API_CATALOG.setWindowDocumentState.kind, 'invoke')
  assert.equal(getHostServiceMethodNames('window').includes('setWindowDocumentState'), true)
  assert.equal(getHostServiceMethodNames('library').includes('openSavedCorpus'), true)
  assert.equal(getHostServiceMethodNames('missing').length, 0)
  assert.ok(Object.keys(HOST_SERVICE_GROUPS).includes('app'))
})
