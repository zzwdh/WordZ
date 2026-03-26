import test from 'node:test'
import assert from 'node:assert/strict'

import { createAnalysisEngineClient } from '../renderer/engine/analysisEngineClient.mjs'

test('analysis engine client exposes in-process runtime and delegates pure methods', () => {
  const client = createAnalysisEngineClient({
    runAnalysisTask: null
  })

  assert.equal(client.runtime, 'in-process')
  assert.equal(client.shouldUseSegmentedAnalysis('a'.repeat(10), 5), true)
  assert.equal(typeof client.calculateChiSquare, 'function')
  assert.equal(typeof client.sortKwicResults, 'function')
})

test('analysis engine client dispatches through runAnalysisTask for corpus build', async () => {
  const calls = []
  const client = createAnalysisEngineClient({
    runAnalysisTask: async (type, payload, fallback) => {
      calls.push([type, payload])
      return fallback()
    }
  })

  const result = await client.buildCorpusData('rose blooms')
  assert.equal(calls[0][0], 'load-corpus')
  assert.deepEqual(result.tokens, ['rose', 'blooms'])
})
