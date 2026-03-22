import { parentPort, workerData } from 'node:worker_threads'

import {
  buildCorpusData,
  calculateChiSquare2x2,
  calculateSTTR,
  calculateTTR,
  compareCorpusFrequencies,
  countNgramFrequency,
  countWordFrequency,
  getSortedFrequencyRows,
  getSortedKWICResults,
  getSortedNgramRows,
  searchCollocates,
  searchKWIC,
  searchLibraryKWIC
} from '../../../analysisCore.mjs'

function assertPort() {
  if (!parentPort) {
    throw new Error('Analysis task worker requires parentPort.')
  }
}

function buildLocatorRows({ text = '', sentenceId = 0, nodeIndex = 0, leftWindowSize = 5, rightWindowSize = 5 } = {}) {
  const corpusData = buildCorpusData(text)
  const targetSentenceId = Number(sentenceId)
  const targetNodeIndex = Number(nodeIndex)
  const rows = corpusData.sentences.map(sentence => {
    const isTarget = sentence.id === targetSentenceId
    const leftWords = isTarget
      ? sentence.normalizedTokens.slice(Math.max(0, targetNodeIndex - leftWindowSize), targetNodeIndex).join(' ')
      : ''
    const nodeWord = isTarget ? (sentence.normalizedTokens[targetNodeIndex] || '') : ''
    const rightWords = isTarget
      ? sentence.normalizedTokens.slice(targetNodeIndex + 1, targetNodeIndex + 1 + rightWindowSize).join(' ')
      : ''
    return {
      sentenceId: sentence.id,
      text: sentence.text,
      leftWords,
      nodeWord,
      rightWords,
      status: isTarget ? '当前定位' : ''
    }
  })
  return {
    sentences: corpusData.sentences,
    rows
  }
}

function computeStats({ text = '', comparisonEntries = [] } = {}) {
  const corpusData = buildCorpusData(text)
  const freqMap = countWordFrequency(corpusData.tokens)
  const comparison = Array.isArray(comparisonEntries) && comparisonEntries.length >= 2
    ? compareCorpusFrequencies(comparisonEntries)
    : { corpora: [], rows: [] }

  return {
    sentences: corpusData.sentences,
    freqRows: getSortedFrequencyRows(freqMap),
    tokenCount: corpusData.tokens.length,
    typeCount: Object.keys(freqMap).length,
    ttr: calculateTTR(corpusData.tokens),
    sttr: calculateSTTR(corpusData.tokens, 1000),
    compareCorpora: comparison.corpora,
    compareRows: comparison.rows
  }
}

function computeNgram({ text = '', n = 2 } = {}) {
  const corpusData = buildCorpusData(text)
  return {
    n,
    rows: getSortedNgramRows(countNgramFrequency(corpusData.tokens, n))
  }
}

function computeKwic({ text = '', keyword = '', leftWindowSize = 5, rightWindowSize = 5, searchOptions = {}, sortMode = 'original' } = {}) {
  const corpusData = buildCorpusData(text)
  const rows = searchKWIC(corpusData.tokenObjects, keyword, leftWindowSize, rightWindowSize, searchOptions)
  return {
    rows: getSortedKWICResults(rows, sortMode),
    sentences: corpusData.sentences
  }
}

function computeLibraryKwic({ corpusEntries = [], keyword = '', leftWindowSize = 5, rightWindowSize = 5, searchOptions = {}, sortMode = 'original' } = {}) {
  const rows = searchLibraryKWIC(corpusEntries, keyword, leftWindowSize, rightWindowSize, searchOptions)
  return {
    rows: getSortedKWICResults(rows, sortMode)
  }
}

function computeCollocates({
  text = '',
  keyword = '',
  leftWindowSize = 5,
  rightWindowSize = 5,
  minFreq = 1,
  searchOptions = {}
} = {}) {
  const corpusData = buildCorpusData(text)
  return {
    rows: searchCollocates(
      corpusData.tokenObjects,
      corpusData.tokens,
      keyword,
      leftWindowSize,
      rightWindowSize,
      minFreq,
      searchOptions
    )
  }
}

function computeCompare({ comparisonEntries = [] } = {}) {
  return compareCorpusFrequencies(comparisonEntries)
}

function computeWordCloud({ text = '', limit = 80 } = {}) {
  const corpusData = buildCorpusData(text)
  const rows = getSortedFrequencyRows(countWordFrequency(corpusData.tokens)).slice(0, Math.max(1, Number(limit) || 80))
  return { rows }
}

function runTask(taskType, payload = {}) {
  if (taskType === 'stats') return computeStats(payload)
  if (taskType === 'ngram') return computeNgram(payload)
  if (taskType === 'kwic') return computeKwic(payload)
  if (taskType === 'library-kwic') return computeLibraryKwic(payload)
  if (taskType === 'collocate') return computeCollocates(payload)
  if (taskType === 'compare') return computeCompare(payload)
  if (taskType === 'chi-square') return calculateChiSquare2x2(payload)
  if (taskType === 'word-cloud') return computeWordCloud(payload)
  if (taskType === 'locator') return buildLocatorRows(payload)
  throw new Error(`Unsupported task type: ${taskType}`)
}

assertPort()

try {
  const result = runTask(String(workerData?.taskType || ''), workerData?.payload || {})
  parentPort.postMessage({
    success: true,
    result
  })
} catch (error) {
  parentPort.postMessage({
    success: false,
    message: error instanceof Error ? error.message : String(error || 'Analysis task failed')
  })
}
