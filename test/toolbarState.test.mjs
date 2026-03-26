import test from 'node:test'
import assert from 'node:assert/strict'

import {
  buildAnalysisActionButtonState,
  buildLoadSelectedCorporaButtonState
} from '../renderer/viewModels/toolbarState.mjs'

test('toolbar state keeps primary analysis actions enabled when idle', () => {
  const state = buildAnalysisActionButtonState()

  assert.equal(state.buttons.count.disabled, false)
  assert.equal(state.buttons.ngram.disabled, false)
  assert.equal(state.buttons.kwic.disabled, false)
  assert.equal(state.buttons.collocate.disabled, false)
  assert.equal(state.buttons.cancelStats.hidden, true)
  assert.equal(state.buttons.cancelKwic.hidden, true)
  assert.equal(state.buttons.cancelCollocate.hidden, true)
})

test('toolbar state disables segmented search actions and exposes cancel labels', () => {
  const state = buildAnalysisActionButtonState({
    activeCancelableAnalysis: 'kwic',
    cancellingAnalysis: 'kwic',
    currentAnalysisMode: 'segmented'
  })

  assert.equal(state.buttons.count.disabled, true)
  assert.equal(state.buttons.ngram.disabled, true)
  assert.equal(state.buttons.kwic.disabled, true)
  assert.equal(state.buttons.collocate.disabled, true)
  assert.match(state.buttons.kwic.title, /分段分析模式/)
  assert.equal(state.buttons.cancelKwic.hidden, false)
  assert.equal(state.buttons.cancelKwic.disabled, true)
  assert.equal(state.buttons.cancelKwic.label, '正在取消...')
})

test('load selected corpora button state reflects current selection count', () => {
  assert.deepEqual(buildLoadSelectedCorporaButtonState(0), {
    disabled: true,
    label: '载入选中语料'
  })

  assert.deepEqual(buildLoadSelectedCorporaButtonState(3), {
    disabled: false,
    label: '载入选中语料（3）'
  })
})
