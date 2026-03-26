import test from 'node:test'
import assert from 'node:assert/strict'

import {
  createStopwordMatcher,
  getStopwordSummaryText,
  normalizeStopwordFilterState,
  parseStopwordList
} from '../renderer/stopwordFilter.mjs'

test('parseStopwordList de-duplicates mixed separators', () => {
  const result = parseStopwordList('the, and\nof；the  to\tand')
  assert.deepEqual(result, ['the', 'and', 'of', 'to'])
})

test('normalizeStopwordFilterState falls back to default mode and preserves list text', () => {
  const result = normalizeStopwordFilterState({
    enabled: true,
    mode: 'unexpected',
    listText: 'The\nAnd'
  })
  assert.equal(result.enabled, true)
  assert.equal(result.mode, 'exclude')
  assert.equal(result.listText, 'the\nand')
})

test('createStopwordMatcher exclude mode filters exact tokens and ngram members', () => {
  const matcher = createStopwordMatcher({
    enabled: true,
    mode: 'exclude',
    listText: 'the\nand'
  })
  assert.equal(matcher.matches('rose garden'), true)
  assert.equal(matcher.matches('the rose'), false)
  assert.equal(matcher.matches('and'), false)
})

test('createStopwordMatcher include mode keeps rows that contain stopwords', () => {
  const matcher = createStopwordMatcher({
    enabled: true,
    mode: 'include',
    listText: 'the\nand'
  })
  assert.equal(matcher.matches('rose garden'), false)
  assert.equal(matcher.matches('the rose'), true)
  assert.equal(matcher.matches('and'), true)
})

test('getStopwordSummaryText reports disabled, empty and enabled states', () => {
  assert.equal(getStopwordSummaryText({ enabled: false, mode: 'exclude', listText: 'the' }), 'Stopword 关闭')
  assert.equal(getStopwordSummaryText({ enabled: true, mode: 'exclude', listText: '' }), '词表为空 · 当前不生效')
  assert.equal(getStopwordSummaryText({ enabled: true, mode: 'include', listText: 'the\nand' }), '仅保留词表内词项 · 2 词')
})
