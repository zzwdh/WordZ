import test from 'node:test'
import assert from 'node:assert/strict'

import { ANALYSIS_ENGINE_METHOD } from '../renderer/engine/analysisEngineProtocol.mjs'
import { createAnalysisEngineService } from '../renderer/engine/analysisEngineService.mjs'

test('analysis engine service exposes stable capabilities and runtime metadata', () => {
  const service = createAnalysisEngineService()

  assert.equal(service.runtime, 'in-process')
  assert.equal(service.supports(ANALYSIS_ENGINE_METHOD.COMPUTE_STATS), true)
  assert.equal(service.supports('unknown-method'), false)
  assert.equal(typeof service.normalizeSearchOptions, 'function')
  assert.equal(typeof service.buildTokenMatcher, 'function')
})

test('analysis engine service invokes build corpus through method contract', async () => {
  const service = createAnalysisEngineService()
  const result = await service.invoke(ANALYSIS_ENGINE_METHOD.BUILD_CORPUS_DATA, {
    text: 'rose blooms'
  })

  assert.deepEqual(result.tokens, ['rose', 'blooms'])
})

test('analysis engine service rejects unsupported methods', async () => {
  const service = createAnalysisEngineService()

  assert.throws(
    () => service.invoke('not-real'),
    /Unsupported analysis engine method/
  )
})
