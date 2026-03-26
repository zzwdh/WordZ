import { ANALYSIS_TASK_TYPES } from '../constants.mjs'
import { createInProcessAnalysisEngine } from './inProcessAnalysisEngine.mjs'

export function createAnalysisEngineClient({
  runAnalysisTask,
  segmentedAnalysisChunkChars = 120000,
  segmentedAnalysisThreshold = 1200000,
  sttrChunkSize = 1000,
  engine = createInProcessAnalysisEngine()
} = {}) {
  async function dispatch(taskType, payload, fallback, options = {}) {
    if (typeof runAnalysisTask !== 'function') {
      return fallback()
    }
    return runAnalysisTask(taskType, payload, fallback, options)
  }

  return Object.freeze({
    descriptor: engine.descriptor,
    runtime: engine.runtime,
    normalizeSearchOptions: engine.normalizeSearchOptions || undefined,
    buildTokenMatcher: engine.buildTokenMatcher || undefined,
    shouldUseSegmentedAnalysis(text = '', thresholdOverride = segmentedAnalysisThreshold) {
      return engine.shouldUseSegmentedAnalysis(text, thresholdOverride)
    },
    async buildCorpusData(text = '') {
      return dispatch(
        ANALYSIS_TASK_TYPES.loadCorpus,
        { text: String(text || '') },
        () => engine.buildCorpusData(text)
      )
    },
    async computeStats({
      text = '',
      tokens = [],
      comparisonEntries = [],
      analysisMode = 'full',
      compareSignature = 'none',
      taskName = 'stats'
    } = {}) {
      const segmentedMode = analysisMode === 'segmented'
      const result = await dispatch(
        segmentedMode ? ANALYSIS_TASK_TYPES.computeStatsSegmented : ANALYSIS_TASK_TYPES.computeStats,
        segmentedMode
          ? {
              text: String(text || ''),
              chunkCharSize: segmentedAnalysisChunkChars,
              sttrChunkSize,
              compareSignature,
              comparisonEntries: Array.isArray(comparisonEntries) ? comparisonEntries : []
            }
          : {
              comparisonEntries: Array.isArray(comparisonEntries) ? comparisonEntries : []
            },
        () =>
          engine.computeStats({
            text,
            tokens,
            comparisonEntries,
            analysisMode,
            segmentedChunkCharSize: segmentedAnalysisChunkChars,
            sttrChunkSize
          }),
        { taskName }
      )

      return {
        ...result,
        compareSignature
      }
    },
    async computeNgrams({
      text = '',
      tokens = [],
      n = 2,
      analysisMode = 'full'
    } = {}) {
      const segmentedMode = analysisMode === 'segmented'
      return dispatch(
        segmentedMode ? ANALYSIS_TASK_TYPES.computeNgramsSegmented : ANALYSIS_TASK_TYPES.computeNgrams,
        segmentedMode
          ? {
              n,
              text: String(text || ''),
              chunkCharSize: segmentedAnalysisChunkChars
            }
          : { n },
        () =>
          engine.computeNgrams({
            text,
            tokens,
            n,
            analysisMode,
            segmentedChunkCharSize: segmentedAnalysisChunkChars
          })
      )
    },
    async searchKwic({
      tokenObjects = [],
      keyword = '',
      leftWindowSize = 5,
      rightWindowSize = 5,
      searchOptions = {},
      taskName = 'kwic'
    } = {}) {
      return dispatch(
        ANALYSIS_TASK_TYPES.searchKWIC,
        {
          keyword,
          leftWindowSize,
          rightWindowSize,
          searchOptions
        },
        () =>
          engine.searchKwic({
            tokenObjects,
            keyword,
            leftWindowSize,
            rightWindowSize,
            searchOptions
          }),
        { taskName }
      )
    },
    async searchCollocates({
      tokenObjects = [],
      tokens = [],
      keyword = '',
      leftWindowSize = 5,
      rightWindowSize = 5,
      minFreq = 1,
      searchOptions = {},
      taskName = 'collocate'
    } = {}) {
      return dispatch(
        ANALYSIS_TASK_TYPES.searchCollocates,
        {
          keyword,
          leftWindowSize,
          rightWindowSize,
          minFreq,
          searchOptions
        },
        () =>
          engine.searchCollocates({
            tokenObjects,
            tokens,
            keyword,
            leftWindowSize,
            rightWindowSize,
            minFreq,
            searchOptions
          }),
        { taskName }
      )
    },
    calculateChiSquare(inputValues = {}) {
      return engine.calculateChiSquare(inputValues)
    },
    sortKwicResults(rows = [], mode = 'original') {
      return engine.sortKwicResults(rows, mode)
    }
  })
}
