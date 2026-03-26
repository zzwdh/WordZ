import {
  buildCorpusData,
  buildTokenMatcher,
  compareCorpusFrequencies,
  computeSegmentedNgramRows,
  computeSegmentedStats,
  calculateSTTR,
  calculateTTR,
  calculateChiSquare2x2,
  countNgramFrequency,
  countWordFrequency,
  getSortedKWICResults,
  getSortedNgramRows,
  getSortedFrequencyRows,
  normalizeSearchOptions,
  searchCollocates,
  searchKWIC
} from '../../analysisCore.mjs'
import { createAnalysisEngineDescriptor, ANALYSIS_ENGINE_RUNTIME } from './analysisEngineProtocol.mjs'

export { buildTokenMatcher, normalizeSearchOptions }

export function createInProcessAnalysisEngine() {
  const descriptor = createAnalysisEngineDescriptor({
    runtime: ANALYSIS_ENGINE_RUNTIME.IN_PROCESS
  })

  return Object.freeze({
    descriptor,
    runtime: descriptor.runtime,
    buildTokenMatcher,
    normalizeSearchOptions,
    buildCorpusData(text = '') {
      return buildCorpusData(String(text || ''))
    },
    computeStats({
      text = '',
      tokens = [],
      comparisonEntries = [],
      analysisMode = 'full',
      segmentedChunkCharSize = 120000,
      sttrChunkSize = 1000
    } = {}) {
      const shouldCompareAcrossCorpora = Array.isArray(comparisonEntries) && comparisonEntries.length >= 2
      const comparison = shouldCompareAcrossCorpora
        ? compareCorpusFrequencies(comparisonEntries)
        : { corpora: [], rows: [] }

      if (analysisMode === 'segmented') {
        const segmentedStats = computeSegmentedStats(String(text || ''), {
          chunkCharSize: segmentedChunkCharSize,
          sttrChunkSize
        })
        return {
          ...segmentedStats,
          compareCorpora: comparison.corpora,
          compareRows: comparison.rows
        }
      }

      const safeTokens = Array.isArray(tokens) ? tokens : []
      const freqMap = countWordFrequency(safeTokens)
      return {
        freqRows: getSortedFrequencyRows(freqMap),
        tokenCount: safeTokens.length,
        typeCount: Object.keys(freqMap).length,
        ttr: calculateTTR(safeTokens),
        sttr: calculateSTTR(safeTokens, sttrChunkSize),
        compareCorpora: comparison.corpora,
        compareRows: comparison.rows
      }
    },
    computeNgrams({
      text = '',
      tokens = [],
      n = 2,
      analysisMode = 'full',
      segmentedChunkCharSize = 120000
    } = {}) {
      const normalizedN = Math.max(1, Number(n) || 2)
      if (analysisMode === 'segmented') {
        return computeSegmentedNgramRows(String(text || ''), normalizedN, {
          chunkCharSize: segmentedChunkCharSize
        })
      }

      const safeTokens = Array.isArray(tokens) ? tokens : []
      const freqMap = countNgramFrequency(safeTokens, normalizedN)
      return {
        n: normalizedN,
        rows: getSortedNgramRows(freqMap)
      }
    },
    searchKwic({
      tokenObjects = [],
      keyword = '',
      leftWindowSize = 5,
      rightWindowSize = 5,
      searchOptions = {}
    } = {}) {
      return searchKWIC(
        Array.isArray(tokenObjects) ? tokenObjects : [],
        String(keyword || ''),
        Number(leftWindowSize) || 0,
        Number(rightWindowSize) || 0,
        normalizeSearchOptions(searchOptions)
      )
    },
    searchCollocates({
      tokenObjects = [],
      tokens = [],
      keyword = '',
      leftWindowSize = 5,
      rightWindowSize = 5,
      minFreq = 1,
      searchOptions = {}
    } = {}) {
      return searchCollocates(
        Array.isArray(tokenObjects) ? tokenObjects : [],
        Array.isArray(tokens) ? tokens : [],
        String(keyword || ''),
        Number(leftWindowSize) || 0,
        Number(rightWindowSize) || 0,
        Number(minFreq) || 1,
        normalizeSearchOptions(searchOptions)
      )
    },
    calculateChiSquare(inputValues = {}) {
      return calculateChiSquare2x2(inputValues)
    },
    sortKwicResults(rows = [], mode = 'original') {
      return getSortedKWICResults(Array.isArray(rows) ? rows : [], String(mode || 'original'))
    },
    shouldUseSegmentedAnalysis(text = '', threshold = 1200000) {
      return String(text || '').length >= Math.max(0, Number(threshold) || 0)
    }
  })
}
