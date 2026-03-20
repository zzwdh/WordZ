import test from 'node:test'
import assert from 'node:assert/strict'

import {
  buildCorpusData,
  compareCorpusFrequencies,
  countWordFrequency,
  calculateTTR,
  calculateSTTR,
  getSortedFrequencyRows,
  getSortedKWICResults,
  searchLibraryKWIC,
  searchKWIC,
  searchCollocates
} from '../analysisCore.mjs'

test('buildCorpusData splits sentences and tokens consistently', () => {
  const corpus = buildCorpusData("Rose blooms. Rose's petals glow!")

  assert.equal(corpus.sentences.length, 2)
  assert.deepEqual(corpus.tokens, ['rose', 'blooms', "rose's", 'petals', 'glow'])
  assert.equal(corpus.tokenObjects[0].sentenceId, 0)
  assert.equal(corpus.tokenObjects[2].sentenceId, 1)
})

test('frequency statistics are stable for repeated tokens', () => {
  const tokens = ['rose', 'rose', 'petal', 'wind']
  const freqMap = countWordFrequency(tokens)

  assert.deepEqual(getSortedFrequencyRows(freqMap), [
    ['rose', 2],
    ['petal', 1],
    ['wind', 1]
  ])
  assert.equal(calculateTTR(tokens), 0.75)
  assert.equal(calculateSTTR(tokens, 10), 0.75)
})

test('kwic sorting and collocate counting produce expected outputs', () => {
  const corpus = buildCorpusData('red rose blooms. white rose fades. red rose returns.')
  const kwicRows = searchKWIC(corpus.tokenObjects, 'rose', 1, 1)
  const sortedKWIC = getSortedKWICResults(kwicRows, 'left-near')
  const collocates = searchCollocates(corpus.tokenObjects, corpus.tokens, 'rose', 1, 1, 1)

  assert.equal(sortedKWIC.length, 3)
  assert.equal(sortedKWIC[0].left, 'red')
  assert.equal(sortedKWIC[1].left, 'red')
  assert.equal(sortedKWIC[2].left, 'white')

  assert.deepEqual(collocates[0], {
    word: 'red',
    total: 2,
    left: 2,
    right: 0,
    wordFreq: 2,
    keywordFreq: 3,
    rate: 2 / 3
  })
  assert.equal(collocates[1].word, 'blooms')
  assert.equal(collocates[2].word, 'fades')
})

test('library kwic search keeps corpus and folder context across multiple corpora', () => {
  const results = searchLibraryKWIC([
    {
      corpusId: 'corpus-a',
      corpusName: '语料A',
      folderId: 'folder-a',
      folderName: '文学',
      content: 'red rose blooms. bright wind.'
    },
    {
      corpusId: 'corpus-b',
      corpusName: '语料B',
      folderId: 'folder-b',
      folderName: '新闻',
      content: 'white rose fades. rose returns.'
    }
  ], 'rose', 1, 1)

  assert.equal(results.length, 3)
  assert.deepEqual(
    results.map(item => [item.corpusId, item.corpusName, item.folderName, item.left, item.node, item.right]),
    [
      ['corpus-a', '语料A', '文学', 'red', 'rose', 'blooms'],
      ['corpus-b', '语料B', '新闻', 'white', 'rose', 'fades'],
      ['corpus-b', '语料B', '新闻', 'fades', 'rose', 'returns']
    ]
  )
})

test('search query options change matching behavior for kwic and collocates', () => {
  const corpus = buildCorpusData('Cyber rises. cyber grows. CYBER returns fast.')

  assert.equal(
    searchKWIC(corpus.tokenObjects, 'Cyber', 1, 1, { words: true, caseSensitive: true }).length,
    1
  )
  assert.equal(
    searchKWIC(corpus.tokenObjects, 'Cyber', 1, 1, { words: true, caseSensitive: false }).length,
    3
  )
  assert.equal(
    searchKWIC(corpus.tokenObjects, 'ybe', 1, 1, { words: false, caseSensitive: false }).length,
    3
  )
  assert.equal(
    searchKWIC(corpus.tokenObjects, '^c.*r$', 1, 1, { words: false, regex: true, caseSensitive: false }).length,
    3
  )

  const collocates = searchCollocates(
    corpus.tokenObjects,
    corpus.tokens,
    'Cyber',
    1,
    1,
    1,
    { words: true, caseSensitive: true }
  )
  assert.deepEqual(collocates[0], {
    word: 'rises',
    total: 1,
    left: 0,
    right: 1,
    wordFreq: 1,
    keywordFreq: 1,
    rate: 1
  })
})

test('multi-corpus comparison summarizes spread, dominant corpus and normalized range', () => {
  const comparison = compareCorpusFrequencies([
    {
      corpusId: 'corpus-a',
      corpusName: '语料A',
      folderName: '文学',
      content: 'rose rose bloom bright'
    },
    {
      corpusId: 'corpus-b',
      corpusName: '语料B',
      folderName: '新闻',
      content: 'rose bright bright wind'
    }
  ])

  assert.equal(comparison.corpora.length, 2)
  assert.equal(comparison.corpora[0].tokenCount, 4)
  assert.equal(comparison.corpora[1].topWord, 'bright')

  const roseRow = comparison.rows.find(row => row.word === 'rose')
  assert.ok(roseRow)
  assert.equal(roseRow.spread, 2)
  assert.equal(roseRow.total, 3)
  assert.equal(roseRow.dominantCorpusName, '语料A')
  assert.equal(roseRow.perCorpus[0].count, 2)
  assert.equal(roseRow.perCorpus[1].count, 1)
  assert.equal(roseRow.range, 2500)

  const bloomRow = comparison.rows.find(row => row.word === 'bloom')
  assert.ok(bloomRow)
  assert.equal(bloomRow.spread, 1)
  assert.equal(bloomRow.dominantCorpusName, '语料A')
  assert.equal(bloomRow.perCorpus[1].count, 0)
})
