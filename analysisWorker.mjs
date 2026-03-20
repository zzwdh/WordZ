import {
  buildCorpusData,
  countWordFrequency,
  calculateTTR,
  calculateSTTR,
  getSortedFrequencyRows,
  searchKWIC,
  searchLibraryKWIC,
  searchCollocates
} from './analysisCore.mjs'

const workerUrl = new URL(self.location.href)
const smokeDelayMs = Math.max(0, Number(workerUrl.searchParams.get('delayMs') || 0))

const analysisState = {
  sentences: [],
  tokenObjects: [],
  tokens: [],
  freqMap: null
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

function setCorpus(text) {
  const corpusData = buildCorpusData(text)
  analysisState.sentences = corpusData.sentences
  analysisState.tokenObjects = corpusData.tokenObjects
  analysisState.tokens = corpusData.tokens
  analysisState.freqMap = null
  return corpusData
}

function ensureFrequencyMap() {
  if (!analysisState.freqMap) {
    analysisState.freqMap = countWordFrequency(analysisState.tokens)
  }
  return analysisState.freqMap
}

function computeStats() {
  const freqMap = ensureFrequencyMap()
  return {
    freqRows: getSortedFrequencyRows(freqMap),
    tokenCount: analysisState.tokens.length,
    typeCount: Object.keys(freqMap).length,
    ttr: calculateTTR(analysisState.tokens),
    sttr: calculateSTTR(analysisState.tokens, 1000)
  }
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
      result = computeStats()
    } else if (type === 'search-kwic') {
      result = searchKWIC(
        analysisState.tokenObjects,
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5
      )
    } else if (type === 'search-library-kwic') {
      result = searchLibraryKWIC(
        payload?.corpusEntries || [],
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5
      )
    } else if (type === 'search-collocates') {
      result = searchCollocates(
        analysisState.tokenObjects,
        analysisState.tokens,
        payload?.keyword || '',
        payload?.leftWindowSize ?? 5,
        payload?.rightWindowSize ?? 5,
        payload?.minFreq ?? 1
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
