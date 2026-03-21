import {
  buildCorpusData,
  computeSegmentedNgramRows,
  computeSegmentedStats,
  compareCorpusFrequencies,
  countNgramFrequency,
  countWordFrequency,
  calculateTTR,
  calculateSTTR,
  getSortedNgramRows,
  getSortedFrequencyRows,
  searchKWIC,
  searchLibraryKWIC,
  searchCollocates
} from './analysisCore.mjs'

const workerUrl = new URL(self.location.href)
const smokeDelayMs = Math.max(0, Number(workerUrl.searchParams.get('delayMs') || 0))

const analysisState = {
  rawText: '',
  sentences: [],
  tokenObjects: [],
  tokens: [],
  freqMap: null,
  ngramMapBySize: new Map()
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

function setCorpus(text) {
  const normalizedText = String(text || '')
  const corpusData = buildCorpusData(normalizedText)
  analysisState.rawText = normalizedText
  analysisState.sentences = corpusData.sentences
  analysisState.tokenObjects = corpusData.tokenObjects
  analysisState.tokens = corpusData.tokens
  analysisState.freqMap = null
  analysisState.ngramMapBySize = new Map()
  return corpusData
}

function ensureFrequencyMap() {
  if (!analysisState.freqMap) {
    analysisState.freqMap = countWordFrequency(analysisState.tokens)
  }
  return analysisState.freqMap
}

function computeStats(payload = {}) {
  const freqMap = ensureFrequencyMap()
  const comparison =
    Array.isArray(payload?.comparisonEntries) && payload.comparisonEntries.length >= 2
      ? compareCorpusFrequencies(payload.comparisonEntries)
      : { corpora: [], rows: [] }
  return {
    freqRows: getSortedFrequencyRows(freqMap),
    tokenCount: analysisState.tokens.length,
    typeCount: Object.keys(freqMap).length,
    ttr: calculateTTR(analysisState.tokens),
    sttr: calculateSTTR(analysisState.tokens, 1000),
    compareCorpora: comparison.corpora,
    compareRows: comparison.rows
  }
}

function computeStatsSegmented(payload = {}) {
  const segmentedStats = computeSegmentedStats(payload?.text || analysisState.rawText || '', {
    chunkCharSize: payload?.chunkCharSize,
    sttrChunkSize: payload?.sttrChunkSize
  })
  const comparison =
    Array.isArray(payload?.comparisonEntries) && payload.comparisonEntries.length >= 2
      ? compareCorpusFrequencies(payload.comparisonEntries)
      : { corpora: [], rows: [] }
  return {
    ...segmentedStats,
    compareCorpora: comparison.corpora,
    compareRows: comparison.rows,
    compareSignature: String(payload?.compareSignature || '')
  }
}

function computeNgrams(payload = {}) {
  const n = Number(payload?.n || 2)
  if (!Number.isFinite(n) || !Number.isInteger(n) || n <= 0) {
    throw new Error('Ngram 的 N 必须是正整数')
  }

  let ngramMap = analysisState.ngramMapBySize.get(n)
  if (!ngramMap) {
    ngramMap = countNgramFrequency(analysisState.tokens, n)
    analysisState.ngramMapBySize.set(n, ngramMap)
  }

  return {
    n,
    rows: getSortedNgramRows(ngramMap)
  }
}

function computeNgramsSegmented(payload = {}) {
  return computeSegmentedNgramRows(payload?.text || analysisState.rawText || '', payload?.n || 2, {
    chunkCharSize: payload?.chunkCharSize
  })
}

self.onmessage = async event => {
  const { id, type, payload } = event.data || {}

  try {
    let result

    if (smokeDelayMs > 0 && type !== 'load-corpus') {
      await sleep(smokeDelayMs)
    }

    if (type === 'load-corpus') {
      result = setCorpus(payload?.text || '')
    } else if (type === 'compute-stats') {
      result = computeStats(payload)
    } else if (type === 'compute-stats-segmented') {
      result = computeStatsSegmented(payload)
    } else if (type === 'compute-ngrams') {
      result = computeNgrams(payload)
    } else if (type === 'compute-ngrams-segmented') {
      result = computeNgramsSegmented(payload)
    } else if (type === 'search-kwic') {
      result = searchKWIC(
        analysisState.tokenObjects,
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5,
        payload?.searchOptions || {}
      )
    } else if (type === 'search-library-kwic') {
      result = searchLibraryKWIC(
        payload?.corpusEntries || [],
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5,
        payload?.searchOptions || {}
      )
    } else if (type === 'search-collocates') {
      result = searchCollocates(
        analysisState.tokenObjects,
        analysisState.tokens,
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5,
        payload?.minFreq ?? 1,
        payload?.searchOptions || {}
      )
    } else {
      throw new Error(`未知的分析任务：${type}`)
    }

    self.postMessage({
      id,
      success: true,
      result
    })
  } catch (error) {
    self.postMessage({
      id,
      success: false,
      message: error && error.message ? error.message : '分析任务失败'
    })
  }
}
