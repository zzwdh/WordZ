import { createAnalysisEngineClient } from './analysisEngineClient.mjs'
import { createInProcessAnalysisEngine } from './inProcessAnalysisEngine.mjs'
import { ANALYSIS_ENGINE_METHOD } from './analysisEngineProtocol.mjs'

function normalizeMethodName(methodName = '') {
  return String(methodName || '').trim()
}

export function createAnalysisEngineService({
  runAnalysisTask,
  segmentedAnalysisChunkChars = 120000,
  segmentedAnalysisThreshold = 1200000,
  sttrChunkSize = 1000,
  engine = createInProcessAnalysisEngine()
} = {}) {
  const client = createAnalysisEngineClient({
    runAnalysisTask,
    segmentedAnalysisChunkChars,
    segmentedAnalysisThreshold,
    sttrChunkSize,
    engine
  })

  const operations = Object.freeze({
    [ANALYSIS_ENGINE_METHOD.BUILD_CORPUS_DATA]: payload => client.buildCorpusData(payload?.text),
    [ANALYSIS_ENGINE_METHOD.COMPUTE_STATS]: payload => client.computeStats(payload),
    [ANALYSIS_ENGINE_METHOD.COMPUTE_NGRAMS]: payload => client.computeNgrams(payload),
    [ANALYSIS_ENGINE_METHOD.SEARCH_KWIC]: payload => client.searchKwic(payload),
    [ANALYSIS_ENGINE_METHOD.SEARCH_COLLOCATES]: payload => client.searchCollocates(payload),
    [ANALYSIS_ENGINE_METHOD.CALCULATE_CHI_SQUARE]: payload => client.calculateChiSquare(payload),
    [ANALYSIS_ENGINE_METHOD.SORT_KWIC_RESULTS]: payload =>
      client.sortKwicResults(payload?.rows, payload?.mode),
    [ANALYSIS_ENGINE_METHOD.BUILD_TOKEN_MATCHER]: payload =>
      client.buildTokenMatcher(payload?.query, payload?.options),
    [ANALYSIS_ENGINE_METHOD.NORMALIZE_SEARCH_OPTIONS]: payload =>
      client.normalizeSearchOptions(payload),
    [ANALYSIS_ENGINE_METHOD.SHOULD_USE_SEGMENTED_ANALYSIS]: payload =>
      client.shouldUseSegmentedAnalysis(payload?.text, payload?.threshold)
  })

  function supports(methodName = '') {
    return client.descriptor?.methods?.includes(normalizeMethodName(methodName)) === true
  }

  function invoke(methodName, payload = {}) {
    const normalizedMethodName = normalizeMethodName(methodName)
    const operation = operations[normalizedMethodName]
    if (!operation) {
      throw new Error(`Unsupported analysis engine method: ${normalizedMethodName || 'unknown'}`)
    }
    return operation(payload)
  }

  return Object.freeze({
    descriptor: client.descriptor,
    runtime: client.runtime,
    normalizeSearchOptions: client.normalizeSearchOptions,
    buildTokenMatcher: client.buildTokenMatcher,
    shouldUseSegmentedAnalysis: client.shouldUseSegmentedAnalysis,
    buildCorpusData: client.buildCorpusData,
    computeStats: client.computeStats,
    computeNgrams: client.computeNgrams,
    searchKwic: client.searchKwic,
    searchCollocates: client.searchCollocates,
    calculateChiSquare: client.calculateChiSquare,
    sortKwicResults: client.sortKwicResults,
    invoke,
    supports
  })
}
