export const ANALYSIS_ENGINE_RUNTIME = Object.freeze({
  IN_PROCESS: 'in-process'
})

export const ANALYSIS_ENGINE_METHOD = Object.freeze({
  BUILD_CORPUS_DATA: 'buildCorpusData',
  COMPUTE_STATS: 'computeStats',
  COMPUTE_NGRAMS: 'computeNgrams',
  SEARCH_KWIC: 'searchKwic',
  SEARCH_COLLOCATES: 'searchCollocates',
  CALCULATE_CHI_SQUARE: 'calculateChiSquare',
  SORT_KWIC_RESULTS: 'sortKwicResults',
  BUILD_TOKEN_MATCHER: 'buildTokenMatcher',
  NORMALIZE_SEARCH_OPTIONS: 'normalizeSearchOptions',
  SHOULD_USE_SEGMENTED_ANALYSIS: 'shouldUseSegmentedAnalysis'
})

export function createAnalysisEngineDescriptor({
  runtime = ANALYSIS_ENGINE_RUNTIME.IN_PROCESS,
  methods = Object.values(ANALYSIS_ENGINE_METHOD)
} = {}) {
  return Object.freeze({
    runtime: String(runtime || ANALYSIS_ENGINE_RUNTIME.IN_PROCESS),
    methods: Object.freeze(Array.from(new Set(methods.map(item => String(item || '').trim()).filter(Boolean))))
  })
}
