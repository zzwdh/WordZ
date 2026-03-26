import { parseStopwordList } from './stopwordFilter.mjs'

export function buildAnalysisSnapshotState({
  currentAnalysisMode,
  currentSentenceObjects,
  currentTokenObjects,
  currentTokens,
  currentFreqRows,
  currentTokenCount,
  currentTypeCount,
  currentTTR,
  currentSTTR,
  currentComparisonEntries,
  currentComparisonCorpora,
  currentComparisonRows
}) {
  return {
    analysisMode: currentAnalysisMode,
    sentenceObjects: currentSentenceObjects,
    tokenObjects: currentTokenObjects,
    tokens: currentTokens,
    freqRows: currentFreqRows,
    tokenCount: currentTokenCount,
    typeCount: currentTypeCount,
    ttr: currentTTR,
    sttr: currentSTTR,
    comparisonEntries: currentComparisonEntries,
    comparisonCorpora: currentComparisonCorpora,
    comparisonRows: currentComparisonRows
  }
}

export function buildStatsState(params = {}) {
  return {
    currentAnalysisMode: params.currentAnalysisMode,
    currentCorpusMode: params.currentCorpusMode,
    currentCorpusDisplayName: params.currentCorpusDisplayName,
    currentCorpusFolderName: params.currentCorpusFolderName,
    currentSelectedCorpora: params.currentSelectedCorpora,
    currentTokens: params.currentTokens,
    currentFreqRows: params.currentFreqRows,
    currentDisplayedFreqRows: params.currentDisplayedFreqRows,
    currentSearchQuery: params.currentSearchQuery,
    currentSearchOptions: params.currentSearchOptions,
    currentSearchError: params.currentSearchError,
    currentStopwordFilter: params.currentStopwordFilter,
    currentStopwordSummary: params.currentStopwordSummary,
    currentPage: params.currentPage,
    pageSize: params.pageSize,
    currentTokenCount: params.currentTokenCount,
    currentTypeCount: params.currentTypeCount,
    currentTTR: params.currentTTR,
    currentSTTR: params.currentSTTR
  }
}

export function buildCompareState(params = {}) {
  return {
    currentSelectedCorpora: params.currentSelectedCorpora,
    currentFreqRows: params.currentFreqRows,
    currentTokenCount: params.currentTokenCount,
    currentComparisonEntries: params.currentComparisonEntries,
    currentComparisonRows: params.currentComparisonRows,
    currentComparisonCorpora: params.currentComparisonCorpora,
    currentDisplayedCompareRows: params.currentDisplayedCompareRows,
    currentSearchQuery: params.currentSearchQuery,
    currentSearchError: params.currentSearchError,
    currentStopwordFilter: params.currentStopwordFilter,
    currentStopwordSummary: params.currentStopwordSummary,
    currentComparePage: params.currentComparePage,
    currentComparePageSize: params.currentComparePageSize,
    hasStats: params.hasStats,
    comparisonEligible: params.comparisonEligible
  }
}

export function buildNgramState(params = {}) {
  return {
    currentNgramRows: params.currentNgramRows,
    currentDisplayedNgramRows: params.currentDisplayedNgramRows,
    currentNgramPage: params.currentNgramPage,
    currentNgramPageSize: params.currentNgramPageSize,
    currentSearchQuery: params.currentSearchQuery,
    currentSearchError: params.currentSearchError,
    currentStopwordFilter: params.currentStopwordFilter,
    currentStopwordSummary: params.currentStopwordSummary
  }
}

export function buildKWICState(params = {}) {
  return {
    currentKWICResults: params.currentKWICResults,
    currentKWICPage: params.currentKWICPage,
    currentKWICPageSize: params.currentKWICPageSize,
    currentKWICSortMode: params.currentKWICSortMode,
    currentKWICKeyword: params.currentKWICKeyword,
    currentSearchOptions: params.currentSearchOptions,
    currentKWICLeftWindow: params.currentKWICLeftWindow,
    currentKWICRightWindow: params.currentKWICRightWindow,
    currentKWICScope: params.currentKWICScope,
    currentKWICScopeLabel: params.currentKWICScopeLabel,
    currentKWICSearchedCorpusCount: params.currentKWICSearchedCorpusCount,
    currentKWICSortCache: params.currentKWICSortCache
  }
}

export function buildCollocateState(params = {}) {
  return {
    currentCollocateRows: params.currentCollocateRows,
    currentCollocatePage: params.currentCollocatePage,
    currentCollocatePageSize: params.currentCollocatePageSize
  }
}

export function buildLocatorState(params = {}) {
  return {
    currentSentenceObjects: params.currentSentenceObjects,
    currentHighlight: params.currentHighlight,
    activeSentenceId: params.activeSentenceId,
    pendingLocatorScrollSentenceId: params.pendingLocatorScrollSentenceId
  }
}

export function buildDiagnosticRendererState(params = {}) {
  return {
    currentTab: params.currentTab,
    corpusMode: params.currentCorpusMode,
    analysisMode: params.currentAnalysisMode,
    corpusDisplayName: params.currentCorpusDisplayName,
    corpusFolderName: params.currentCorpusFolderName || '',
    selectedCorporaCount: params.currentSelectedCorpora?.length || 0,
    currentLibraryFolderId: params.currentLibraryFolderId,
    libraryFolderCount: params.currentLibraryFolders?.length || 0,
    libraryVisibleCount: params.currentLibraryVisibleCount,
    libraryTotalCount: params.currentLibraryTotalCount,
    currentSearchQuery: params.currentSearchQuery,
    searchOptionsSummary: params.searchOptionsSummary,
    stopwordFilter: {
      ...(params.currentStopwordFilter || {}),
      wordCount: parseStopwordList(params.currentStopwordFilter?.listText).length,
      summary: params.currentStopwordSummary
    },
    tokenCount: params.currentTokenCount,
    typeCount: params.currentTypeCount,
    ngramSize: params.currentNgramSize,
    ngramResultCount: params.currentNgramRows?.length || 0,
    kwicKeyword: params.currentKWICKeyword,
    kwicResultCount: params.currentKWICResults?.length || 0,
    kwicScope: params.currentKWICScopeLabel,
    collocateKeyword: params.currentCollocateKeyword,
    collocateResultCount: params.currentCollocateRows?.length || 0,
    chiSquareHasResult: Boolean(params.currentChiSquareResult),
    chiSquareInputs: {
      ...(params.currentChiSquareInputValues || {})
    },
    locatorSentenceCount: params.currentSentenceObjects?.length || 0,
    taskCenter: (params.taskCenterEntries || []).slice(0, 5).map(entry => ({
      taskKey: entry.taskKey,
      status: entry.status,
      detail: entry.detail,
      durationMs: entry.durationMs || 0
    })),
    startupPhases: (params.startupPhaseEvents || []).slice(-16).map(event => ({
      phase: event.phase,
      status: event.status,
      durationMs: Number(event.durationMs) || 0,
      startedAt: event.startedAt || '',
      endedAt: event.endedAt || '',
      errorMessage: event.errorMessage || ''
    })),
    uiSettings: params.currentUISettings
  }
}
