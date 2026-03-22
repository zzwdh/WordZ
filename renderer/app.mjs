import {
  compareCorpusFrequencies,
  buildTokenMatcher,
  buildCorpusData,
  computeSegmentedNgramRows,
  computeSegmentedStats,
  calculateSTTR,
  calculateTTR,
  calculateChiSquare2x2,
  countNgramFrequency,
  countWordFrequency,
  getSortedNgramRows,
  getSortedFrequencyRows,
  normalizeSearchOptions,
  getSortedKWICResults as sortKWICResults,
  searchCollocates,
  searchKWIC
} from '../analysisCore.mjs'
import {
  ANALYSIS_TASK_TYPES,
  DEFAULT_APP_INFO,
  BUTTON_ICONS,
  DEFAULT_THEME,
  DEFAULT_UI_SETTINGS,
  DEFAULT_WINDOW_SIZE,
  LARGE_TABLE_THRESHOLD,
  LIBRARY_FOLDER_STORAGE_KEY,
  ONBOARDING_STORAGE_KEY,
  PREVIEW_CHAR_LIMIT,
  RECENT_OPEN_LIMIT,
  RECENT_OPEN_STORAGE_KEY,
  TABLE_RENDER_CHUNK_SIZE,
  UI_FONT_FAMILIES,
  UI_SETTINGS_STORAGE_KEY,
  WORKSPACE_SNAPSHOT_VERSION,
  WORKSPACE_STATE_STORAGE_KEY
} from './constants.mjs'
import {
  applyAppInfoToShell as applyAppInfoToShellView,
  normalizeAppInfo,
  renderHelpCenter as renderHelpCenterView
} from './appInfo.mjs'
import { dom } from './domRefs.mjs'
import { createAnalysisBridge } from './analysisBridge.mjs'
import {
  renderChiSquareResult as renderChiSquareResultSection
} from './features/chiSquare.mjs'
import {
  buildAllCollocateRows as buildAllCollocateRowsData,
  buildCollocateRows as buildCollocateRowsData,
  renderCollocateTable as renderCollocateTableSection
} from './features/collocate.mjs'
import {
  buildAllCompareRows as buildAllCompareRowsData,
  buildCompareRows as buildCompareRowsData,
  renderCompareSection as renderCompareSectionData
} from './features/compare.mjs'
import { createFeedbackController } from './feedback.mjs'
import {
  buildSelectedCorporaTable,
  buildRecycleBinTable,
  buildLibraryFolderList,
  buildLibraryTable,
  getFolderById as getFolderByIdFromList,
  getImportTargetFolder as getImportTargetFolderForState,
  getLibraryTargetChipText
} from './features/library.mjs'
import {
  buildLocatorHighlight,
  buildLocatorRows as buildLocatorRowsData,
  renderSentenceViewer as renderSentenceViewerSection
} from './features/locator.mjs'
import {
  buildAllKWICRows as buildAllKWICRowsData,
  buildKWICRows as buildKWICRowsData,
  renderKWICTable as renderKWICTableSection
} from './features/kwic.mjs'
import {
  buildAllNgramRows as buildAllNgramRowsData,
  buildNgramRows as buildNgramRowsData,
  renderNgramTable as renderNgramTableSection
} from './features/ngram.mjs'
import {
  buildAllFrequencyRows as buildAllFrequencyRowsData,
  buildFrequencyRows as buildFrequencyRowsData,
  buildStatsRows as buildStatsRowsData,
  renderFrequencyTable as renderFrequencyTableSection,
  renderStatsSummary as renderStatsSummarySection,
  renderWordCloud as renderWordCloudSection,
  renderWorkspaceOverview as renderWorkspaceOverviewSection
} from './features/stats.mjs'
import { createTableRenderer } from './tableRender.mjs'
import { createUISettingsController } from './uiSettings.mjs'
import {
  clampNumber,
  escapeHtml,
  formatCount,
  getPreviewText,
  normalizeWindowSizeInput,
  readWindowSizeInput,
  resolvePageSize,
  saveTableFile,
  setButtonsBusy
} from './utils.mjs'
import {
  buildRecentOpenEntryFromResult,
  loadRecentOpenEntries as loadRecentOpenEntriesFromStorage,
  normalizeRecentOpenEntry,
  persistRecentOpenEntries as persistRecentOpenEntriesToStorage,
  renderRecentOpenList as renderRecentOpenListView
} from './recentOpen.mjs'
import {
  getRestorableTabFromSnapshot,
  getWorkspaceSnapshotSummary,
  hasMeaningfulWorkspaceSnapshot,
  loadOnboardingState,
  loadStoredWorkspaceSnapshot as loadStoredWorkspaceSnapshotFromStorage,
  markOnboardingTutorialCompleted,
  shouldShowFirstRunTutorial
} from './sessionState.mjs'
import { createTaskCenterController } from './taskCenter.mjs'
import {
  bindLibraryTableEvents,
  decorateLibraryTableControls,
  decorateRecycleTableControls
} from './controllers/libraryTableEvents.mjs'
import { createOpenCommandController } from './controllers/openCommandController.mjs'
import { createWelcomeUpdateController } from './controllers/welcomeUpdateController.mjs'
import { runDeferredRendererStartup, runInitialRendererSetup } from './startup/flow.mjs'
import { createStartupPhaseRunner } from './startup/phaseRunner.mjs'

function resolveRendererFullProbeMode() {
  try {
    const fromGlobal = String(globalThis.__WORDZ_FULL_PROBE_MODE__ || '').trim().toLowerCase()
    if (fromGlobal === 'safe-style' || fromGlobal === 'delay-renderer-start') {
      return fromGlobal
    }
    const fromQuery = String(new URLSearchParams(window.location.search || '').get('fullProbe') || '').trim().toLowerCase()
    if (fromQuery === 'safe-style' || fromQuery === 'delay-renderer-start') {
      return fromQuery
    }
  } catch {
    // ignore full probe parse failures
  }
  return ''
}

function writeStartupAppLog(scope, details = null) {
  try {
    if (details && typeof details === 'object') {
      console.warn(`[startup.app] ${scope}`, JSON.stringify(details))
      return
    }
    console.warn(`[startup.app] ${scope}`)
  } catch {
    // ignore startup app log failures
  }
}

const fullProbeMode = resolveRendererFullProbeMode()
writeStartupAppLog('top-level.begin', {
  fullProbeMode,
  readyState: document.readyState,
  hasElectronAPI: Boolean(window.electronAPI)
})

const {
  dropImportOverlay,
  dropImportHint,
  welcomeRestorePrompt,
  welcomeRestoreSummary,
  restoreWorkspaceButton,
  skipWorkspaceRestoreButton,
  openCorpusMenuButton,
  openCorpusMenuPanel,
  quickOpenButton,
  saveImportButton,
  libraryButton,
  recentOpenSection,
  recentOpenList,
  clearRecentOpenButton,
  selectSavedCorporaButton,
  countButton,
  cancelStatsButton,
  checkUpdateButton,
  aboutButton,
  uiSettingsButton,
  taskCenterButton,
  taskCenterPanel,
  taskCenterMeta,
  taskCenterList,
  queueToggleButton,
  retryFailedTaskButton,
  cancelQueuedTaskButton,
  closeTaskCenterButton,
  kwicButton,
  cancelKwicButton,
  kwicInput,
  kwicScopeSelect,
  leftWindowSelect,
  rightWindowSelect,
  fileInfo,
  previewToggleButton,
  previewPanelBody,
  previewBox,
  selectedCorporaWrapper,
  systemStatus,
  systemStatusText,
  workspaceCorpusValue,
  workspaceCorpusNote,
  workspaceModeValue,
  workspaceModeNote,
  workspaceTokenValue,
  workspaceTokenNote,
  workspaceMetricValue,
  workspaceMetricNote,
  statsSummaryWrapper,
  tableWrapper,
  compareSummaryWrapper,
  compareFilterInput,
  compareMeta,
  compareWrapper,
  comparePageSizeSelect,
  comparePrevPageButton,
  compareNextPageButton,
  comparePageInfo,
  compareTotalRowsInfo,
  chiSquareMeta,
  chiSquareResultWrapper,
  chiAInput,
  chiBInput,
  chiCInput,
  chiDInput,
  chiYatesToggle,
  chiSquareRunButton,
  chiSquareResetButton,
  wordCloudWrapper,
  ngramButton,
  ngramSizeSelect,
  ngramMeta,
  ngramWrapper,
  ngramPageSizeSelect,
  ngramPrevPageButton,
  ngramNextPageButton,
  ngramPageInfo,
  ngramTotalRowsInfo,
  exportNgramButton,
  exportAllNgramButton,
  freqFilterInput,
  searchQueryInputs,
  searchOptionInputs,
  pageSizeSelect,
  prevPageButton,
  nextPageButton,
  pageInfo,
  totalRowsInfo,
  kwicMeta,
  kwicWrapper,
  kwicSortSelect,
  kwicPageSizeSelect,
  kwicPrevPageButton,
  kwicNextPageButton,
  kwicPageInfo,
  kwicTotalRowsInfo,
  collocateInput,
  collocateButton,
  cancelCollocateButton,
  collocateLeftWindowSelect,
  collocateRightWindowSelect,
  collocateMinFreqSelect,
  collocateWrapper,
  collocateMeta,
  collocatePageSizeSelect,
  collocatePrevPageButton,
  collocateNextPageButton,
  collocatePageInfo,
  collocateTotalRowsInfo,
  exportCollocateButton,
  exportAllCollocateButton,
  locatorMeta,
  sentenceViewer,
  copyStatsButton,
  copyFreqButton,
  exportAllFreqButton,
  copyCompareButton,
  exportAllCompareButton,
  copyKWICButton,
  exportAllKWICButton,
  copyLocatorButton,
  tabButtons,
  statsSection,
  compareSection,
  chiSquareSection,
  wordCloudSection,
  ngramSection,
  kwicSection,
  collocateSection,
  locatorSection,
  libraryModal,
  libraryMeta,
  libraryFolderList,
  libraryTableWrapper,
  libraryTargetChip,
  createFolderButton,
  importToFolderButton,
  recycleBinButton,
  backupLibraryButton,
  restoreLibraryButton,
  repairLibraryButton,
  loadSelectedCorporaButton,
  closeLibraryButton,
  recycleModal,
  recycleMeta,
  recycleTableWrapper,
  closeRecycleButton,
  helpCenterModal,
  reopenTutorialButton,
  openGitHubRepoButton,
  closeHelpCenterButton,
  uiSettingsModal,
  uiZoomRange,
  uiFontSizeRange,
  uiFontFamilySelect,
  restoreWorkspaceToggle,
  windowAttentionToggle,
  notifyAnalysisCompleteToggle,
  notifyUpdateDownloadedToggle,
  notifyDiagnosticsExportToggle,
  followSystemAccessibilityToggle,
  lightThemeButton,
  darkThemeButton,
  systemThemeButton,
  debugLoggingToggle,
  diagnosticsStatusText,
  resetWindowsCompatButton,
  exportDiagnosticsButton,
  reportIssueButton,
  analysisCacheValue,
  analysisCacheStatusText,
  refreshAnalysisCacheButton,
  rebuildAnalysisCacheButton,
  clearAnalysisCacheButton,
  resetUiSettingsButton,
  closeUiSettingsButton,
  feedbackModal,
  commandPaletteModal,
  commandPaletteInput,
  commandPaletteList,
  closeCommandPaletteButton
} = dom

writeStartupAppLog('dom-refs.ready', {
  fullProbeMode,
  sharedSearchInputCount: Array.isArray(searchQueryInputs) ? searchQueryInputs.length : 0,
  searchOptionInputCount: Array.isArray(searchOptionInputs) ? searchOptionInputs.length : 0,
  hasAppShell: Boolean(document.querySelector('.app-shell'))
})

const {
  beginBusyState,
  nextAnalysisRun,
  isLatestAnalysisRun,
  runAnalysisTask,
  runCancelableTask,
  cancelAnalysisTask,
  cancelAllAnalysisTasks,
  isAnalysisTaskActive,
  isAbortError
} = createAnalysisBridge({
  systemStatus,
  systemStatusText
})
const { cancelTableRender, renderTableInChunks } = createTableRenderer({
  formatCount,
  largeTableThreshold: LARGE_TABLE_THRESHOLD,
  chunkSize: TABLE_RENDER_CHUNK_SIZE
})
const {
  applyTheme,
  applyUISettings,
  applyUISettingsFromControls,
  closeUISettingsModal,
  getCurrentUISettings,
  init: initUISettings,
  openUISettingsModal
} = createUISettingsController({
  dom,
  defaultTheme: DEFAULT_THEME,
  storageKey: UI_SETTINGS_STORAGE_KEY,
  defaultSettings: DEFAULT_UI_SETTINGS,
  fontFamilies: UI_FONT_FAMILIES,
  clampNumber
})
const { showAlert, showConfirm, showPrompt, showToast } = createFeedbackController(dom)
const exportFeedback = { showAlert, showToast, notifySystem }
let currentAppInfo = { ...DEFAULT_APP_INFO }
let appInfoLoaded = false
let appInfoPromise = null

let currentCorpusMode = 'quick'
let currentCorpusId = null
let currentCorpusDisplayName = ''
let currentCorpusFolderId = null
let currentCorpusFolderName = ''
let currentSelectedCorpora = []
let currentLibraryFolderId = localStorage.getItem(LIBRARY_FOLDER_STORAGE_KEY) || 'all'
let currentLibraryFolders = []
let selectedLibraryCorpusIds = new Set()
let currentLibraryVisibleCount = 0
let currentLibraryTotalCount = 0

let currentText = ''
let currentTokens = []
let currentTokenObjects = []
let currentSentenceObjects = []
let currentFreqRows = []
let currentComparisonEntries = []
let currentComparisonRows = []
let currentComparisonCorpora = []
let currentSearchQuery = ''
let currentSearchOptions = normalizeSearchOptions()
let currentPage = 1
let pageSize = 10
let currentComparePage = 1
let currentComparePageSize = 10
let currentNgramRows = []
let currentNgramPage = 1
let currentNgramPageSize = 10
let currentNgramSize = 2

let currentKWICResults = []
let currentKWICPage = 1
let currentKWICPageSize = 10
let currentKWICSortMode = 'original'
let currentKWICKeyword = ''
let currentKWICLeftWindow = 5
let currentKWICRightWindow = 5
let currentKWICScope = 'current'
let currentKWICScopeLabel = '当前语料'
let currentKWICSearchedCorpusCount = 0

let currentCollocateRows = []
let currentCollocatePage = 1
let currentCollocatePageSize = 10
let currentCollocateKeyword = ''
let currentCollocateLeftWindow = 5
let currentCollocateRightWindow = 5
let currentCollocateMinFreq = 1
let currentChiSquareResult = null
let currentChiSquareInputValues = {
  a: '',
  b: '',
  c: '',
  d: '',
  yates: false
}

let currentTokenCount = 0
let currentTypeCount = 0
let currentTTR = 0
let currentSTTR = 0
let currentTab = 'stats'

let activeSentenceId = null
let currentHighlight = null
let currentKWICSortCache = { source: null, mode: 'original', rows: [] }
let locatorNeedsRender = true
let pendingLocatorScrollSentenceId = null
let activeCancelableAnalysis = null
let cancellingAnalysis = null
let isCorpusLoading = false
let pendingTaskAttentionCount = 0
let workspaceSnapshotTimer = null
let workspaceSnapshotReady = false
let workspaceRestoreInProgress = false
let recentOpenEntries = []
let onboardingState = loadOnboardingState(localStorage, ONBOARDING_STORAGE_KEY)
let systemOpenRequestQueue = Promise.resolve()
let startupRestoreHandledByCrashWizard = false
const startupPhaseEvents = []
const REMINDER_CATEGORY_SETTING_KEYS = Object.freeze({
  'analysis-complete': 'notifyAnalysisComplete',
  'update-downloaded': 'notifyUpdateDownloaded',
  'diagnostics-export': 'notifyDiagnosticsExport'
})
const REMINDER_CATEGORY_LABELS = Object.freeze({
  'analysis-complete': '分析完成提醒',
  'update-downloaded': '更新下载完成提醒',
  'diagnostics-export': '诊断导出完成提醒'
})
const AUTO_BUG_FEEDBACK_COOLDOWN_MS = 45 * 1000
const AUTO_BUG_FEEDBACK_MAX_PROMPTS = 3
const ANALYSIS_CACHE_SCHEMA_VERSION = 1
const MAX_ANALYSIS_QUEUE_LENGTH = 12
const LARGE_CORPUS_SEGMENTED_CHAR_THRESHOLD = 1200000
const SEGMENTED_ANALYSIS_CHUNK_CHARS = 180000
const MEMORY_PRESSURE_WARN_RATIO = 0.82
const MEMORY_PRESSURE_WARN_COOLDOWN_MS = 60 * 1000
let autoBugFeedbackPromptCount = 0
let autoBugFeedbackLastPromptAt = 0
let autoBugFeedbackLastSignature = ''
let autoBugFeedbackInFlight = false
let currentAnalysisCacheKey = ''
let currentAnalysisCachePayload = null
let currentAnalysisMode = 'full'
let analysisQueuePaused = false
let analysisQueueRunning = false
let analysisQueueSeq = 0
let analysisQueue = []
let analysisQueueFailedItems = []
let lastMemoryPressureWarningAt = 0
const activeTaskCenterTaskKeys = {
  stats: 'stats',
  kwic: 'kwic',
  collocate: 'collocate'
}
let searchContextCache = {
  query: '',
  optionsKey: '',
  context: null
}
let visibleFrequencyRowsCache = {
  rowsRef: null,
  searchKey: '',
  result: []
}
let visibleCompareRowsCache = {
  rowsRef: null,
  searchKey: '',
  result: []
}

writeStartupAppLog('state.ready', {
  fullProbeMode,
  currentTab,
  currentCorpusMode,
  currentLibraryFolderId,
  onboardingLoaded: Boolean(onboardingState)
})

function invalidateKWICSortCache() {
  currentKWICSortCache = { source: null, mode: 'original', rows: [] }
}

function buildSearchOptionsKey(options = currentSearchOptions) {
  const normalized = normalizeSearchOptions(options)
  return `${normalized.words ? '1' : '0'}${normalized.caseSensitive ? '1' : '0'}${normalized.regex ? '1' : '0'}`
}

function invalidateSearchCaches({ invalidateSearchContext = false } = {}) {
  visibleFrequencyRowsCache = {
    rowsRef: null,
    searchKey: '',
    result: []
  }
  visibleCompareRowsCache = {
    rowsRef: null,
    searchKey: '',
    result: []
  }
  if (invalidateSearchContext) {
    searchContextCache = {
      query: '',
      optionsKey: '',
      context: null
    }
  }
}

function getCurrentSearchContext() {
  const query = String(currentSearchQuery || '')
  const optionsKey = buildSearchOptionsKey(currentSearchOptions)
  if (
    searchContextCache.context &&
    searchContextCache.query === query &&
    searchContextCache.optionsKey === optionsKey
  ) {
    return searchContextCache.context
  }
  const context = buildTokenMatcher(query, currentSearchOptions)
  searchContextCache = {
    query,
    optionsKey,
    context
  }
  return context
}

function computeTextFingerprint(text) {
  const source = String(text || '')
  let hash = 0x811c9dc5
  for (let index = 0; index < source.length; index += 1) {
    const code = source.charCodeAt(index)
    hash ^= code & 0xff
    hash = Math.imul(hash, 0x01000193) >>> 0
    hash ^= (code >>> 8) & 0xff
    hash = Math.imul(hash, 0x01000193) >>> 0
  }
  return hash.toString(16).padStart(8, '0')
}

function buildComparisonSignature(comparisonEntries = currentComparisonEntries) {
  if (!Array.isArray(comparisonEntries) || comparisonEntries.length === 0) return 'none'
  const signatureParts = comparisonEntries.map(entry => {
    const corpusId = String(entry?.corpusId || '').trim()
    const content = String(entry?.content || '')
    const contentLength = Number(entry?.contentLength) || content.length
    const contentFingerprint = String(entry?.contentFingerprint || '').trim()
    const sample = content.length <= 2048
      ? content
      : `${content.slice(0, 1024)}${content.slice(-1024)}`
    return `${corpusId}:${contentLength}:${contentFingerprint || computeTextFingerprint(sample)}`
  })
  return computeTextFingerprint(signatureParts.join('|'))
}

function normalizeComparisonEntries(entries = []) {
  if (!Array.isArray(entries)) return []
  return entries
    .map(entry => {
      const content = String(entry?.content || '')
      return {
        corpusId: String(entry?.corpusId || '').trim(),
        corpusName: String(entry?.corpusName || '').trim(),
        folderId: String(entry?.folderId || '').trim(),
        folderName: String(entry?.folderName || '').trim(),
        sourceType: String(entry?.sourceType || 'txt').trim() || 'txt',
        contentLength: Number(entry?.contentLength) || content.length,
        contentFingerprint: String(entry?.contentFingerprint || '').trim(),
        content
      }
    })
    .filter(entry => entry.corpusId && entry.content.trim())
}

function resolveCorpusText(result, comparisonEntries = []) {
  const directContent = String(result?.content || '')
  if (directContent.trim()) return directContent
  if (!Array.isArray(comparisonEntries) || comparisonEntries.length === 0) return ''
  return comparisonEntries.map(entry => entry.content).filter(Boolean).join('\n\n')
}

function buildAnalysisCacheKey(result = {}, text = '') {
  const mode = String(result?.mode || currentCorpusMode || 'quick').trim() || 'quick'
  const corpusId = String(result?.corpusId || currentCorpusId || '').trim()
  const filePath = String(result?.filePath || '').trim()
  const selectedIds = Array.isArray(result?.selectedItems)
    ? result.selectedItems.map(item => String(item?.id || '').trim()).filter(Boolean).join(',')
    : currentSelectedCorpora.map(item => String(item?.id || '').trim()).filter(Boolean).join(',')
  const comparisonSignature = buildComparisonSignature(
    Array.isArray(result?.comparisonEntries) ? result.comparisonEntries : currentComparisonEntries
  )
  const identity = [mode, corpusId, selectedIds, filePath, comparisonSignature].join('|')
  return `wordz-v1:${computeTextFingerprint(identity)}:${computeTextFingerprint(text)}`
}

function normalizeCachedStats(stats) {
  if (!stats || typeof stats !== 'object') return null
  if (!Array.isArray(stats.freqRows)) return null
  return {
    freqRows: stats.freqRows,
    tokenCount: Number(stats.tokenCount) || 0,
    typeCount: Number(stats.typeCount) || 0,
    ttr: Number(stats.ttr) || 0,
    sttr: Number(stats.sttr) || 0,
    compareSignature: String(stats.compareSignature || ''),
    compareCorpora: Array.isArray(stats.compareCorpora) ? stats.compareCorpora : [],
    compareRows: Array.isArray(stats.compareRows) ? stats.compareRows : []
  }
}

function normalizeAnalysisMode(mode) {
  return String(mode || '').trim().toLowerCase() === 'segmented' ? 'segmented' : 'full'
}

function shouldUseSegmentedAnalysis(text) {
  return String(text || '').length >= LARGE_CORPUS_SEGMENTED_CHAR_THRESHOLD
}

function normalizeAnalysisCachePayload(payload) {
  if (!payload || typeof payload !== 'object') return null
  if (Number(payload.schemaVersion) !== ANALYSIS_CACHE_SCHEMA_VERSION) return null
  const analysisMode = normalizeAnalysisMode(payload.analysisMode)
  const rawCorpusData = payload.corpusData
  if (!rawCorpusData || typeof rawCorpusData !== 'object') return null
  const corpusData = {
    sentences: Array.isArray(rawCorpusData.sentences) ? rawCorpusData.sentences : [],
    tokenObjects: Array.isArray(rawCorpusData.tokenObjects) ? rawCorpusData.tokenObjects : [],
    tokens: Array.isArray(rawCorpusData.tokens) ? rawCorpusData.tokens : []
  }
  if (
    analysisMode === 'full' &&
    (!Array.isArray(rawCorpusData.sentences) || !Array.isArray(rawCorpusData.tokenObjects) || !Array.isArray(rawCorpusData.tokens))
  ) {
    return null
  }
  const normalizedNgrams = {}
  if (payload.ngrams && typeof payload.ngrams === 'object') {
    for (const [rawSize, rows] of Object.entries(payload.ngrams)) {
      if (!Array.isArray(rows)) continue
      const size = Number(rawSize)
      if (!Number.isFinite(size) || size <= 0) continue
      normalizedNgrams[String(size)] = rows
    }
  }
  return {
    schemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
    analysisMode,
    corpusData,
    stats: normalizeCachedStats(payload.stats),
    ngrams: normalizedNgrams
  }
}

async function loadAnalysisCachePayload(cacheKey) {
  const normalizedKey = String(cacheKey || '').trim()
  if (!normalizedKey || !window.electronAPI?.getAnalysisCache) return null
  try {
    const result = await window.electronAPI.getAnalysisCache(normalizedKey)
    if (!result?.success || !result?.hit) return null
    return normalizeAnalysisCachePayload(result.payload)
  } catch (error) {
    console.warn('[analysis-cache.load]', error)
    return null
  }
}

async function persistAnalysisCachePayload(cacheKey = currentAnalysisCacheKey, payload = currentAnalysisCachePayload) {
  const normalizedKey = String(cacheKey || '').trim()
  const normalizedPayload = normalizeAnalysisCachePayload(payload)
  if (!normalizedKey || !normalizedPayload || !window.electronAPI?.setAnalysisCache) return false
  try {
    const result = await window.electronAPI.setAnalysisCache(normalizedKey, normalizedPayload)
    return result?.success === true
  } catch (error) {
    console.warn('[analysis-cache.save]', error)
    return false
  }
}

function updateCurrentAnalysisCache({ stats = null, ngramSize = null, ngramRows = null } = {}) {
  if (!currentAnalysisCachePayload || typeof currentAnalysisCachePayload !== 'object') return

  if (stats && typeof stats === 'object') {
    currentAnalysisCachePayload = {
      ...currentAnalysisCachePayload,
      stats: {
        freqRows: Array.isArray(stats.freqRows) ? stats.freqRows : [],
        tokenCount: Number(stats.tokenCount) || 0,
        typeCount: Number(stats.typeCount) || 0,
        ttr: Number(stats.ttr) || 0,
        sttr: Number(stats.sttr) || 0,
        compareSignature: String(stats.compareSignature || ''),
        compareCorpora: Array.isArray(stats.compareCorpora) ? stats.compareCorpora : [],
        compareRows: Array.isArray(stats.compareRows) ? stats.compareRows : []
      }
    }
  }

  if (Number.isFinite(Number(ngramSize)) && Array.isArray(ngramRows)) {
    currentAnalysisCachePayload = {
      ...currentAnalysisCachePayload,
      ngrams: {
        ...(currentAnalysisCachePayload.ngrams || {}),
        [String(Number(ngramSize))]: ngramRows
      }
    }
  }
}

function formatBytes(value) {
  const bytes = Math.max(0, Number(value) || 0)
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

function readMemorySnapshot() {
  const memory = globalThis?.performance?.memory
  if (!memory) return null
  const used = Number(memory.usedJSHeapSize) || 0
  const total = Number(memory.totalJSHeapSize) || 0
  const limit = Number(memory.jsHeapSizeLimit) || 0
  if (!used || !limit) return null
  return {
    used,
    total,
    limit,
    usedRatio: used / limit
  }
}

function maybeWarnMemoryPressure(source = '') {
  const memorySnapshot = readMemorySnapshot()
  if (!memorySnapshot) return
  if (memorySnapshot.usedRatio < MEMORY_PRESSURE_WARN_RATIO) return
  const now = Date.now()
  if (now - lastMemoryPressureWarningAt < MEMORY_PRESSURE_WARN_COOLDOWN_MS) return
  lastMemoryPressureWarningAt = now

  const ratioLabel = `${Math.round(memorySnapshot.usedRatio * 100)}%`
  const message = `当前内存占用较高（${ratioLabel}，约 ${formatBytes(memorySnapshot.used)} / ${formatBytes(memorySnapshot.limit)}）。建议先完成导出并切换更小语料。`
  showToast(message, {
    title: '内存保护提醒',
    duration: 3200
  })
  void recordDiagnostic('warn', 'analysis.memory-pressure', message, {
    source,
    usedBytes: memorySnapshot.used,
    limitBytes: memorySnapshot.limit,
    usedRatio: memorySnapshot.usedRatio
  })
}

function buildAnalysisCachePayloadFromCurrentState() {
  const existingNgrams =
    currentAnalysisCachePayload && typeof currentAnalysisCachePayload === 'object' && currentAnalysisCachePayload.ngrams
      ? currentAnalysisCachePayload.ngrams
      : {}
  const hasStats = currentFreqRows.length > 0 || currentTokenCount > 0
  return normalizeAnalysisCachePayload({
    schemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
    analysisMode: currentAnalysisMode,
    corpusData:
      currentAnalysisMode === 'segmented'
        ? { sentences: [], tokenObjects: [], tokens: [] }
        : {
            sentences: Array.isArray(currentSentenceObjects) ? currentSentenceObjects : [],
            tokenObjects: Array.isArray(currentTokenObjects) ? currentTokenObjects : [],
            tokens: Array.isArray(currentTokens) ? currentTokens : []
          },
    stats: hasStats
      ? {
          freqRows: currentFreqRows,
          tokenCount: currentTokenCount,
          typeCount: currentTypeCount,
          ttr: currentTTR,
          sttr: currentSTTR,
          compareSignature: buildComparisonSignature(currentComparisonEntries),
          compareCorpora: currentComparisonCorpora,
          compareRows: currentComparisonRows
        }
      : null,
    ngrams: existingNgrams
  })
}

async function refreshAnalysisCacheState({ silent = false } = {}) {
  if (!analysisCacheValue || !analysisCacheStatusText) return null
  if (!window.electronAPI?.getAnalysisCacheState) {
    analysisCacheValue.textContent = '不可用'
    analysisCacheStatusText.textContent = '当前版本未启用分析缓存状态接口。'
    if (refreshAnalysisCacheButton) refreshAnalysisCacheButton.disabled = true
    if (clearAnalysisCacheButton) clearAnalysisCacheButton.disabled = true
    if (rebuildAnalysisCacheButton) rebuildAnalysisCacheButton.disabled = true
    return null
  }

  try {
    const state = await window.electronAPI.getAnalysisCacheState()
    if (!state?.success) {
      analysisCacheValue.textContent = '读取失败'
      analysisCacheStatusText.textContent = state?.message || '分析缓存状态读取失败。'
      return null
    }
    const entryCount = Number(state.entryCount) || 0
    analysisCacheValue.textContent = `${formatCount(entryCount)} 条`
    analysisCacheStatusText.textContent = `目录：${state.cacheDir || '未知'} ｜ 总占用：${formatBytes(state.totalBytes)} ｜ 上限：${formatBytes(state.maxTotalBytes)}`
    if (clearAnalysisCacheButton) clearAnalysisCacheButton.disabled = entryCount === 0
    if (rebuildAnalysisCacheButton) rebuildAnalysisCacheButton.disabled = !currentAnalysisCacheKey
    return state
  } catch (error) {
    console.warn('[analysis-cache.state]', error)
    analysisCacheValue.textContent = '读取失败'
    analysisCacheStatusText.textContent = error?.message || '分析缓存状态读取失败。'
    if (!silent) {
      showToast('分析缓存状态读取失败。', {
        title: '缓存管理'
      })
    }
    return null
  }
}

async function rebuildCurrentAnalysisCache({ silent = false } = {}) {
  const cacheKey = String(currentAnalysisCacheKey || '').trim()
  if (!cacheKey) {
    if (!silent) {
      showToast('当前没有可重建缓存的语料。', {
        title: '缓存管理'
      })
    }
    return false
  }

  const nextPayload = buildAnalysisCachePayloadFromCurrentState()
  if (!nextPayload) {
    if (!silent) {
      showToast('当前缓存快照无效，无法重建。', {
        title: '缓存管理'
      })
    }
    return false
  }

  currentAnalysisCachePayload = nextPayload
  const saved = await persistAnalysisCachePayload(cacheKey, nextPayload)
  if (!saved) {
    if (!silent) {
      showToast('重建分析缓存失败。', {
        title: '缓存管理'
      })
    }
    return false
  }

  if (window.electronAPI?.pruneAnalysisCache) {
    try {
      await window.electronAPI.pruneAnalysisCache()
    } catch {
      // ignore prune failures
    }
  }

  await refreshAnalysisCacheState({ silent: true })
  if (!silent) {
    showToast('已重建当前语料缓存。', {
      title: '缓存管理',
      type: 'success'
    })
  }
  return true
}

function getVisibleFrequencyRows() {
  const { matcher, normalizedQuery, options, error } = getCurrentSearchContext()
  if (error) return []
  const searchKey = `${normalizedQuery}|${buildSearchOptionsKey(options)}`
  if (visibleFrequencyRowsCache.rowsRef === currentFreqRows && visibleFrequencyRowsCache.searchKey === searchKey) {
    return visibleFrequencyRowsCache.result
  }
  const rows = !normalizedQuery
    ? currentFreqRows
    : currentFreqRows.filter(([word]) => matcher(String(word || '')))
  visibleFrequencyRowsCache = {
    rowsRef: currentFreqRows,
    searchKey,
    result: rows
  }
  return rows
}

function getVisibleCompareRows() {
  const { matcher, normalizedQuery, options, error } = getCurrentSearchContext()
  if (error) return []
  const searchKey = `${normalizedQuery}|${buildSearchOptionsKey(options)}`
  if (visibleCompareRowsCache.rowsRef === currentComparisonRows && visibleCompareRowsCache.searchKey === searchKey) {
    return visibleCompareRowsCache.result
  }
  const rows = !normalizedQuery
    ? currentComparisonRows
    : currentComparisonRows.filter(row => matcher(String(row?.word || '')))
  visibleCompareRowsCache = {
    rowsRef: currentComparisonRows,
    searchKey,
    result: rows
  }
  return rows
}

function getTabLabel(tabName) {
  if (tabName === 'compare') return '对比分析'
  if (tabName === 'chi-square') return '卡方检验'
  if (tabName === 'word-cloud') return '词云'
  if (tabName === 'ngram') return 'Ngram'
  if (tabName === 'kwic') return 'KWIC 检索'
  if (tabName === 'collocate') return 'Collocate 统计'
  if (tabName === 'locator') return '原文定位'
  return '统计结果'
}

function persistRecentOpenEntries() {
  persistRecentOpenEntriesToStorage(localStorage, RECENT_OPEN_STORAGE_KEY, recentOpenEntries)
}

function renderRecentOpenList() {
  renderRecentOpenListView(
    {
      section: recentOpenSection,
      list: recentOpenList,
      clearButton: clearRecentOpenButton
    },
    recentOpenEntries
  )
}

function addRecentOpenEntry(entry) {
  const normalizedEntry = normalizeRecentOpenEntry(entry)
  if (!normalizedEntry) return
  recentOpenEntries = [
    normalizedEntry,
    ...recentOpenEntries.filter(item => item.key !== normalizedEntry.key)
  ].slice(0, RECENT_OPEN_LIMIT)
  persistRecentOpenEntries()
  renderRecentOpenList()
}

function clearRecentOpenEntries() {
  recentOpenEntries = []
  persistRecentOpenEntries()
  renderRecentOpenList()
}

async function notifySystem({ title, body, subtitle = '', tag = '', silent = false, category = '', action = null } = {}) {
  const normalizedCategory = String(category || '').trim()
  if (getCurrentUISettings().systemNotifications === false) {
    return {
      success: false,
      skipped: true
    }
  }

  if (!isReminderCategoryEnabled(normalizedCategory)) {
    return {
      success: false,
      skipped: true
    }
  }

  if (!window.electronAPI?.showSystemNotification) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await window.electronAPI.showSystemNotification({
      title,
      body,
      subtitle,
      tag,
      silent,
      action
    })
  } catch (error) {
    console.warn('[system-notification]', error)
    return {
      success: false,
      message: error?.message || '系统通知发送失败'
    }
  }
}

async function setWindowProgressState({ source, state, progress = 0, priority = 0 } = {}) {
  if (!window.electronAPI?.setWindowProgressState) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await window.electronAPI.setWindowProgressState({
      source,
      state,
      progress,
      priority
    })
  } catch (error) {
    console.warn('[window-progress]', error)
    return {
      success: false,
      message: error?.message || '窗口进度条更新失败'
    }
  }
}

async function setWindowAttentionState({ source, state, count = 0, description = '', priority = 0, requestAttention = false, category = '' } = {}) {
  const normalizedState = String(state || '').trim().toLowerCase()
  const normalizedCategory = String(category || '').trim()
  if (normalizedState !== 'none' && getCurrentUISettings().windowAttention === false) {
    return {
      success: false,
      skipped: true
    }
  }

  if (normalizedState !== 'none' && !isReminderCategoryEnabled(normalizedCategory)) {
    return {
      success: false,
      skipped: true
    }
  }

  if (!window.electronAPI?.setWindowAttentionState) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await window.electronAPI.setWindowAttentionState({
      source,
      state,
      count,
      description,
      priority,
      requestAttention
    })
  } catch (error) {
    console.warn('[window-attention]', error)
    return {
      success: false,
      message: error?.message || '窗口提醒状态更新失败'
    }
  }
}

function clearTaskCenterAttention() {
  pendingTaskAttentionCount = 0
  void setWindowAttentionState({
    source: 'task-center',
    state: 'none'
  })
}

function isReminderCategoryEnabled(category) {
  const categoryKey = REMINDER_CATEGORY_SETTING_KEYS[category]
  if (!categoryKey) return true
  return getCurrentUISettings()[categoryKey] !== false
}

function applyReminderCategoryChange(category, checked) {
  const categoryLabel = REMINDER_CATEGORY_LABELS[category] || category
  if (!checked) {
    if (category === 'analysis-complete') {
      clearTaskCenterAttention()
    }
    if (category === 'update-downloaded') {
      void setWindowAttentionState({
        source: 'auto-update',
        state: 'none'
      })
    }
  }
  void recordDiagnostic(
    'info',
    'reminder.category',
    checked ? `用户已开启${categoryLabel}。` : `用户已关闭${categoryLabel}。`
  )
}

function clearAllWindowAttention() {
  clearTaskCenterAttention()
  void setWindowAttentionState({
    source: 'auto-update',
    state: 'none'
  })
}

function pushTaskCenterAttention(title, detail, category = 'analysis-complete') {
  if (!isReminderCategoryEnabled(category)) return
  const shouldTrackUnread = !(taskCenter.isOpen() && !document.hidden && document.hasFocus())
  if (!shouldTrackUnread) return
  pendingTaskAttentionCount = Math.min(99, pendingTaskAttentionCount + 1)
  void setWindowAttentionState({
    source: 'task-center',
    count: pendingTaskAttentionCount,
    description: `${title}：${detail}`.slice(0, 120),
    priority: 45,
    requestAttention: document.hidden || !document.hasFocus(),
    category
  })
}

function finishTaskEntryWithAttention(taskKey, title, status, detail, category = 'analysis-complete') {
  taskCenter.finishEntry(taskKey, status, detail)
  updateAnalysisQueueControls()
  if (status === 'success' || status === 'failed' || status === 'cancelled') {
    pushTaskCenterAttention(title, detail, category)
  }
}

function renderSelectedCorporaTable() {
  if (!selectedCorporaWrapper) return
  selectedCorporaWrapper.innerHTML = buildSelectedCorporaTable(currentSelectedCorpora, escapeHtml)
}

function syncLibrarySelectionWithCurrentCorpora() {
  selectedLibraryCorpusIds = new Set(currentSelectedCorpora.map(item => item.id).filter(Boolean))
}

function updateLoadSelectedCorporaButton() {
  if (!loadSelectedCorporaButton) return
  const selectedCount = selectedLibraryCorpusIds.size
  loadSelectedCorporaButton.disabled = selectedCount === 0
  setButtonLabel(loadSelectedCorporaButton, selectedCount > 0 ? `载入选中语料（${selectedCount}）` : '载入选中语料')
}

function syncSharedSearchInputs() {
  for (const input of searchQueryInputs || []) {
    if (input && input.value !== currentSearchQuery) {
      input.value = currentSearchQuery
    }
  }
}

function syncSearchOptionInputs() {
  for (const input of searchOptionInputs || []) {
    if (!(input instanceof HTMLInputElement)) continue
    const optionName = input.dataset.searchOption || ''
    const checked =
      optionName === 'words'
        ? currentSearchOptions.words
        : optionName === 'case'
          ? currentSearchOptions.caseSensitive
          : currentSearchOptions.regex
    input.checked = Boolean(checked)
  }
}

function getSearchOptionsSummary() {
  const enabled = []
  if (currentSearchOptions.words) enabled.push('Words')
  if (currentSearchOptions.caseSensitive) enabled.push('Case')
  if (currentSearchOptions.regex) enabled.push('Regex')
  return enabled.length > 0 ? enabled.join(' / ') : '默认匹配'
}

function syncChiSquareInputsFromState() {
  if (chiAInput) chiAInput.value = currentChiSquareInputValues.a
  if (chiBInput) chiBInput.value = currentChiSquareInputValues.b
  if (chiCInput) chiCInput.value = currentChiSquareInputValues.c
  if (chiDInput) chiDInput.value = currentChiSquareInputValues.d
  if (chiYatesToggle) chiYatesToggle.checked = currentChiSquareInputValues.yates === true
}

function captureChiSquareInputsFromControls() {
  currentChiSquareInputValues = {
    a: String(chiAInput?.value || '').trim(),
    b: String(chiBInput?.value || '').trim(),
    c: String(chiCInput?.value || '').trim(),
    d: String(chiDInput?.value || '').trim(),
    yates: chiYatesToggle?.checked === true
  }
}

function getChiSquareInputNumber(control, label) {
  const rawValue = String(control?.value || '').trim()
  if (!rawValue) {
    throw new Error(`${label} 不能为空`)
  }
  const value = Number(rawValue)
  if (!Number.isFinite(value) || value < 0 || !Number.isInteger(value)) {
    throw new Error(`${label} 必须是大于等于 0 的整数`)
  }
  return value
}

function readChiSquareInputNumbers() {
  return {
    a: getChiSquareInputNumber(chiAInput, 'A（语料 A 目标词）'),
    b: getChiSquareInputNumber(chiBInput, 'B（语料 A 非目标词）'),
    c: getChiSquareInputNumber(chiCInput, 'C（语料 B 目标词）'),
    d: getChiSquareInputNumber(chiDInput, 'D（语料 B 非目标词）'),
    yates: chiYatesToggle?.checked === true
  }
}

function getChiSquareState() {
  return {
    currentChiSquareResult
  }
}

function renderChiSquareResult() {
  renderChiSquareResultSection(getChiSquareState(), dom, {
    escapeHtml,
    formatCount
  })
}

function renderWordCloud() {
  renderWordCloudSection(getStatsState(), dom, {
    escapeHtml,
    formatCount
  })
}

function renderCompareSection() {
  const result = renderCompareSectionData(getCompareState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    renderTableInChunks
  })
  currentComparePage = result.currentComparePage
}

function rerenderSearchDrivenViews() {
  if (currentFreqRows.length === 0 && currentComparisonRows.length === 0) {
    renderCompareSection()
    renderWordCloud()
    return
  }
  pageSize = resolvePageSize(pageSizeSelect.value, getVisibleFrequencyRows().length)
  currentPage = 1
  currentComparePageSize = resolvePageSize(comparePageSizeSelect?.value || '10', getVisibleCompareRows().length)
  currentComparePage = 1
  renderFrequencyTable()
  renderCompareSection()
  renderWordCloud()
}

function setSharedSearchQuery(value, { rerender = true } = {}) {
  currentSearchQuery = String(value || '')
  invalidateSearchCaches({ invalidateSearchContext: true })
  syncSharedSearchInputs()
  scheduleWorkspaceSnapshotSave()
  if (rerender) {
    rerenderSearchDrivenViews()
  }
}

function setSharedSearchOption(optionName, checked, { rerender = true } = {}) {
  const nextOptions = { ...currentSearchOptions }
  if (optionName === 'words') nextOptions.words = Boolean(checked)
  else if (optionName === 'case') nextOptions.caseSensitive = Boolean(checked)
  else if (optionName === 'regex') nextOptions.regex = Boolean(checked)
  currentSearchOptions = normalizeSearchOptions(nextOptions)
  invalidateSearchCaches({ invalidateSearchContext: true })
  syncSearchOptionInputs()
  scheduleWorkspaceSnapshotSave()
  if (rerender) {
    rerenderSearchDrivenViews()
  }
}

function updateLibraryMetaText() {
  if (!libraryMeta) return
  if (currentLibraryFolderId === 'all') {
    libraryMeta.textContent = `共 ${currentLibraryTotalCount || 0} 条本地语料，已整理到 ${currentLibraryFolders.length} 个文件夹中。已选 ${selectedLibraryCorpusIds.size} 条。`
    return
  }

  const folder = getFolderByIdFromList(currentLibraryFolders, currentLibraryFolderId)
  libraryMeta.textContent = `文件夹「${folder ? folder.name : '未分类'}」中共 ${currentLibraryVisibleCount || 0} 条语料。已选 ${selectedLibraryCorpusIds.size} 条。`
}

function syncCurrentWorkspaceSelectionState() {
  if (currentCorpusMode === 'saved-multi') {
    if (currentSelectedCorpora.length === 0) {
      demoteCurrentSavedCorpusToQuick()
      return false
    }
    const uniqueFolderIds = [...new Set(currentSelectedCorpora.map(item => item.folderId).filter(Boolean))]
    const uniqueFolderNames = [...new Set(currentSelectedCorpora.map(item => item.folderName || '未分类'))]
    currentCorpusId = null
    currentCorpusDisplayName = `已选 ${currentSelectedCorpora.length} 条语料`
    currentCorpusFolderId = uniqueFolderIds.length === 1 ? uniqueFolderIds[0] : ''
    currentCorpusFolderName = uniqueFolderNames.length === 1 ? uniqueFolderNames[0] : '多个分类'
  } else if (currentCorpusMode === 'saved') {
    if (currentSelectedCorpora.length === 0) {
      demoteCurrentSavedCorpusToQuick()
      return false
    }
    const [currentItem] = currentSelectedCorpora
    if (currentItem) {
      currentCorpusId = currentItem.id || currentCorpusId
      currentCorpusDisplayName = currentItem.name || currentCorpusDisplayName
      currentCorpusFolderId = currentItem.folderId || currentCorpusFolderId
      currentCorpusFolderName = currentItem.folderName || currentCorpusFolderName
    }
  }

  syncComparisonMetadataFromSelection()
  syncLibrarySelectionWithCurrentCorpora()
  updateLoadSelectedCorporaButton()
  updateLibraryMetaText()
  updateCurrentCorpusInfo()
  renderCompareSection()
  scheduleWorkspaceSnapshotSave()
  return true
}

function syncComparisonMetadataFromSelection() {
  if (currentComparisonEntries.length === 0 && currentComparisonCorpora.length === 0) return

  const currentSelectedById = new Map(currentSelectedCorpora.map(item => [item.id, item]))
  if (currentCorpusMode !== 'saved-multi' || currentSelectedById.size === 0) {
    currentComparisonEntries = []
    currentComparisonCorpora = []
    currentComparisonRows = []
    currentComparePage = 1
    invalidateSearchCaches()
    return
  }

  const previousComparisonEntryCount = currentComparisonEntries.length
  currentComparisonEntries = currentComparisonEntries
    .filter(entry => currentSelectedById.has(entry.corpusId))
    .map(entry => {
      const selectedItem = currentSelectedById.get(entry.corpusId)
      if (!selectedItem) return entry
      return {
        ...entry,
        corpusName: selectedItem.name || entry.corpusName,
        folderId: selectedItem.folderId || entry.folderId,
        folderName: selectedItem.folderName || entry.folderName,
        sourceType: selectedItem.sourceType || entry.sourceType
      }
    })

  if (currentComparisonEntries.length !== previousComparisonEntryCount) {
    currentComparisonCorpora = []
    currentComparisonRows = []
    currentComparePage = 1
    invalidateSearchCaches()
    return
  }

  currentComparisonCorpora = currentComparisonCorpora
    .filter(entry => currentSelectedById.has(entry.corpusId))
    .map(entry => {
      const selectedItem = currentSelectedById.get(entry.corpusId)
      if (!selectedItem) return entry
      return {
        ...entry,
        corpusName: selectedItem.name || entry.corpusName,
        folderId: selectedItem.folderId || entry.folderId,
        folderName: selectedItem.folderName || entry.folderName,
        sourceType: selectedItem.sourceType || entry.sourceType
      }
    })

  currentComparisonRows = currentComparisonRows.map(row => ({
    ...row,
    dominantCorpusName: currentSelectedById.get(row.dominantCorpusId)?.name || row.dominantCorpusName,
    perCorpus: Array.isArray(row.perCorpus)
      ? row.perCorpus
          .filter(entry => currentSelectedById.has(entry.corpusId))
          .map(entry => {
            const selectedItem = currentSelectedById.get(entry.corpusId)
            if (!selectedItem) return entry
            return {
              ...entry,
              corpusName: selectedItem.name || entry.corpusName,
              folderName: selectedItem.folderName || entry.folderName
            }
          })
      : []
  }))
  invalidateSearchCaches()
}

function patchCurrentSelectedCorpora(predicate, patch) {
  let hasChanged = false
  currentSelectedCorpora = currentSelectedCorpora.map(item => {
    if (!predicate(item)) return item
    hasChanged = true
    return { ...item, ...patch(item) }
  })
  if (hasChanged) syncCurrentWorkspaceSelectionState()
  return hasChanged
}

function removeCurrentSelectedCorpora(predicate) {
  const nextItems = currentSelectedCorpora.filter(item => !predicate(item))
  if (nextItems.length === currentSelectedCorpora.length) return false
  currentSelectedCorpora = nextItems
  syncCurrentWorkspaceSelectionState()
  return true
}

function getErrorMessage(error, fallbackMessage) {
  return error && error.message ? error.message : fallbackMessage
}

function setPreviewCollapsed(collapsed) {
  if (!previewPanelBody || !previewToggleButton) return
  previewPanelBody.classList.toggle('hidden', collapsed)
  previewToggleButton.setAttribute('aria-expanded', String(!collapsed))
  previewToggleButton.textContent = collapsed ? '展开预览' : '收起预览'
  scheduleWorkspaceSnapshotSave()
}

async function revealNativeToolbarOverflowForSmoke() {
  const overflowNode = document.querySelector('.toolbar-native-overflow')
  if (!overflowNode || !window.electronAPI?.getSmokeObserverState) return
  try {
    const result = await window.electronAPI.getSmokeObserverState()
    if (!result?.success) return
    overflowNode.classList.remove('hidden')
    overflowNode.setAttribute('aria-hidden', 'false')
  } catch {
    // ignore smoke probe failures
  }
}

function setButtonLabel(button, label) {
  if (!button) return
  const labelNode = button.querySelector('.button-content span:last-child')
  if (labelNode) labelNode.textContent = label
  else button.textContent = label
}

const taskCenter = createTaskCenterController({ dom, setButtonLabel })
const welcomeUpdate = createWelcomeUpdateController({
  dom,
  electronAPI: window.electronAPI,
  getCurrentUISettings,
  getCurrentAppInfo: () => currentAppInfo,
  getWorkspaceSnapshotSummary,
  getTabLabel,
  hasMeaningfulWorkspaceSnapshot,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  setWindowAttentionState,
  setButtonLabel
})
const {
  applyAutoUpdateButtonState,
  getCurrentAutoUpdateState,
  hasPendingWorkspaceRestoreSnapshot,
  hideWelcomeOverlay,
  initializeAutoUpdate,
  isWelcomeOverlayVisible,
  isWelcomeReady,
  isWelcomeTutorialVisible,
  markWelcomeReady,
  promptInstallDownloadedUpdate,
  requestWorkspaceRestoreDecision,
  resolveStartupRestoreDecision,
  setWelcomeProgress,
  showWelcomeOverlay,
  syncWelcomePreferenceCheckboxes
} = welcomeUpdate
const openCommand = createOpenCommandController({
  dom,
  taskCenter,
  getRecentOpenEntries: () => recentOpenEntries,
  renderRecentOpenList,
  openRecentOpenEntry,
  clearRecentOpenEntries,
  showToast,
  showAlert,
  getErrorMessage,
  escapeHtml,
  getCommandPaletteCommands: () => getCommandPaletteCommands(),
  onQuickOpen: async () => {
    if (!window.electronAPI?.openQuickCorpus) {
      await showMissingBridge('openQuickCorpus')
      return
    }

    const result = await window.electronAPI.openQuickCorpus()
    await loadCorpusResult(result)
  },
  onImportAndSave: async () => {
    if (!window.electronAPI?.importAndSaveCorpus) {
      await showMissingBridge('importAndSaveCorpus')
      return
    }

    const result = await window.electronAPI.importAndSaveCorpus(getImportTargetFolder().id)
    await loadCorpusResult(result)
    if (!libraryModal.classList.contains('hidden')) {
      await refreshLibraryModal(currentLibraryFolderId)
    }
  },
  onOpenLibrary: async () => {
    await openLibraryModal()
  },
  onOpenHelpCenter: async () => {
    await ensureAppInfoLoaded()
    openHelpCenterModal()
  },
  onRunStats: async () => enqueueOrRunAnalysisTask({
    type: 'stats',
    title: '统计结果',
    detail: '正在统计词频与词汇指标...',
    run: ({ taskCenterTaskKey }) => executeStatsAnalysis({ taskCenterTaskKey })
  }),
  onCheckUpdate: () => {
    checkUpdateButton?.click()
  },
  onOpenSettings: () => {
    openUISettingsModal()
    void refreshDiagnosticsStatusText()
    void refreshAnalysisCacheState({ silent: true })
  },
  clearTaskCenterAttention,
  closeHelpCenterModal,
  closeRecycleModal,
  hideWelcomeOverlay,
  isWelcomeOverlayVisible,
  handleDroppedPaths: handleDropImportPaths,
  onDropImportError: error => {
    console.error('[drop-import]', error)
    recordDiagnosticError('drop-import', error)
  }
})
const {
  bindDropImportHandlers,
  bindShellInteractionHandlers,
  closeCommandPalette,
  dismissFloatingOverlaysForPrimaryAction,
  handleAppMenuAction,
  openCommandPalette,
  runImportAndSaveAction,
  runOpenHelpCenterAction,
  runOpenLibraryAction,
  runQuickOpenAction,
  setOpenCorpusMenuOpen
} = openCommand
let packagedSmokeAutorunPromise = null

async function getPackagedSmokeConfig() {
  if (!window.electronAPI?.getPackagedSmokeConfig) return null
  try {
    const result = await window.electronAPI.getPackagedSmokeConfig()
    return result?.success ? result.config || null : null
  } catch {
    return null
  }
}

async function reportPackagedSmokeResult(payload = {}) {
  if (!window.electronAPI?.reportPackagedSmokeResult) return null
  try {
    return await window.electronAPI.reportPackagedSmokeResult(payload)
  } catch {
    return null
  }
}

async function maybeRunPackagedSmokeAutorun() {
  if (packagedSmokeAutorunPromise) return packagedSmokeAutorunPromise

  packagedSmokeAutorunPromise = (async () => {
    const config = await getPackagedSmokeConfig()
    if (!config?.enabled || !config?.autoRun) return

    try {
      hideWelcomeOverlay({ immediate: true })
      setOpenCorpusMenuOpen(false)
      closeHelpCenterModal()
      closeLibraryModal()
      closeRecycleModal()
      closeCommandPalette()
      if (taskCenter.isOpen()) taskCenter.setOpen(false)

      setSharedSearchOption('words', true, { rerender: false })
      setSharedSearchOption('case', false, { rerender: false })
      setSharedSearchOption('regex', false, { rerender: false })
      setSharedSearchQuery('', { rerender: false })

      await runQuickOpenAction()

      const corpusName = String(currentCorpusDisplayName || '').trim()
      if (!corpusName) {
        throw new Error('packaged smoke 未能载入语料。')
      }

      const statsStatus = await executeStatsAnalysis({
        taskCenterTaskKey: 'packaged-smoke-stats'
      })
      if (statsStatus !== 'success' || currentFreqRows.length === 0) {
        throw new Error(`packaged smoke 统计阶段失败：${statsStatus || 'unknown'}`)
      }

      setSharedSearchQuery('rose')
      const kwicStatus = await executeKWICAnalysis({
        taskCenterTaskKey: 'packaged-smoke-kwic'
      })
      if (kwicStatus !== 'success' || currentKWICResults.length === 0) {
        throw new Error(`packaged smoke KWIC 阶段失败：${kwicStatus || 'unknown'}`)
      }

      await reportPackagedSmokeResult({
        status: 'passed',
        stage: 'complete',
        message: 'Packaged smoke completed successfully.',
        corpusName,
        statsRowCount: currentFreqRows.length,
        kwicResultCount: currentKWICResults.length,
        runtime: {
          analysisMode: currentAnalysisMode,
          searchQuery: currentSearchQuery
        }
      })
      void recordDiagnostic('info', 'smoke.packaged', 'Packaged smoke 自检已完成。', {
        corpusName,
        statsRowCount: currentFreqRows.length,
        kwicResultCount: currentKWICResults.length
      })
    } catch (error) {
      const message = getErrorMessage(error, 'Packaged smoke 自检失败')
      await reportPackagedSmokeResult({
        status: 'failed',
        stage: 'autorun',
        message,
        corpusName: String(currentCorpusDisplayName || '').trim(),
        statsRowCount: currentFreqRows.length,
        kwicResultCount: currentKWICResults.length,
        runtime: {
          analysisMode: currentAnalysisMode,
          searchQuery: currentSearchQuery
        }
      })
      throw error
    }
  })()

  return packagedSmokeAutorunPromise
}

function updateAnalysisActionButtons() {
  const disablePrimaryActions = isCorpusLoading || Boolean(activeCancelableAnalysis)
  const segmentedSearchDisabled = currentAnalysisMode === 'segmented'
  countButton.disabled = disablePrimaryActions
  if (ngramButton) ngramButton.disabled = disablePrimaryActions
  kwicButton.disabled = disablePrimaryActions || segmentedSearchDisabled
  collocateButton.disabled = disablePrimaryActions || segmentedSearchDisabled
  if (kwicButton) {
    kwicButton.title = segmentedSearchDisabled
      ? '分段分析模式下为保证稳定性，KWIC 暂不可用'
      : ''
  }
  if (collocateButton) {
    collocateButton.title = segmentedSearchDisabled
      ? '分段分析模式下为保证稳定性，Collocate 暂不可用'
      : ''
  }

  const cancelButtonStates = [
    { name: 'stats', button: cancelStatsButton, defaultLabel: '取消统计' },
    { name: 'kwic', button: cancelKwicButton, defaultLabel: '取消 KWIC' },
    { name: 'collocate', button: cancelCollocateButton, defaultLabel: '取消 Collocate' }
  ]

  for (const { name, button, defaultLabel } of cancelButtonStates) {
    if (!button) continue
    const isActive = activeCancelableAnalysis === name
    button.classList.toggle('hidden', !isActive)
    button.disabled = !isActive || cancellingAnalysis === name
    setButtonLabel(button, cancellingAnalysis === name ? '正在取消...' : defaultLabel)
  }
}

function beginCancelableAnalysis(taskName) {
  activeCancelableAnalysis = taskName
  cancellingAnalysis = null
  updateAnalysisActionButtons()
}

function endCancelableAnalysis(taskName) {
  if (!taskName || activeCancelableAnalysis === taskName) {
    activeCancelableAnalysis = null
    cancellingAnalysis = null
    updateAnalysisActionButtons()
    if (!analysisQueuePaused && analysisQueue.length > 0) {
      void runAnalysisQueueIfNeeded()
    }
  }
}

function requestCancelAnalysis(taskName, busyMessage, cancelMessage) {
  if (!isAnalysisTaskActive(taskName)) return false
  cancellingAnalysis = taskName
  updateAnalysisActionButtons()
  if (systemStatusText) systemStatusText.textContent = busyMessage
  const taskCenterTaskKey = activeTaskCenterTaskKeys[taskName] || taskName
  taskCenter.updateActiveEntry(taskCenterTaskKey, { detail: busyMessage })
  return cancelAnalysisTask(taskName, cancelMessage)
}

async function showMissingBridge(apiName) {
  void recordDiagnostic('warn', 'bridge.missing', '检测到缺失的 preload 接口。', { apiName })
  await showAlert({
    title: '功能暂不可用',
    message: `当前 preload.js 还没有接好 ${apiName}`
  })
}

function validateRequiredName(_rawValue, normalizedValue, label) {
  if (!normalizedValue) return `${label}不能为空`
  if (normalizedValue.length > 120) return `${label}不能超过 120 个字符`
  return ''
}

function buildBackupSummaryMessage(result) {
  return [
    `已创建语料库备份。`,
    `备份位置：${result.backupDir || '未知位置'}`,
    `文件夹数量：${formatCount(result.folderCount || 0)}`,
    `语料数量：${formatCount(result.corpusCount || 0)}`
  ].join('\n')
}

function buildRestoreSummaryMessage(result) {
  return [
    '语料库已从备份恢复。',
    `备份来源：${result.restoredFromDir || '未知位置'}`,
    `恢复后的文件夹数量：${formatCount(result.folderCount || 0)}`,
    `恢复后的语料数量：${formatCount(result.corpusCount || 0)}`,
    `恢复前快照位置：${result.previousLibraryBackupDir || '未生成'}`
  ].join('\n')
}

function buildRepairSummaryMessage(result) {
  const summary = result.summary || {}
  const lines = [
    `检查文件夹：${formatCount(summary.checkedFolders || 0)}`,
    `检查语料：${formatCount(summary.checkedCorpora || 0)}`,
    `修复文件夹：${formatCount(summary.repairedFolders || 0)}`,
    `修复语料：${formatCount(summary.repairedCorpora || 0)}`,
    `补回缺失元数据：${formatCount(summary.recoveredCorpusMeta || 0)}`,
    `隔离异常文件夹：${formatCount(summary.quarantinedFolders || 0)}`,
    `隔离异常语料：${formatCount(summary.quarantinedCorpora || 0)}`
  ]

  if (summary.repairedManifest) {
    lines.push('已重写语料库清单。')
  }

  if (result.quarantineDir) {
    lines.push(`异常项已移动到：${result.quarantineDir}`)
  }

  if (
    !summary.repairedManifest &&
    !(summary.repairedFolders || 0) &&
    !(summary.repairedCorpora || 0) &&
    !(summary.quarantinedFolders || 0) &&
    !(summary.quarantinedCorpora || 0)
  ) {
    lines.unshift('语料库结构检查完成，当前没有发现需要修复的问题。')
  } else {
    lines.unshift('语料库检查与修复已完成。')
  }

  return lines.join('\n')
}

function applyAppInfoToShell() {
  applyAppInfoToShellView(currentAppInfo, dom)
  if (helpCenterModal && !helpCenterModal.classList.contains('hidden')) {
    renderHelpCenterView(currentAppInfo, dom)
  }
}

async function ensureAppInfoLoaded() {
  if (appInfoLoaded) return currentAppInfo
  if (appInfoPromise) return appInfoPromise

  appInfoPromise = (async () => {
    if (window.electronAPI?.getAppInfo) {
      try {
        const result = await window.electronAPI.getAppInfo()
        if (result?.success && result.appInfo) {
          currentAppInfo = normalizeAppInfo(result.appInfo)
        }
      } catch (error) {
        console.warn('[app-info]', error)
      }
    }

    applyAppInfoToShell()
    appInfoLoaded = true
    return currentAppInfo
  })()

  try {
    return await appInfoPromise
  } finally {
    appInfoPromise = null
  }
}

function renderHelpCenter() {
  renderHelpCenterView(currentAppInfo, dom)
}

function openHelpCenterModal() {
  renderHelpCenter()
  helpCenterModal?.classList.remove('hidden')
}

function closeHelpCenterModal() {
  helpCenterModal?.classList.add('hidden')
}

async function promptForName({ title, message, defaultValue = '', placeholder = '', confirmText = '保存', label }) {
  return showPrompt({
    title,
    message,
    defaultValue,
    placeholder,
    confirmText,
    transform: value => String(value || '').trim(),
    validate: (rawValue, normalizedValue) => validateRequiredName(rawValue, normalizedValue, label)
  })
}

function decorateButton(button, iconName, label = '') {
  if (!button || button.querySelector('.button-content')) return
  const iconMarkup = BUTTON_ICONS[iconName]
  const textLabel = label || button.textContent.trim()
  if (!iconMarkup || !textLabel) return
  button.innerHTML = `<span class="button-content"><span class="button-icon">${iconMarkup}</span><span>${escapeHtml(textLabel)}</span></span>`
}

function decorateStaticButtons() {
  decorateButton(dom.closeWelcomeButton, 'open')
  decorateButton(restoreWorkspaceButton, 'restore')
  decorateButton(skipWorkspaceRestoreButton, 'close')
  decorateButton(openCorpusMenuButton, 'open')
  decorateButton(quickOpenButton, 'open')
  decorateButton(saveImportButton, 'import')
  decorateButton(libraryButton, 'library')
  decorateButton(clearRecentOpenButton, 'history')
  decorateButton(selectSavedCorporaButton, 'library')
  decorateButton(countButton, 'stats')
  decorateButton(cancelStatsButton, 'stop')
  decorateButton(checkUpdateButton, 'update')
  decorateButton(aboutButton, 'about')
  decorateButton(uiSettingsButton, 'settings')
  decorateButton(taskCenterButton, 'tasks')
  decorateButton(closeTaskCenterButton, 'close')
  decorateButton(resetWindowsCompatButton, 'reset')
  decorateButton(exportDiagnosticsButton, 'export')
  decorateButton(reportIssueButton, 'bug')
  decorateButton(kwicButton, 'spark')
  decorateButton(cancelKwicButton, 'stop')
  decorateButton(collocateButton, 'stats')
  decorateButton(cancelCollocateButton, 'stop')
  decorateButton(ngramButton, 'stats')
  decorateButton(copyStatsButton, 'export')
  decorateButton(copyFreqButton, 'export')
  decorateButton(exportAllFreqButton, 'exportAll')
  decorateButton(exportNgramButton, 'export')
  decorateButton(exportAllNgramButton, 'exportAll')
  decorateButton(copyCompareButton, 'export')
  decorateButton(exportAllCompareButton, 'exportAll')
  decorateButton(copyKWICButton, 'export')
  decorateButton(exportAllKWICButton, 'exportAll')
  decorateButton(exportCollocateButton, 'export')
  decorateButton(exportAllCollocateButton, 'exportAll')
  decorateButton(copyLocatorButton, 'export')
  decorateButton(createFolderButton, 'folderAdd')
  decorateButton(importToFolderButton, 'import')
  decorateButton(recycleBinButton, 'delete')
  decorateButton(backupLibraryButton, 'backup')
  decorateButton(restoreLibraryButton, 'restore')
  decorateButton(repairLibraryButton, 'repair')
  decorateButton(loadSelectedCorporaButton, 'open')
  decorateButton(reopenTutorialButton, 'about')
  decorateButton(openGitHubRepoButton, 'open')
  decorateButton(closeHelpCenterButton, 'close')
  decorateButton(resetUiSettingsButton, 'reset')
  decorateButton(closeUiSettingsButton, 'close')
  decorateButton(closeLibraryButton, 'close')
  decorateButton(closeRecycleButton, 'close')
  decorateButton(lightThemeButton, 'sun')
  decorateButton(darkThemeButton, 'moon')
  decorateButton(systemThemeButton, 'systemTheme')
}

function decorateLibraryControls() {
  decorateLibraryTableControls({
    libraryFolderList,
    libraryTableWrapper,
    decorateButton
  })
}

function decorateRecycleControls() {
  decorateRecycleTableControls({
    recycleTableWrapper,
    decorateButton
  })
}

function switchTab(tabName) {
  currentTab = tabName || 'stats'
  statsSection.classList.add('hidden')
  compareSection.classList.add('hidden')
  chiSquareSection.classList.add('hidden')
  wordCloudSection.classList.add('hidden')
  ngramSection.classList.add('hidden')
  kwicSection.classList.add('hidden')
  collocateSection.classList.add('hidden')
  locatorSection.classList.add('hidden')
  tabButtons.forEach(button => button.classList.remove('active'))
  if (tabName === 'stats') statsSection.classList.remove('hidden')
  else if (tabName === 'compare') compareSection.classList.remove('hidden')
  else if (tabName === 'chi-square') chiSquareSection.classList.remove('hidden')
  else if (tabName === 'word-cloud') wordCloudSection.classList.remove('hidden')
  else if (tabName === 'ngram') ngramSection.classList.remove('hidden')
  else if (tabName === 'kwic') kwicSection.classList.remove('hidden')
  else if (tabName === 'collocate') collocateSection.classList.remove('hidden')
  else if (tabName === 'locator') {
    locatorSection.classList.remove('hidden')
    if (locatorNeedsRender) renderSentenceViewer()
  }
  const activeButton = document.querySelector(`.tab-button[data-tab="${tabName}"]`)
  if (activeButton) activeButton.classList.add('active')
  scheduleWorkspaceSnapshotSave()
}

tabButtons.forEach(button => {
  button.addEventListener('click', () => switchTab(button.dataset.tab))
})

function getStatsState() {
  const currentSearchContext = getCurrentSearchContext()
  return {
    currentAnalysisMode,
    currentCorpusMode,
    currentCorpusDisplayName,
    currentCorpusFolderName,
    currentSelectedCorpora,
    currentTokens,
    currentFreqRows,
    currentDisplayedFreqRows: getVisibleFrequencyRows(),
    currentSearchQuery,
    currentSearchOptions,
    currentSearchError: currentSearchContext.error,
    currentPage,
    pageSize,
    currentTokenCount,
    currentTypeCount,
    currentTTR,
    currentSTTR
  }
}

function getCompareState() {
  const currentSearchContext = getCurrentSearchContext()
  return {
    currentSelectedCorpora,
    currentFreqRows,
    currentTokenCount,
    currentComparisonEntries,
    currentComparisonRows,
    currentComparisonCorpora,
    currentDisplayedCompareRows: getVisibleCompareRows(),
    currentSearchQuery,
    currentSearchError: currentSearchContext.error,
    currentComparePage,
    currentComparePageSize,
    hasStats: currentFreqRows.length > 0 || currentTokenCount > 0,
    comparisonEligible: currentComparisonEntries.length >= 2
  }
}

function getNgramState() {
  return {
    currentNgramRows,
    currentNgramPage,
    currentNgramPageSize
  }
}

function getKWICState() {
  return {
    currentKWICResults,
    currentKWICPage,
    currentKWICPageSize,
    currentKWICSortMode,
    currentKWICKeyword,
    currentSearchOptions,
    currentKWICLeftWindow,
    currentKWICRightWindow,
    currentKWICScope,
    currentKWICScopeLabel,
    currentKWICSearchedCorpusCount,
    currentKWICSortCache
  }
}

function getCollocateState() {
  return {
    currentCollocateRows,
    currentCollocatePage,
    currentCollocatePageSize
  }
}

function getLocatorState() {
  return {
    currentSentenceObjects,
    currentHighlight,
    activeSentenceId,
    pendingLocatorScrollSentenceId
  }
}

async function recordDiagnostic(level, scope, message, details = null) {
  if (!window.electronAPI?.writeDiagnosticLog) return
  try {
    await window.electronAPI.writeDiagnosticLog({
      level,
      scope,
      message,
      details
    })
  } catch (error) {
    console.warn('[diagnostics.log]', error)
  }
}

function normalizeDiagnosticError(error) {
  return error instanceof Error
    ? {
        name: error.name,
        message: error.message,
        stack: error.stack || ''
      }
    : {
        name: 'Error',
        message: String(error || '未知错误')
      }
}

function recordDiagnosticError(scope, error, details = null) {
  const normalizedError = normalizeDiagnosticError(error)
  void recordDiagnostic('error', scope, normalizedError.message, {
    ...(details && typeof details === 'object' ? details : {}),
    error: normalizedError
  })
  return normalizedError
}

function shouldSkipAutoBugFeedback(normalizedError) {
  if (!normalizedError || !normalizedError.message) return true
  const name = String(normalizedError.name || '').toLowerCase()
  if (name === 'aborterror') return true

  const message = String(normalizedError.message).toLowerCase()
  return (
    message.includes('aborted') ||
    message.includes('cancelled') ||
    message.includes('用户取消') ||
    message.includes('operation was aborted')
  )
}

function buildAutoBugIssueTitle(scope, normalizedError) {
  const scopeText = String(scope || 'renderer').trim() || 'renderer'
  const messageText = String(normalizedError?.message || 'Unknown error').trim() || 'Unknown error'
  return `[Bug][Auto] ${scopeText}: ${messageText}`.slice(0, 120)
}

async function exportDiagnosticsForFeedback(rendererState) {
  if (!window.electronAPI?.exportDiagnosticReportAuto) {
    return {
      success: false,
      unsupported: true,
      message: '当前版本不支持自动导出诊断包。'
    }
  }
  try {
    const result = await window.electronAPI.exportDiagnosticReportAuto(rendererState)
    if (!result?.success || !result.filePath) {
      return {
        success: false,
        message: result?.message || '自动导出诊断包失败。'
      }
    }
    return {
      success: true,
      filePath: result.filePath
    }
  } catch (error) {
    return {
      success: false,
      message: error?.message || '自动导出诊断包失败。'
    }
  }
}

async function openGitHubFeedbackIssue({
  issueTitle = '[Bug] 请简要描述问题',
  source = 'manual',
  successTitle = '反馈已准备',
  successMessage = '已打开 GitHub Issues，新页面里已预填当前会话摘要。',
  failureTitle = '打开 GitHub 反馈失败',
  failureMessage = '暂时无法打开 GitHub 反馈页。',
  autoExportDiagnostics = false,
  diagnosticsDetails = null
} = {}) {
  if (!window.electronAPI?.openGitHubFeedback) {
    await showMissingBridge('openGitHubFeedback')
    return false
  }

  const rendererState = getDiagnosticRendererState()
  let diagnosticsExportPath = ''
  if (autoExportDiagnostics) {
    const exportResult = await exportDiagnosticsForFeedback(rendererState)
    if (exportResult.success) {
      diagnosticsExportPath = exportResult.filePath
      rendererState.autoDiagnosticReportPath = diagnosticsExportPath
    } else if (!exportResult.unsupported) {
      void recordDiagnostic('warn', 'diagnostics.auto-export', exportResult.message || '自动导出诊断包失败。', {
        source
      })
    }
  }

  const result = await window.electronAPI.openGitHubFeedback({
    issueTitle,
    rendererState
  })

  if (!result || !result.success) {
    await showAlert({
      title: failureTitle,
      message: result?.message || failureMessage
    })
    return false
  }

  await refreshDiagnosticsStatusText()
  void recordDiagnostic('info', 'diagnostics', '用户已打开 GitHub 反馈页。', {
    source,
    issueUrl: result.issueUrl,
    ...(diagnosticsExportPath ? { diagnosticsExportPath } : {}),
    ...(diagnosticsDetails && typeof diagnosticsDetails === 'object' ? diagnosticsDetails : {})
  })
  showToast(successMessage, {
    title: successTitle,
    type: 'success',
    duration: 2600
  })
  return true
}

async function maybePromptAutoBugFeedback(scope, normalizedError, details = null) {
  if (shouldSkipAutoBugFeedback(normalizedError)) return
  if (!window.electronAPI?.openGitHubFeedback) return
  if (autoBugFeedbackInFlight) return
  if (autoBugFeedbackPromptCount >= AUTO_BUG_FEEDBACK_MAX_PROMPTS) return

  const signature = `${scope}:${normalizedError.name}:${normalizedError.message}`.slice(0, 320)
  const now = Date.now()
  if (
    signature === autoBugFeedbackLastSignature &&
    now - autoBugFeedbackLastPromptAt < AUTO_BUG_FEEDBACK_COOLDOWN_MS
  ) {
    return
  }

  autoBugFeedbackInFlight = true
  try {
    const confirmed = await showConfirm({
      title: '检测到异常',
      message: `WordZ 捕获到一个异常：${normalizedError.message}\n\n是否立即打开 GitHub 反馈页？系统会自动附带当前会话诊断信息。`,
      confirmText: '立即反馈',
      cancelText: '稍后',
      danger: true
    })

    autoBugFeedbackLastSignature = signature
    autoBugFeedbackLastPromptAt = Date.now()

    if (!confirmed) return

    autoBugFeedbackPromptCount += 1
    await openGitHubFeedbackIssue({
      issueTitle: buildAutoBugIssueTitle(scope, normalizedError),
      source: 'auto-error-capture',
      successTitle: '反馈页已打开',
      successMessage: '已打开 GitHub Issues，并自动附带异常上下文与诊断包路径。',
      autoExportDiagnostics: true,
      diagnosticsDetails: {
        scope,
        autoCaptured: true,
        error: normalizedError,
        details: details ?? null
      }
    })
  } finally {
    autoBugFeedbackInFlight = false
  }
}

function getDiagnosticRendererState() {
  return {
    currentTab,
    corpusMode: currentCorpusMode,
    analysisMode: currentAnalysisMode,
    corpusDisplayName: currentCorpusDisplayName,
    corpusFolderName: currentCorpusFolderName || '',
    selectedCorporaCount: currentSelectedCorpora.length,
    currentLibraryFolderId,
    libraryFolderCount: currentLibraryFolders.length,
    libraryVisibleCount: currentLibraryVisibleCount,
    libraryTotalCount: currentLibraryTotalCount,
    currentSearchQuery,
    searchOptionsSummary: getSearchOptionsSummary(),
    tokenCount: currentTokenCount,
    typeCount: currentTypeCount,
    ngramSize: currentNgramSize,
    ngramResultCount: currentNgramRows.length,
    kwicKeyword: currentKWICKeyword,
    kwicResultCount: currentKWICResults.length,
    kwicScope: currentKWICScopeLabel,
    collocateKeyword: currentCollocateKeyword,
    collocateResultCount: currentCollocateRows.length,
    chiSquareHasResult: Boolean(currentChiSquareResult),
    chiSquareInputs: {
      ...currentChiSquareInputValues
    },
    locatorSentenceCount: currentSentenceObjects.length,
    taskCenter: taskCenter.getEntries().slice(0, 5).map(entry => ({
      taskKey: entry.taskKey,
      status: entry.status,
      detail: entry.detail,
      durationMs: entry.durationMs || 0
    })),
    startupPhases: startupPhaseEvents.slice(-16).map(event => ({
      phase: event.phase,
      status: event.status,
      durationMs: Number(event.durationMs) || 0,
      startedAt: event.startedAt || '',
      endedAt: event.endedAt || '',
      errorMessage: event.errorMessage || ''
    })),
    uiSettings: getCurrentUISettings()
  }
}

async function refreshDiagnosticsStatusText() {
  if (!diagnosticsStatusText) return
  const enabled = getCurrentUISettings().debugLogging === true
  const fallbackText = enabled
    ? '调试日志已开启，会记录当前会话的关键操作和错误。'
    : '默认仅保留轻量错误摘要。开启后会把当前会话的关键操作和错误写入诊断日志，便于导出或反馈到 GitHub。'

  if (!window.electronAPI?.getDiagnosticState) {
    diagnosticsStatusText.textContent = fallbackText
    return
  }

  try {
    const result = await window.electronAPI.getDiagnosticState()
    const diagnostics = result?.success ? result.diagnostics : null
    const windowsCompat = result?.success ? result.windowsCompat : null
    if (resetWindowsCompatButton) {
      resetWindowsCompatButton.hidden = !Boolean(windowsCompat?.supported)
    }
    if (!diagnostics) {
      diagnosticsStatusText.textContent = fallbackText
      return
    }
    const errorCount = Array.isArray(diagnostics.recentErrors) ? diagnostics.recentErrors.length : 0
    const logStatus = diagnostics.debugLoggingEnabled ? '已开启' : '未开启'
    const compatText = windowsCompat?.supported
      ? ` ｜ Windows兼容 ${windowsCompat.compatProfile || 'standard'}${windowsCompat.lastCrash?.reason ? `（最近崩溃：${windowsCompat.lastCrash.reason}${Number.isFinite(Number(windowsCompat.lastCrash.exitCode)) ? ` / ${windowsCompat.lastCrash.exitCode}` : ''}）` : ''}`
      : ''
    diagnosticsStatusText.textContent = `本次会话 ${diagnostics.sessionId || ''} ｜ 调试日志${logStatus} ｜ 最近错误 ${errorCount} 条${diagnostics.logFilePath ? ` ｜ 日志：${diagnostics.logFilePath}` : ''}${compatText}`
  } catch (error) {
    console.warn('[diagnostics.state]', error)
    if (resetWindowsCompatButton) {
      resetWindowsCompatButton.hidden = true
    }
    diagnosticsStatusText.textContent = fallbackText
  }
}

function loadStoredWorkspaceSnapshot() {
  return loadStoredWorkspaceSnapshotFromStorage(localStorage, WORKSPACE_STATE_STORAGE_KEY)
}

function applySelectControlValue(control, value, fallbackValue) {
  if (!control) return
  const nextValue = String(value || fallbackValue || '')
  const options = Array.from(control.options || []).map(option => option.value)
  control.value = options.includes(nextValue) ? nextValue : String(fallbackValue || control.value || '')
}

function buildWorkspaceSnapshot() {
  const restorableCorpusIds =
    currentCorpusMode === 'saved' || currentCorpusMode === 'saved-multi'
      ? currentSelectedCorpora.map(item => item.id).filter(Boolean)
      : []
  const restorableCorpusNames =
    currentCorpusMode === 'saved' || currentCorpusMode === 'saved-multi'
      ? currentSelectedCorpora.map(item => item.name).filter(Boolean)
      : []

  return {
    version: WORKSPACE_SNAPSHOT_VERSION,
    savedAt: new Date().toISOString(),
    currentTab,
    currentLibraryFolderId,
    previewCollapsed: previewPanelBody?.classList.contains('hidden') !== false,
    workspace: {
      corpusIds: restorableCorpusIds,
      corpusNames: restorableCorpusNames
    },
    search: {
      query: currentSearchQuery,
      options: { ...currentSearchOptions }
    },
    stats: {
      pageSize: pageSizeSelect?.value || '10'
    },
    compare: {
      pageSize: comparePageSizeSelect?.value || '10'
    },
    ngram: {
      pageSize: ngramPageSizeSelect?.value || '10',
      size: ngramSizeSelect?.value || String(currentNgramSize || 2)
    },
    kwic: {
      pageSize: kwicPageSizeSelect?.value || '10',
      scope: kwicScopeSelect?.value || 'current',
      sortMode: kwicSortSelect?.value || 'original',
      leftWindow: leftWindowSelect?.value || String(currentKWICLeftWindow || DEFAULT_WINDOW_SIZE),
      rightWindow: rightWindowSelect?.value || String(currentKWICRightWindow || DEFAULT_WINDOW_SIZE)
    },
    collocate: {
      pageSize: collocatePageSizeSelect?.value || '10',
      leftWindow: collocateLeftWindowSelect?.value || String(currentCollocateLeftWindow || DEFAULT_WINDOW_SIZE),
      rightWindow: collocateRightWindowSelect?.value || String(currentCollocateRightWindow || DEFAULT_WINDOW_SIZE),
      minFreq: collocateMinFreqSelect?.value || String(currentCollocateMinFreq || 1)
    },
    chiSquare: {
      a: String(chiAInput?.value || ''),
      b: String(chiBInput?.value || ''),
      c: String(chiCInput?.value || ''),
      d: String(chiDInput?.value || ''),
      yates: chiYatesToggle?.checked === true
    }
  }
}

function persistWorkspaceSnapshot() {
  if (workspaceRestoreInProgress || !workspaceSnapshotReady) return
  try {
    localStorage.setItem(WORKSPACE_STATE_STORAGE_KEY, JSON.stringify(buildWorkspaceSnapshot()))
  } catch (error) {
    console.warn('[workspace.snapshot.save]', error)
  }
}

function scheduleWorkspaceSnapshotSave({ immediate = false } = {}) {
  if (workspaceRestoreInProgress || !workspaceSnapshotReady) return
  if (workspaceSnapshotTimer) clearTimeout(workspaceSnapshotTimer)
  if (immediate) {
    workspaceSnapshotTimer = null
    persistWorkspaceSnapshot()
    return
  }
  workspaceSnapshotTimer = setTimeout(() => {
    workspaceSnapshotTimer = null
    persistWorkspaceSnapshot()
  }, 120)
}

async function restoreWorkspaceFromSnapshot(snapshot = loadStoredWorkspaceSnapshot()) {
  if (!snapshot || getCurrentUISettings().restoreWorkspace === false) return

  workspaceRestoreInProgress = true
  const endBusyState = beginBusyState('正在恢复上次工作区...')

  try {
    currentLibraryFolderId = snapshot.currentLibraryFolderId || currentLibraryFolderId
    setPreviewCollapsed(snapshot.previewCollapsed !== false)

    let restoredSavedWorkspace = false
    if (snapshot.workspace.corpusIds.length > 0 && window.electronAPI?.openSavedCorpora) {
      const result = await window.electronAPI.openSavedCorpora(snapshot.workspace.corpusIds)
      if (result?.success) {
        await loadCorpusResult(result, { trackRecent: false })
        restoredSavedWorkspace = true
      } else {
        void recordDiagnostic('warn', 'workspace.restore', '未能恢复上次已保存语料工作区。', {
          message: result?.message || '未知原因',
          corpusIds: snapshot.workspace.corpusIds
        })
      }
    }

    applySelectControlValue(pageSizeSelect, snapshot.stats.pageSize, '10')
    applySelectControlValue(comparePageSizeSelect, snapshot.compare.pageSize, '10')
    applySelectControlValue(ngramPageSizeSelect, snapshot.ngram.pageSize, '10')
    applySelectControlValue(ngramSizeSelect, snapshot.ngram.size, '2')
    applySelectControlValue(kwicPageSizeSelect, snapshot.kwic.pageSize, '10')
    applySelectControlValue(collocatePageSizeSelect, snapshot.collocate.pageSize, '10')
    applySelectControlValue(kwicSortSelect, snapshot.kwic.sortMode, 'original')
    applySelectControlValue(kwicScopeSelect, snapshot.kwic.scope, 'current')
    applySelectControlValue(collocateMinFreqSelect, snapshot.collocate.minFreq, '1')

    if (leftWindowSelect) {
      leftWindowSelect.value = snapshot.kwic.leftWindow
      normalizeWindowSizeInput(leftWindowSelect)
      currentKWICLeftWindow = Number(leftWindowSelect.value) || DEFAULT_WINDOW_SIZE
    }
    if (rightWindowSelect) {
      rightWindowSelect.value = snapshot.kwic.rightWindow
      normalizeWindowSizeInput(rightWindowSelect)
      currentKWICRightWindow = Number(rightWindowSelect.value) || DEFAULT_WINDOW_SIZE
    }
    if (collocateLeftWindowSelect) {
      collocateLeftWindowSelect.value = snapshot.collocate.leftWindow
      normalizeWindowSizeInput(collocateLeftWindowSelect)
      currentCollocateLeftWindow = Number(collocateLeftWindowSelect.value) || DEFAULT_WINDOW_SIZE
    }
    if (collocateRightWindowSelect) {
      collocateRightWindowSelect.value = snapshot.collocate.rightWindow
      normalizeWindowSizeInput(collocateRightWindowSelect)
      currentCollocateRightWindow = Number(collocateRightWindowSelect.value) || DEFAULT_WINDOW_SIZE
    }
    currentCollocateMinFreq = Number(collocateMinFreqSelect?.value || '1') || 1
    currentChiSquareInputValues = {
      a: String(snapshot.chiSquare?.a || ''),
      b: String(snapshot.chiSquare?.b || ''),
      c: String(snapshot.chiSquare?.c || ''),
      d: String(snapshot.chiSquare?.d || ''),
      yates: snapshot.chiSquare?.yates === true
    }
    syncChiSquareInputsFromState()
    currentChiSquareResult = null
    renderChiSquareResult()

    currentSearchOptions = normalizeSearchOptions(snapshot.search.options)
    syncSearchOptionInputs()
    setSharedSearchQuery(snapshot.search.query, { rerender: false })

    pageSize = resolvePageSize(pageSizeSelect?.value || '10', getVisibleFrequencyRows().length)
    currentComparePageSize = resolvePageSize(comparePageSizeSelect?.value || '10', getVisibleCompareRows().length)
    currentNgramSize = Number(ngramSizeSelect?.value || snapshot.ngram.size || '2') || 2
    currentNgramPageSize = resolvePageSize(ngramPageSizeSelect?.value || '10', currentNgramRows.length)
    currentKWICPageSize = resolvePageSize(kwicPageSizeSelect?.value || '10', currentKWICResults.length)
    currentCollocatePageSize = resolvePageSize(collocatePageSizeSelect?.value || '10', currentCollocateRows.length)
    currentKWICSortMode = kwicSortSelect?.value || 'original'
    currentKWICScope = kwicScopeSelect?.value || 'current'
    if (currentTokens.length > 0) {
      await runNgramAnalysis({ silent: true })
    } else {
      renderNgramTable()
    }

    switchTab(getRestorableTabFromSnapshot(snapshot))
    updateCurrentCorpusInfo()
    renderCompareSection()
    renderWordCloud()
    void recordDiagnostic('info', 'workspace.restore', restoredSavedWorkspace ? '已恢复上次工作区。' : '已恢复上次工作区偏好设置。', {
      restoredSavedWorkspace,
      currentTab: getRestorableTabFromSnapshot(snapshot),
      corpusCount: snapshot.workspace.corpusIds.length
    })
  } finally {
    workspaceRestoreInProgress = false
    endBusyState()
  }
}

function renderWorkspaceOverview() {
  renderWorkspaceOverviewSection(getStatsState(), dom, { formatCount })
}

function renderStatsSummaryTable() {
  renderStatsSummarySection(getStatsState(), dom, { formatCount })
}

function renderFrequencyTable() {
  const result = renderFrequencyTableSection(getStatsState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    renderTableInChunks
  })
  currentPage = result.currentPage
}

function renderCompareTable() {
  renderCompareSection()
}

function renderNgramTable() {
  const result = renderNgramTableSection(getNgramState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    renderTableInChunks
  })
  currentNgramPage = result.currentNgramPage
}

function renderKWICTable() {
  const result = renderKWICTableSection(getKWICState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    renderTableInChunks,
    sortResults: sortKWICResults
  })
  currentKWICPage = result.currentKWICPage
  currentKWICSortCache = result.currentKWICSortCache
}

function renderCollocateTable() {
  const result = renderCollocateTableSection(getCollocateState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    renderTableInChunks
  })
  currentCollocatePage = result.currentCollocatePage
}

function renderSentenceViewer() {
  const result = renderSentenceViewerSection(getLocatorState(), dom, {
    cancelTableRender,
    escapeHtml,
    formatCount,
    onSentenceVisible: target => {
      pendingLocatorScrollSentenceId = null
      requestAnimationFrame(() => {
        target.scrollIntoView({ behavior: 'smooth', block: 'center' })
      })
    },
    renderTableInChunks
  })
  locatorNeedsRender = result.locatorNeedsRender
}

function locateSentence(sentenceId, nodeIndex, leftWindowSize, rightWindowSize) {
  activeSentenceId = sentenceId
  pendingLocatorScrollSentenceId = sentenceId
  currentHighlight = buildLocatorHighlight(sentenceId, nodeIndex, leftWindowSize, rightWindowSize)
  renderSentenceViewer()
  locatorMeta.textContent = `已定位到第 ${sentenceId + 1} 句。节点词为黄色，左侧上下文为蓝色，右侧上下文为绿色。`
}

function buildStatsRows() {
  return buildStatsRowsData(getStatsState())
}

function buildFrequencyRows() {
  return buildFrequencyRowsData(getStatsState())
}

function buildNgramRows() {
  return buildNgramRowsData(getNgramState())
}

function buildKWICRows() {
  const result = buildKWICRowsData(getKWICState(), sortKWICResults)
  currentKWICSortCache = result.cache
  return result.rows
}

function buildAllFrequencyRows() {
  return buildAllFrequencyRowsData(getStatsState())
}

function buildAllNgramRows() {
  return buildAllNgramRowsData(getNgramState())
}

function buildCompareRows() {
  return buildCompareRowsData(getCompareState())
}

function buildAllCompareRows() {
  return buildAllCompareRowsData(getCompareState())
}

function buildAllKWICRows() {
  const result = buildAllKWICRowsData(getKWICState(), sortKWICResults)
  currentKWICSortCache = result.cache
  return result.rows
}

function buildCollocateRows() {
  return buildCollocateRowsData(getCollocateState())
}

function buildAllCollocateRows() {
  return buildAllCollocateRowsData(getCollocateState())
}

function buildLocatorRows() {
  return buildLocatorRowsData(getLocatorState())
}

function setLibraryFolderSelection(folderId) {
  currentLibraryFolderId = folderId || 'all'
  localStorage.setItem(LIBRARY_FOLDER_STORAGE_KEY, currentLibraryFolderId)
  scheduleWorkspaceSnapshotSave()
}

function getImportTargetFolder() {
  return getImportTargetFolderForState(currentLibraryFolderId, currentLibraryFolders)
}

function updateLibraryTargetChip() {
  libraryTargetChip.textContent = getLibraryTargetChipText(currentLibraryFolderId, currentLibraryFolders)
}

function updateCurrentCorpusInfo() {
  if (!currentCorpusDisplayName) {
    fileInfo.textContent = '尚未选择文件'
    renderSelectedCorporaTable()
    renderWorkspaceOverview()
    return
  }

  if (currentCorpusMode === 'saved') {
    const folderLabel = currentCorpusFolderName || '未分类'
    fileInfo.textContent = `当前语料（已保存 / ${folderLabel}）：${currentCorpusDisplayName}`
    renderSelectedCorporaTable()
    renderWorkspaceOverview()
    return
  }

  if (currentCorpusMode === 'saved-multi') {
    fileInfo.textContent = `当前语料（多选 / ${currentSelectedCorpora.length} 条）：${currentCorpusDisplayName}`
    renderSelectedCorporaTable()
    renderWorkspaceOverview()
    return
  }

  fileInfo.textContent = '当前语料（Quick Corpus）：' + currentCorpusDisplayName
  renderSelectedCorporaTable()
  renderWorkspaceOverview()
}

function demoteCurrentSavedCorpusToQuick() {
  if (currentCorpusMode !== 'saved' && currentCorpusMode !== 'saved-multi') return
  currentCorpusMode = 'quick'
  currentCorpusId = null
  currentCorpusFolderId = null
  currentCorpusFolderName = ''
  currentSelectedCorpora = []
  syncLibrarySelectionWithCurrentCorpora()
  updateLoadSelectedCorporaButton()
  updateLibraryMetaText()
  updateCurrentCorpusInfo()
  scheduleWorkspaceSnapshotSave()
}

function getSelectedKWICScope() {
  return kwicScopeSelect?.value || 'current'
}

function getSelectedNgramSize() {
  const value = Number(ngramSizeSelect?.value || currentNgramSize || 2)
  if (!Number.isFinite(value) || !Number.isInteger(value) || value <= 0) return 2
  return Math.min(9, value)
}

async function runNgramAnalysis({ switchToTab = false, silent = false } = {}) {
  const hasNgramCorpus = currentAnalysisMode === 'segmented'
    ? Boolean(currentText.trim())
    : currentTokens.length > 0
  if (!hasNgramCorpus) {
    currentNgramRows = []
    currentNgramPage = 1
    currentNgramPageSize = resolvePageSize(ngramPageSizeSelect?.value || '10', 0)
    ngramMeta.textContent = '请先导入语料后再生成 Ngram。'
    renderNgramTable()
    if (!silent) {
      await showAlert({
        title: '缺少语料',
        message: '请先导入一个 txt / docx / pdf 文件'
      })
    }
    return false
  }

  const n = getSelectedNgramSize()
  const runId = nextAnalysisRun('ngram')

  try {
    const cachedRows = Array.isArray(currentAnalysisCachePayload?.ngrams?.[String(n)])
      ? currentAnalysisCachePayload.ngrams[String(n)]
      : null
    const ngramResult = cachedRows
      ? {
          n,
          rows: cachedRows
        }
      : await runAnalysisTask(
          currentAnalysisMode === 'segmented'
            ? ANALYSIS_TASK_TYPES.computeNgramsSegmented
            : ANALYSIS_TASK_TYPES.computeNgrams,
          currentAnalysisMode === 'segmented'
            ? {
                n,
                text: currentText,
                chunkCharSize: SEGMENTED_ANALYSIS_CHUNK_CHARS
              }
            : { n },
          () =>
            currentAnalysisMode === 'segmented'
              ? computeSegmentedNgramRows(currentText, n, {
                  chunkCharSize: SEGMENTED_ANALYSIS_CHUNK_CHARS
                })
              : (() => {
                  const freqMap = countNgramFrequency(currentTokens, n)
                  return {
                    n,
                    rows: getSortedNgramRows(freqMap)
                  }
                })()
        )
    if (!isLatestAnalysisRun('ngram', runId)) return false

    currentNgramSize = Number(ngramResult?.n || n) || n
    currentNgramRows = Array.isArray(ngramResult?.rows) ? ngramResult.rows : []
    currentNgramPageSize = resolvePageSize(ngramPageSizeSelect?.value || '10', currentNgramRows.length)
    currentNgramPage = 1
    ngramMeta.textContent = `${currentNgramSize}-gram · 共 ${formatCount(currentNgramRows.length)} 条结果。`
    renderNgramTable()
    if (switchToTab) switchTab('ngram')
    if (!cachedRows) {
      updateCurrentAnalysisCache({
        ngramSize: currentNgramSize,
        ngramRows: currentNgramRows
      })
      void persistAnalysisCachePayload()
    }
    void refreshAnalysisCacheState({ silent: true })
    maybeWarnMemoryPressure('analysis.ngram')
    scheduleWorkspaceSnapshotSave()
    return true
  } catch (error) {
    recordDiagnosticError('analysis.ngram', error, {
      n,
      tokenCount: currentTokens.length,
      analysisMode: currentAnalysisMode
    })
    if (!silent) {
      await showAlert({
        title: 'Ngram 生成失败',
        message: getErrorMessage(error, 'Ngram 生成失败')
      })
    }
    return false
  }
}

async function resolveCrossCorpusKWICScope(scope) {
  if (!window.electronAPI?.searchLibraryKWIC) {
    await showMissingBridge('searchLibraryKWIC')
    return null
  }

  if (scope === 'folder') {
    if (currentCorpusMode !== 'saved' || !currentCorpusFolderId) {
      await showAlert({
        title: '无法检索当前文件夹',
        message: '请先打开一条已保存语料，再使用“当前文件夹”范围检索。'
      })
      return null
    }

    return {
      folderId: currentCorpusFolderId,
      scopeLabel: `当前文件夹 · ${currentCorpusFolderName || '未分类'}`,
      emptyTitle: '当前文件夹为空',
      emptyMessage: `文件夹「${currentCorpusFolderName || '未分类'}」里还没有可检索的语料。`
    }
  }

  return {
    folderId: 'all',
    scopeLabel: '全部本地语料',
    emptyTitle: '本地语料库为空',
    emptyMessage: '请先导入并保存至少一条本地语料，再使用“全部本地语料”检索。'
  }
}

async function refreshLibraryModal(folderId = currentLibraryFolderId) {
  const endBusyState = beginBusyState('正在读取本地语料库...')
  currentLibraryVisibleCount = 0
  libraryMeta.textContent = '正在读取本地语料库...'
  libraryFolderList.innerHTML = '<div class="empty-tip">正在加载文件夹...</div>'
  libraryTableWrapper.innerHTML = '<div class="empty-tip">正在加载本地语料库...</div>'

  try {
    const result = await window.electronAPI.listSavedCorpora(folderId)
    if (!result.success) {
      libraryMeta.textContent = '读取失败'
      libraryFolderList.innerHTML = '<div class="empty-tip">无法读取文件夹信息</div>'
      libraryTableWrapper.innerHTML = '<div class="empty-tip">无法读取本地语料库</div>'
      return
    }

    currentLibraryFolders = result.folders || []
    currentLibraryVisibleCount = (result.items || []).length
    currentLibraryTotalCount = result.totalCount || 0
    setLibraryFolderSelection(result.selectedFolderId || 'all')
    updateLibraryTargetChip()
    libraryFolderList.innerHTML = buildLibraryFolderList(
      currentLibraryFolders,
      currentLibraryFolderId,
      result.totalCount || 0,
      escapeHtml
    )
    libraryTableWrapper.innerHTML = buildLibraryTable(
      result.items || [],
      currentLibraryFolders,
      currentLibraryFolderId,
      escapeHtml,
      { selectedCorpusIds: selectedLibraryCorpusIds }
    )
    decorateLibraryControls()
    updateLoadSelectedCorporaButton()
    updateLibraryMetaText()
  } finally {
    endBusyState()
  }
}

async function openLibraryModal(folderId = currentLibraryFolderId) {
  if (!window.electronAPI?.listSavedCorpora) {
    await showMissingBridge('listSavedCorpora')
    return
  }

  syncLibrarySelectionWithCurrentCorpora()
  updateLoadSelectedCorporaButton()
  libraryModal.classList.remove('hidden')
  await refreshLibraryModal(folderId)
}

function closeLibraryModal() {
  libraryModal.classList.add('hidden')
}

async function refreshRecycleBinModal() {
  recycleMeta.textContent = '正在读取回收站...'
  recycleTableWrapper.innerHTML = '<div class="empty-tip">正在读取回收站...</div>'

  const result = await window.electronAPI.listRecycleBin()
  if (!result.success) {
    recycleMeta.textContent = '读取失败'
    recycleTableWrapper.innerHTML = '<div class="empty-tip">无法读取回收站</div>'
    return
  }

  recycleMeta.textContent = `共 ${formatCount(result.totalCount || 0)} 条项目，其中 ${formatCount(result.folderCount || 0)} 个文件夹、${formatCount(result.corpusCount || 0)} 条语料。`
  recycleTableWrapper.innerHTML = buildRecycleBinTable(result.entries || [], escapeHtml)
  decorateRecycleControls()
}

async function openRecycleModal() {
  if (!window.electronAPI?.listRecycleBin) {
    await showMissingBridge('listRecycleBin')
    return
  }

  recycleModal.classList.remove('hidden')
  await refreshRecycleBinModal()
}

function closeRecycleModal() {
  recycleModal.classList.add('hidden')
}

async function loadCorpusResult(result, { trackRecent = true } = {}) {
  if (!result || !result.success) return
  cancelAllAnalysisTasks('已因切换语料取消当前分析任务')
  const runId = nextAnalysisRun('loadCorpus')
  nextAnalysisRun('stats')
  nextAnalysisRun('ngram')
  nextAnalysisRun('kwic')
  nextAnalysisRun('collocate')
  const endBusyState = beginBusyState('正在解析语料...')
  isCorpusLoading = true
  updateAnalysisActionButtons()
  setButtonsBusy([openCorpusMenuButton, quickOpenButton, saveImportButton, importToFolderButton], true)

  try {
    const normalizedComparisonEntries = normalizeComparisonEntries(result.comparisonEntries)
    currentText = resolveCorpusText(result, normalizedComparisonEntries)
    currentCorpusMode = result.mode || 'quick'
    currentCorpusId = result.corpusId || null
    currentCorpusDisplayName = result.displayName || result.fileName || ''
    currentCorpusFolderId = result.folderId || null
    currentCorpusFolderName = result.folderName || ''
    currentSelectedCorpora = Array.isArray(result.selectedItems)
      ? result.selectedItems.map(item => ({
          id: item.id,
          name: item.name,
          folderId: item.folderId,
          folderName: item.folderName,
          sourceType: item.sourceType
        }))
      : (result.corpusId
          ? [{
              id: result.corpusId,
              name: result.displayName || result.fileName || '',
              folderId: result.folderId || '',
              folderName: result.folderName || '',
              sourceType: result.sourceType || 'txt'
            }]
          : [])
    currentComparisonEntries =
      currentCorpusMode === 'saved-multi'
        ? normalizedComparisonEntries
        : []
    currentAnalysisMode = shouldUseSegmentedAnalysis(currentText) ? 'segmented' : 'full'
    currentAnalysisCacheKey = buildAnalysisCacheKey(result, currentText)
    currentAnalysisCachePayload = null

    let corpusData = {
      sentences: [],
      tokenObjects: [],
      tokens: []
    }
    let usedCachedCorpusData = false
    const cachedPayload = await loadAnalysisCachePayload(currentAnalysisCacheKey)
    if (cachedPayload) {
      if (cachedPayload.analysisMode === 'segmented') {
        currentAnalysisMode = 'segmented'
      }
      currentAnalysisCachePayload = cachedPayload
      if (currentAnalysisMode === 'full' && cachedPayload?.corpusData) {
        corpusData = cachedPayload.corpusData
        usedCachedCorpusData = true
      }
    }

    if (currentAnalysisMode === 'full' && !usedCachedCorpusData) {
      corpusData = await runAnalysisTask(
        ANALYSIS_TASK_TYPES.loadCorpus,
        { text: currentText },
        () => buildCorpusData(currentText)
      )
      currentAnalysisCachePayload = normalizeAnalysisCachePayload({
        schemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
        analysisMode: 'full',
        corpusData: {
          sentences: corpusData?.sentences || [],
          tokenObjects: corpusData?.tokenObjects || [],
          tokens: corpusData?.tokens || []
        },
        stats: null,
        ngrams: {}
      })
      void persistAnalysisCachePayload()
    } else if (currentAnalysisMode === 'segmented') {
      const segmentedPayloadSeed =
        currentAnalysisCachePayload && typeof currentAnalysisCachePayload === 'object'
          ? {
              ...currentAnalysisCachePayload,
              analysisMode: 'segmented',
              corpusData: {
                sentences: [],
                tokenObjects: [],
                tokens: []
              }
            }
          : {
              schemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
              analysisMode: 'segmented',
              corpusData: {
                sentences: [],
                tokenObjects: [],
                tokens: []
              },
              stats: null,
              ngrams: {}
            }
      currentAnalysisCachePayload = normalizeAnalysisCachePayload(
        segmentedPayloadSeed
      )
      if (!cachedPayload) {
        void persistAnalysisCachePayload()
      }
    }
    if (!isLatestAnalysisRun('loadCorpus', runId)) return

    currentSentenceObjects = Array.isArray(corpusData?.sentences) ? corpusData.sentences : []
    currentTokenObjects = Array.isArray(corpusData?.tokenObjects) ? corpusData.tokenObjects : []
    currentTokens =
      currentAnalysisMode === 'segmented'
        ? []
        : (Array.isArray(corpusData?.tokens) ? corpusData.tokens : currentTokenObjects.map(item => item.token))
    currentFreqRows = []
    currentComparisonRows = []
    currentComparisonCorpora = []
    invalidateSearchCaches()
    setSharedSearchQuery('', { rerender: false })
    currentNgramRows = []
    currentNgramPage = 1
    currentNgramPageSize = 10
    currentNgramSize = 2
    currentKWICResults = []
    currentCollocateRows = []
    invalidateKWICSortCache()
    currentPage = 1
    currentComparePage = 1
    currentNgramPage = 1
    currentKWICPage = 1
    currentCollocatePage = 1
    currentComparePageSize = 10
    currentNgramPageSize = 10
    currentKWICPageSize = 10
    currentCollocatePageSize = 10
    currentKWICSortMode = 'original'
    currentKWICKeyword = ''
    currentKWICLeftWindow = 5
    currentKWICRightWindow = 5
    currentKWICScope = 'current'
    currentKWICScopeLabel = '当前语料'
    currentKWICSearchedCorpusCount = 0
    currentCollocateKeyword = ''
    currentCollocateLeftWindow = 5
    currentCollocateRightWindow = 5
    currentCollocateMinFreq = 1
    currentTokenCount = 0
    currentTypeCount = 0
    currentTTR = 0
    currentSTTR = 0
    activeSentenceId = null
    currentHighlight = null
    locatorNeedsRender = true

    kwicSortSelect.value = 'original'
    syncSharedSearchInputs()
    leftWindowSelect.value = '5'
    rightWindowSelect.value = '5'
    comparePageSizeSelect.value = '10'
    ngramSizeSelect.value = '2'
    ngramPageSizeSelect.value = '10'
    kwicPageSizeSelect.value = '10'
    collocateLeftWindowSelect.value = '5'
    collocateRightWindowSelect.value = '5'
    collocateMinFreqSelect.value = '1'
    collocatePageSizeSelect.value = '10'

    syncCurrentWorkspaceSelectionState()

    previewBox.textContent = getPreviewText(currentText, PREVIEW_CHAR_LIMIT)
    statsSummaryWrapper.innerHTML = '<div class="empty-tip">文本已导入，请点击“开始统计”</div>'
    totalRowsInfo.textContent = '共 0 个单词'
    pageInfo.textContent = '第 0 / 0 页'
    prevPageButton.disabled = true
    nextPageButton.disabled = true
    tableWrapper.innerHTML = '<div class="empty-tip">文本已导入，请点击“开始统计”</div>'
    compareSummaryWrapper.innerHTML = currentComparisonEntries.length >= 2
      ? '<div class="empty-tip">当前多语料工作区已就绪。点击“开始统计”后生成对比摘要。</div>'
      : '<div class="empty-tip">载入两条以上已保存语料后，这里会显示多语料对比摘要。</div>'
    compareTotalRowsInfo.textContent = currentComparisonEntries.length >= 2 ? '等待统计结果' : '至少需要 2 条语料'
    comparePageInfo.textContent = '第 0 / 0 页'
    comparePrevPageButton.disabled = true
    compareNextPageButton.disabled = true
    compareMeta.textContent = currentComparisonEntries.length >= 2
      ? `当前已载入 ${formatCount(currentComparisonEntries.length)} 条语料。点击“开始统计”后生成对比结果。`
      : '这里会在载入两条以上已保存语料后显示“多语料对比分析”。'
    compareWrapper.innerHTML = currentComparisonEntries.length >= 2
      ? '<div class="empty-tip">这里会在统计完成后显示多语料词频对比表。</div>'
      : '<div class="empty-tip">这里会显示多语料词频对比表</div>'
    renderWordCloud()
    ngramTotalRowsInfo.textContent = '共 0 条结果'
    ngramPageInfo.textContent = '第 0 / 0 页'
    ngramPrevPageButton.disabled = true
    ngramNextPageButton.disabled = true
    ngramMeta.textContent =
      currentAnalysisMode === 'segmented'
        ? '已启用分段分析模式。可继续生成 Ngram（流式统计）。'
        : '语料已导入。可选择 2-gram 到 5-gram 后点击“生成 Ngram”。'
    ngramWrapper.innerHTML = '<div class="empty-tip">这里会显示 Ngram 统计结果</div>'
    kwicTotalRowsInfo.textContent = '共 0 条结果'
    kwicPageInfo.textContent = '第 0 / 0 页'
    kwicPrevPageButton.disabled = true
    kwicNextPageButton.disabled = true
    kwicMeta.innerHTML =
      currentAnalysisMode === 'segmented'
        ? '当前语料体量较大，已启用分段分析模式。为保证稳定性，KWIC 检索暂不可用。<br />可切换更小语料后再做 KWIC。'
        : '文本已导入。请输入检索词，选择检索范围，并设置左右窗口大小后点击“KWIC 检索”。<br />支持当前语料、当前文件夹和全部本地语料。'
    kwicWrapper.innerHTML = '<div class="empty-tip">这里会显示关键词前后文结果</div>'
    collocateTotalRowsInfo.textContent = '共 0 条结果'
    collocatePageInfo.textContent = '第 0 / 0 页'
    collocatePrevPageButton.disabled = true
    collocateNextPageButton.disabled = true
    collocateMeta.innerHTML =
      currentAnalysisMode === 'segmented'
        ? '当前语料体量较大，已启用分段分析模式。为保证稳定性，Collocate 统计暂不可用。'
        : '文本已导入。请输入节点词后开始统计 Collocate。'
    collocateWrapper.innerHTML = '<div class="empty-tip">这里会显示 Collocate 统计结果</div>'
    locatorMeta.textContent = '原文已载入。点击任一 KWIC 结果行后，会自动定位并高亮对应原句。'
    sentenceViewer.innerHTML = '<div class="empty-tip">切换到“原文定位”或点击某条 KWIC 结果后，这里会按需加载定位表。</div>'
    switchTab('stats')
    if (trackRecent) {
      addRecentOpenEntry(buildRecentOpenEntryFromResult(result))
    }
    if (currentAnalysisMode === 'segmented') {
      showToast('检测到超大语料，已切换为分段分析模式（统计/Ngram可用，KWIC/Collocate已暂时禁用）。', {
        title: '内存保护已启用',
        duration: 3400
      })
    }
    void refreshAnalysisCacheState({ silent: true })
    maybeWarnMemoryPressure('load-corpus')
    await showPreflightWarnings(result)
    void recordDiagnostic('info', 'corpus.load', '语料已载入工作区。', {
      mode: currentCorpusMode,
      analysisMode: currentAnalysisMode,
      corpusName: currentCorpusDisplayName,
      selectedCorporaCount: currentSelectedCorpora.length,
      tokenCount: currentTokens.length,
      textLength: currentText.length,
      usedCachedCorpusData
    })
  } catch (error) {
    console.error('[loadCorpusResult]', error)
    recordDiagnosticError('corpus.load', error, {
      resultMode: result?.mode || '',
      corpusName: result?.displayName || result?.fileName || ''
    })
    await showAlert({
      title: '处理语料失败',
      message: getErrorMessage(error, '处理语料失败')
    })
  } finally {
    endBusyState()
    isCorpusLoading = false
    updateAnalysisActionButtons()
    setButtonsBusy([openCorpusMenuButton, quickOpenButton, saveImportButton, importToFolderButton], false)
  }
}

async function handleSystemOpenFileRequest(payload = {}) {
  const filePath = String(payload?.filePath || '').trim()
  if (!filePath) return

  if (!window.electronAPI?.openQuickCorpusAtPath) {
    await showMissingBridge('openQuickCorpusAtPath')
    return
  }

  setOpenCorpusMenuOpen(false)
  closeHelpCenterModal()
  closeLibraryModal()
  closeRecycleModal()
  hideWelcomeOverlay({ immediate: true })

  const result = await window.electronAPI.openQuickCorpusAtPath(filePath)
  if (!result?.success) {
    await showAlert({
      title: '打开系统文件失败',
      message: result?.message || `暂时无法打开文件：${filePath}`
    })
    return
  }

  await loadCorpusResult(result)
  showToast(`已打开：${result.displayName || result.fileName || filePath}`, {
    title: '已载入',
    type: 'success',
    duration: 2200
  })
}

function enqueueSystemOpenFileRequest(payload) {
  systemOpenRequestQueue = systemOpenRequestQueue
    .then(() => handleSystemOpenFileRequest(payload))
    .catch(error => {
      console.error('[system-open-file-request]', error)
      recordDiagnosticError('system-open-file-request', error, {
        filePath: String(payload?.filePath || '').trim()
      })
    })

  return systemOpenRequestQueue
}

async function openRecentOpenEntry(entry) {
  const normalizedEntry = normalizeRecentOpenEntry(entry)
  if (!normalizedEntry) return

  let result = null
  if (normalizedEntry.type === 'quick') {
    if (!window.electronAPI?.openQuickCorpusAtPath) {
      await showMissingBridge('openQuickCorpusAtPath')
      return
    }
    result = await window.electronAPI.openQuickCorpusAtPath(normalizedEntry.filePath)
  } else if (normalizedEntry.type === 'saved-multi') {
    if (!window.electronAPI?.openSavedCorpora) {
      await showMissingBridge('openSavedCorpora')
      return
    }
    result = await window.electronAPI.openSavedCorpora(normalizedEntry.corpusIds)
  } else {
    if (!window.electronAPI?.openSavedCorpus) {
      await showMissingBridge('openSavedCorpus')
      return
    }
    result = await window.electronAPI.openSavedCorpus(normalizedEntry.corpusId)
  }

  if (!result?.success) {
    recentOpenEntries = recentOpenEntries.filter(item => item.key !== normalizedEntry.key)
    persistRecentOpenEntries()
    renderRecentOpenList()
    await showAlert({
      title: '打开最近语料失败',
      message: result?.message || '该最近打开项目已不可用，已从列表中移除。'
    })
    return
  }

  setOpenCorpusMenuOpen(false)
  await loadCorpusResult(result)
}

function getCommandPaletteCommands() {
  return [
    {
      id: 'quick-open',
      title: '快速打开语料',
      meta: '打开本地 txt / docx / pdf',
      keywords: 'open quick corpus file txt docx pdf',
      run: () => runQuickOpenAction()
    },
    {
      id: 'import-save',
      title: '导入并保存语料',
      meta: '导入并写入本地语料库',
      keywords: 'import save corpus library',
      run: () => runImportAndSaveAction()
    },
    {
      id: 'open-library',
      title: '打开本地语料库',
      meta: '管理分类、回收站、备份与修复',
      keywords: 'library local corpus manage',
      run: () => runOpenLibraryAction()
    },
    {
      id: 'run-stats',
      title: '开始统计',
      meta: '统计词频、Type、TTR、STTR',
      keywords: 'stats frequency token type ttr sttr',
      run: () => enqueueOrRunAnalysisTask({
        type: 'stats',
        title: '统计结果',
        detail: '正在统计词频与词汇指标...',
        run: ({ taskCenterTaskKey }) => executeStatsAnalysis({ taskCenterTaskKey })
      })
    },
    {
      id: 'run-kwic',
      title: '运行 KWIC 检索',
      meta: '按当前 SearchQuery 检索关键词前后文',
      keywords: 'kwic search query concordance',
      run: () => enqueueOrRunAnalysisTask({
        type: 'kwic',
        title: 'KWIC 检索',
        detail: `关键词：${String(currentSearchQuery || '').trim() || '(空)'} · SearchQuery：${getSearchOptionsSummary()}`,
        run: ({ taskCenterTaskKey }) => executeKWICAnalysis({ taskCenterTaskKey })
      })
    },
    {
      id: 'run-collocate',
      title: '运行 Collocate 统计',
      meta: '按当前 SearchQuery 计算搭配词',
      keywords: 'collocate cooccurrence',
      run: () => enqueueOrRunAnalysisTask({
        type: 'collocate',
        title: 'Collocate 统计',
        detail: `节点词：${String(currentSearchQuery || '').trim() || '(空)'} · SearchQuery：${getSearchOptionsSummary()}`,
        run: ({ taskCenterTaskKey }) => executeCollocateAnalysis({ taskCenterTaskKey })
      })
    },
    {
      id: 'run-ngram',
      title: '生成 Ngram',
      meta: '按当前 Ngram 类型统计短语频次',
      keywords: 'ngram phrase',
      run: () => runNgramAnalysis({ switchToTab: true })
    },
    {
      id: 'toggle-queue',
      title: analysisQueuePaused ? '恢复任务队列' : '暂停任务队列',
      meta: analysisQueuePaused ? '继续按顺序自动执行排队任务' : '暂停自动执行，仅保留排队',
      keywords: 'queue pause resume',
      run: async () => {
        analysisQueuePaused = !analysisQueuePaused
        updateAnalysisQueueControls()
        if (!analysisQueuePaused) {
          void runAnalysisQueueIfNeeded()
        }
      }
    },
    {
      id: 'retry-failed',
      title: '重试失败任务',
      meta: analysisQueueFailedItems.length > 0 ? `当前有 ${analysisQueueFailedItems.length} 条失败任务` : '当前没有失败任务',
      keywords: 'queue retry failed',
      run: async () => {
        retryFailedQueueTasks()
      }
    },
    {
      id: 'cancel-queued',
      title: '取消排队任务',
      meta: analysisQueue.length > 0 ? `当前有 ${analysisQueue.length} 条排队任务` : '当前没有排队任务',
      keywords: 'queue cancel clear',
      run: async () => {
        const cancelledCount = cancelQueuedAnalysisTasks('已取消排队任务')
        if (cancelledCount <= 0) {
          showToast('当前没有可取消的排队任务。', { title: '任务队列' })
          return
        }
        showToast(`已取消 ${formatCount(cancelledCount)} 项排队任务。`, {
          title: '队列已清理',
          type: 'success'
        })
      }
    },
    {
      id: 'check-update',
      title: '检查更新',
      meta: '检查 stable 版本更新',
      keywords: 'update',
      run: () => checkUpdateButton?.click()
    },
    {
      id: 'open-settings',
      title: '打开设置',
      meta: '主题、字体、日志、提醒与诊断',
      keywords: 'settings theme font diagnostics',
      run: () => {
        openUISettingsModal()
        void refreshDiagnosticsStatusText()
        void refreshAnalysisCacheState({ silent: true })
      }
    },
    {
      id: 'open-task-center',
      title: taskCenter.isOpen() ? '关闭任务中心' : '打开任务中心',
      meta: '查看任务状态与排队进度',
      keywords: 'task center',
      run: () => {
        taskCenter.setOpen(!taskCenter.isOpen())
        if (taskCenter.isOpen()) {
          clearTaskCenterAttention()
        }
      }
    },
    {
      id: 'open-help',
      title: '打开关于 / 帮助中心',
      meta: '查看版本、说明与发布信息',
      keywords: 'about help',
      run: () => runOpenHelpCenterAction()
    }
  ]
}

function buildSkippedEntriesSummary(skippedEntries = []) {
  if (!Array.isArray(skippedEntries) || skippedEntries.length === 0) return ''
  const lines = skippedEntries.slice(0, 12).map((entry, index) => {
    const sourcePath = String(entry?.sourcePath || '').trim() || '未知路径'
    const reason = String(entry?.reason || '已跳过').trim()
    return `${index + 1}. ${sourcePath}\n原因：${reason}`
  })
  const extraCount = skippedEntries.length - lines.length
  if (extraCount > 0) {
    lines.push(`... 还有 ${formatCount(extraCount)} 条跳过记录`)
  }
  return lines.join('\n\n')
}

function normalizePreflightWarningEntries(result = {}) {
  const warnings = Array.isArray(result?.preflightWarnings)
    ? result.preflightWarnings.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const warningEntries = Array.isArray(result?.preflightWarningEntries)
    ? result.preflightWarningEntries
        .map(entry => {
          const sourcePath = String(entry?.sourcePath || '').trim()
          const entryWarnings = Array.isArray(entry?.warnings)
            ? entry.warnings.map(item => String(item || '').trim()).filter(Boolean)
            : []
          if (!sourcePath || entryWarnings.length === 0) return null
          return { sourcePath, warnings: entryWarnings }
        })
        .filter(Boolean)
    : []
  return {
    warnings,
    warningEntries
  }
}

function buildPreflightWarningsSummary(result = {}) {
  const { warnings, warningEntries } = normalizePreflightWarningEntries(result)
  const lines = []
  if (warnings.length > 0) {
    for (let index = 0; index < Math.min(4, warnings.length); index += 1) {
      lines.push(`${index + 1}. ${warnings[index]}`)
    }
  }
  if (warningEntries.length > 0) {
    const remaining = Math.max(0, 10 - lines.length)
    for (let index = 0; index < Math.min(remaining, warningEntries.length); index += 1) {
      const entry = warningEntries[index]
      lines.push(`${lines.length + 1}. ${entry.sourcePath}\n提示：${entry.warnings.join('；')}`)
    }
  }
  return lines.join('\n\n')
}

async function showPreflightWarnings(result = {}) {
  const normalizedWarnings = normalizePreflightWarningEntries(result)
  const warningCount =
    Number(result?.preflightWarningCount) ||
    normalizedWarnings.warnings.length +
      normalizedWarnings.warningEntries.reduce((sum, entry) => sum + entry.warnings.length, 0)

  if (warningCount <= 0) return

  showToast(`导入前体检给出 ${formatCount(warningCount)} 条提示。`, {
    title: '导入前体检',
    type: 'success',
    duration: 2600
  })

  const warningSummary = buildPreflightWarningsSummary(result)
  if (warningSummary) {
    await showAlert({
      title: '导入前体检提示',
      message: warningSummary
    })
  }
}

async function handleDropImportPaths(paths) {
  if (!window.electronAPI?.importCorpusPaths) {
    await showMissingBridge('importCorpusPaths')
    return
  }

  const droppedPaths = Array.isArray(paths)
    ? [...new Set(paths.map(item => String(item || '').trim()).filter(Boolean))]
    : []
  if (droppedPaths.length === 0) {
    showToast('未检测到可导入的文件或文件夹路径。', {
      title: '拖拽导入'
    })
    return
  }

  dismissFloatingOverlaysForPrimaryAction()
  const endBusyState = beginBusyState('正在导入拖拽语料...')
  setButtonsBusy([openCorpusMenuButton, quickOpenButton, saveImportButton, importToFolderButton], true)
  void setWindowProgressState({
    source: 'drag-import',
    state: 'indeterminate',
    priority: 42
  })
  try {
    const importTargetFolder = getImportTargetFolder()
    const result = await window.electronAPI.importCorpusPaths(droppedPaths, {
      folderId: importTargetFolder.id,
      preserveHierarchy: true
    })
    if (!result?.success) {
      const skippedSummary = buildSkippedEntriesSummary(result?.skippedEntries)
      await showAlert({
        title: '拖拽导入失败',
        message: [
          result?.message || '暂时无法导入拖拽语料',
          skippedSummary ? `\n${skippedSummary}` : ''
        ].join('')
      })
      return
    }

    await loadCorpusResult(result)
    if (!libraryModal.classList.contains('hidden')) {
      await refreshLibraryModal(currentLibraryFolderId)
    }

    const importedCount = Number(result.importedCount) || 1
    const skippedCount = Number(result.skippedCount) || 0
    showToast(
      skippedCount > 0
        ? `已导入 ${formatCount(importedCount)} 条语料，跳过 ${formatCount(skippedCount)} 条。`
        : `已导入 ${formatCount(importedCount)} 条语料。`,
      {
        title: '拖拽导入完成',
        type: 'success',
        duration: 2600
      }
    )

    if (skippedCount > 0) {
      const skippedSummary = buildSkippedEntriesSummary(result?.skippedEntries)
      await showAlert({
        title: '部分路径已跳过',
        message: skippedSummary || `共有 ${formatCount(skippedCount)} 条路径被跳过。`
      })
    }
    void recordDiagnostic('info', 'drag-import', '拖拽导入已完成。', {
      importedCount,
      skippedCount,
      pathCount: droppedPaths.length
    })
  } finally {
    endBusyState()
    setButtonsBusy([openCorpusMenuButton, quickOpenButton, saveImportButton, importToFolderButton], false)
    void setWindowProgressState({
      source: 'drag-import',
      state: 'none'
    })
  }
}

async function handleSystemNotificationAction(payload = {}) {
  const actionId = String(payload?.actionId || '').trim()
  if (!actionId) return

  if (actionId === 'open-stats-tab') {
    switchTab('stats')
    showToast('已从系统通知切换到统计结果。', {
      title: '系统通知'
    })
    return
  }

  if (actionId === 'open-kwic-tab') {
    switchTab('kwic')
    showToast('已从系统通知切换到 KWIC 检索。', {
      title: '系统通知'
    })
    return
  }

  if (actionId === 'open-collocate-tab') {
    switchTab('collocate')
    showToast('已从系统通知切换到 Collocate 统计。', {
      title: '系统通知'
    })
    return
  }

  if (actionId === 'prompt-install-update') {
    await promptInstallDownloadedUpdate(getCurrentAutoUpdateState(), { force: true })
    return
  }

  if (actionId === 'reveal-path') {
    const targetPath = String(payload?.actionPayload?.path || payload?.actionPayload?.filePath || '').trim()
    if (!targetPath || !window.electronAPI?.showPathInFolder) return
    const showResult = await window.electronAPI.showPathInFolder(targetPath)
    if (!showResult?.success) {
      showToast(showResult?.message || '无法在系统文件管理器中打开该路径。', {
        title: '系统通知',
        type: 'error'
      })
    }
  }
}

function buildCrashRecoverySummary(recoveryState) {
  const source = String(recoveryState?.source || 'unknown')
  const errorMessage = String(recoveryState?.error?.message || '未知错误')
  const recordedAt = String(recoveryState?.recordedAt || '')
  return [
    `异常来源：${source}`,
    `异常信息：${errorMessage}`,
    recordedAt ? `记录时间：${recordedAt}` : ''
  ]
    .filter(Boolean)
    .join('\n')
}

async function runCrashRecoveryWizard() {
  if (!window.electronAPI?.consumeCrashRecoveryState) return
  const result = await window.electronAPI.consumeCrashRecoveryState()
  if (!result?.success || !result.recoveryState) return

  const recoveryState = result.recoveryState
  await showAlert({
    title: '检测到上次异常退出',
    message: `${buildCrashRecoverySummary(recoveryState)}\n\n你可以恢复上次会话，或导出诊断并反馈到 GitHub。`
  })

  const workspaceSnapshot = loadStoredWorkspaceSnapshot()
  if (getCurrentUISettings().restoreWorkspace !== false && hasMeaningfulWorkspaceSnapshot(workspaceSnapshot)) {
    const shouldRestore = await showConfirm({
      title: '恢复上次会话',
      message: `${getWorkspaceSnapshotSummary(workspaceSnapshot, { getTabLabel })}\n\n是否立即恢复？`,
      confirmText: '恢复上次会话',
      cancelText: '暂不恢复'
    })
    startupRestoreHandledByCrashWizard = true
    if (shouldRestore) {
      await restoreWorkspaceFromSnapshot(workspaceSnapshot)
    } else {
      void recordDiagnostic('info', 'workspace.restore', '崩溃恢复向导中用户选择暂不恢复上次工作区。')
    }
  }

  const shouldExportDiagnostics = await showConfirm({
    title: '导出诊断报告',
    message: '是否现在导出一份诊断报告，便于定位问题？',
    confirmText: '导出诊断',
    cancelText: '跳过'
  })
  if (shouldExportDiagnostics) {
    if (!window.electronAPI?.exportDiagnosticReport) {
      await showMissingBridge('exportDiagnosticReport')
    } else {
      const exportResult = await window.electronAPI.exportDiagnosticReport(getDiagnosticRendererState())
      if (exportResult?.success) {
        await refreshDiagnosticsStatusText()
        showToast(`诊断报告已导出到：${exportResult.filePath}`, {
          title: '崩溃恢复',
          type: 'success'
        })
        void notifySystem({
          title: '诊断报告已导出',
          body: exportResult.filePath,
          tag: 'diagnostics-export',
          category: 'diagnostics-export',
          action: {
            actionId: 'reveal-path',
            payload: { path: exportResult.filePath }
          }
        })
      } else if (!exportResult?.canceled) {
        await showAlert({
          title: '导出诊断报告失败',
          message: exportResult?.message || '诊断报告导出失败，请稍后重试。'
        })
      }
    }
  }

  const shouldOpenGitHubIssue = await showConfirm({
    title: '反馈到 GitHub',
    message: '是否现在打开 GitHub Issues 反馈页面？系统会自动带上当前会话摘要。',
    confirmText: '打开反馈页面',
    cancelText: '稍后'
  })
  if (shouldOpenGitHubIssue) {
    await openGitHubFeedbackIssue({
      issueTitle: `[Bug][CrashRecovery] ${String(recoveryState?.source || 'unknown crash')}`.slice(0, 120),
      source: 'crash-recovery-wizard'
    })
  }
}

const startupPhaseRunner = createStartupPhaseRunner({
  maxEvents: 100,
  onEvent: event => {
    startupPhaseEvents.push(event)
    while (startupPhaseEvents.length > 100) {
      startupPhaseEvents.shift()
    }
    globalThis.__WORDZ_STARTUP_PHASE_EVENTS__ = startupPhaseEvents.map(item => ({ ...item }))
    if (event.status === 'started' || event.status === 'completed') {
      console.warn(
        '[renderer.startup.phase]',
        event.status,
        event.phase,
        Number(event.durationMs) || 0
      )
    }
    if (event.status === 'failed') {
      console.error('[renderer.startup.phase]', event.phase, event.errorMessage || '')
      void recordDiagnostic('error', 'renderer.startup.phase', `启动阶段失败：${event.phase}`, {
        phase: event.phase,
        durationMs: Number(event.durationMs) || 0,
        errorName: event.errorName || '',
        errorMessage: event.errorMessage || ''
      })
    }
  }
})

writeStartupAppLog('probe-gate.ready', {
  fullProbeMode
})

const startupProbeMode = (() => {
  try {
    const probe = new URLSearchParams(window.location.search || '').get('startupProbe')
    const normalizedProbe = String(probe || '').trim().toLowerCase()
    if (normalizedProbe === 'skip-all' || normalizedProbe === 'skip-deferred') {
      return normalizedProbe
    }
  } catch {
    // ignore invalid probe params
  }
  return ''
})()

const shouldReportRendererReady = !startupProbeMode && !fullProbeMode
let rendererReadyReported = false

function dispatchRendererReadyEvent(stage = 'startup-complete') {
  try {
    window.dispatchEvent(new CustomEvent('wordz:renderer-ready', {
      detail: {
        stage
      }
    }))
    writeStartupAppLog('renderer-ready.dispatched', {
      stage
    })
  } catch (error) {
    console.warn('[renderer.ready.event]', error)
  }
}

async function reportRendererReady(stage = 'startup-complete') {
  if (!shouldReportRendererReady || rendererReadyReported) return
  rendererReadyReported = true
  dispatchRendererReadyEvent(stage)
  if (!window.electronAPI?.reportRendererReady) return
  try {
    await window.electronAPI.reportRendererReady({ stage })
    writeStartupAppLog('renderer-ready.reported', {
      stage
    })
  } catch (error) {
    rendererReadyReported = false
    console.warn('[renderer.ready.report]', error)
  }
}

const shouldSkipSyncStartup = startupProbeMode === 'skip-all'
const shouldSkipDeferredStartup = shouldSkipSyncStartup || startupProbeMode === 'skip-deferred'
globalThis.__WORDZ_STARTUP_PROBE_MODE__ = startupProbeMode

if (startupProbeMode) {
  console.warn('[renderer.startup.probe]', JSON.stringify({
    startupProbeMode,
    skipSyncStartup: shouldSkipSyncStartup,
    skipDeferredStartup: shouldSkipDeferredStartup
  }))
}

let loadedRecentOpenEntries = recentOpenEntries
if (shouldSkipSyncStartup) {
  console.warn('[renderer.startup.probe] sync-startup.skipped', startupProbeMode)
} else {
  ;({ recentOpenEntries: loadedRecentOpenEntries } = runInitialRendererSetup({
    runSyncPhase: startupPhaseRunner.runSyncPhase,
    decorateStaticButtons,
    updateAnalysisActionButtons,
    setPreviewCollapsed,
    taskCenter,
    updateAnalysisQueueControls,
    setOpenCorpusMenuOpen,
    bindDropImportHandlers,
    revealNativeToolbarOverflowForSmoke,
    initUISettings,
    loadRecentOpenEntries: () => loadRecentOpenEntriesFromStorage(localStorage, RECENT_OPEN_STORAGE_KEY),
    renderWorkspaceOverview,
    renderSelectedCorporaTable,
    updateLoadSelectedCorporaButton,
    renderRecentOpenList,
    syncSharedSearchInputs,
    syncSearchOptionInputs,
    syncChiSquareInputsFromState,
    renderCompareSection,
    renderWordCloud,
    renderNgramTable,
    renderChiSquareResult,
    applyAppInfoToShell,
    applyAutoUpdateButtonState,
    syncWelcomePreferenceCheckboxes,
    refreshDiagnosticsStatusText,
    refreshAnalysisCacheState,
    shouldShowFirstRunTutorial: () => shouldShowFirstRunTutorial(onboardingState),
    showWelcomeOverlay,
    setWelcomeProgress,
    recordRendererInitialized: (settings) => {
      void recordDiagnostic('info', 'app', 'Renderer 已完成初始化。', {
        tab: currentTab,
        showWelcomeScreen: settings.showWelcomeScreen !== false,
        startupProbeMode
      })
    }
  }))
  recentOpenEntries = loadedRecentOpenEntries
}

if (window.electronAPI?.onSystemOpenFileRequest) {
  window.electronAPI.onSystemOpenFileRequest(payload => {
    void enqueueSystemOpenFileRequest(payload)
  })
}

if (window.electronAPI?.onAppMenuAction) {
  window.electronAPI.onAppMenuAction(payload => {
    void handleAppMenuAction(payload).catch(error => {
      console.error('[app-menu-action]', error)
      recordDiagnosticError('app-menu-action', error, {
        action: String(payload?.action || '').trim()
      })
    })
  })
}

if (window.electronAPI?.onSystemNotificationAction) {
  window.electronAPI.onSystemNotificationAction(payload => {
    void handleSystemNotificationAction(payload).catch(error => {
      console.error('[system-notification-action]', error)
      recordDiagnosticError('system-notification-action', error, {
        actionId: String(payload?.actionId || '').trim()
      })
    })
  })
}

window.addEventListener('error', event => {
  const errorDetails = {
    filename: event.filename || '',
    lineno: event.lineno || 0,
    colno: event.colno || 0
  }
  const normalizedError = recordDiagnosticError(
    'renderer.error',
    event.error || new Error(event.message || '未捕获错误'),
    errorDetails
  )
  void maybePromptAutoBugFeedback('renderer.error', normalizedError, errorDetails)
})

window.addEventListener('unhandledrejection', event => {
  const rejectionError =
    event.reason instanceof Error ? event.reason : new Error(String(event.reason || '未处理 Promise 拒绝'))
  const rejectionDetails = {
    reason: event.reason instanceof Error ? event.reason.message : String(event.reason || '')
  }
  const normalizedError = recordDiagnosticError(
    'renderer.unhandledrejection',
    rejectionError,
    rejectionDetails
  )
  void maybePromptAutoBugFeedback('renderer.unhandledrejection', normalizedError, rejectionDetails)
})

const deferredStartupPromise = shouldSkipDeferredStartup
  ? Promise.resolve().then(() => {
      console.warn('[renderer.startup.probe] deferred-startup.skipped', startupProbeMode || 'skip')
    })
  : runDeferredRendererStartup({
      runPhase: startupPhaseRunner.runPhase,
      setWelcomeProgress,
      ensureAppInfoLoaded,
      consumePendingSystemOpenFiles: async () => {
        if (!window.electronAPI?.consumePendingSystemOpenFiles) return
        const pendingOpenResult = await window.electronAPI.consumePendingSystemOpenFiles()
        if (!pendingOpenResult?.success || !Array.isArray(pendingOpenResult.filePaths)) return
        for (const filePath of pendingOpenResult.filePaths) {
          await enqueueSystemOpenFileRequest({ filePath })
        }
      },
      initializeAutoUpdate,
      runCrashRecoveryWizard,
      maybeRestoreWorkspaceOnStartup: async () => {
        if (getCurrentUISettings().restoreWorkspace === false || startupRestoreHandledByCrashWizard) return
        const workspaceSnapshot = loadStoredWorkspaceSnapshot()
        if (!hasMeaningfulWorkspaceSnapshot(workspaceSnapshot)) return
        const shouldRestoreWorkspace = await requestWorkspaceRestoreDecision(workspaceSnapshot)
        if (shouldRestoreWorkspace) {
          setWelcomeProgress(76, '正在恢复上次工作区...', '正在连接上次分析状态')
          await restoreWorkspaceFromSnapshot(workspaceSnapshot)
          return
        }
        void recordDiagnostic('info', 'workspace.restore', '用户选择跳过恢复上次工作区。', {
          snapshotCorpusCount: workspaceSnapshot?.workspace?.corpusIds?.length || 0
        })
      },
      markWorkspaceSnapshotReady: () => {
        workspaceSnapshotReady = true
      },
      scheduleWorkspaceSnapshotSave,
      waitForNextFrame: () => new Promise(resolve => requestAnimationFrame(() => resolve())),
      markWelcomeReady
    })

void deferredStartupPromise
  .then(async () => {
    try {
      await maybeRunPackagedSmokeAutorun()
      if (shouldReportRendererReady) {
        await new Promise(resolve => {
          window.setTimeout(resolve, 3000)
        })
        await new Promise(resolve => requestAnimationFrame(() => resolve()))
        await reportRendererReady('deferred-startup-complete')
      }
    } catch (error) {
      console.error('[packaged-smoke.autorun]', error)
      recordDiagnosticError('smoke.packaged', error)
    }
  })
  .catch(error => {
  const normalizedError = recordDiagnosticError('renderer.startup.flow', error)
  void maybePromptAutoBugFeedback('renderer.startup.flow', normalizedError, {
    startupPhases: startupPhaseEvents.slice(-12)
  })
})

previewToggleButton?.addEventListener('click', () => {
  const isCollapsed = previewPanelBody?.classList.contains('hidden')
  setPreviewCollapsed(!isCollapsed)
})

dom.closeWelcomeButton?.addEventListener('click', () => {
  if (!isWelcomeReady()) return
  const shouldShowWelcome = !(dom.welcomeDisableCheckbox?.checked)
  if (isWelcomeTutorialVisible()) {
    onboardingState = markOnboardingTutorialCompleted(localStorage, ONBOARDING_STORAGE_KEY, onboardingState)
  }
  applyUISettings({
    ...getCurrentUISettings(),
    showWelcomeScreen: shouldShowWelcome
  })
  syncWelcomePreferenceCheckboxes()
  hideWelcomeOverlay({ immediate: true })
})

restoreWorkspaceButton?.addEventListener('click', () => {
  if (!hasPendingWorkspaceRestoreSnapshot()) return
  resolveStartupRestoreDecision(true)
})

skipWorkspaceRestoreButton?.addEventListener('click', () => {
  if (!hasPendingWorkspaceRestoreSnapshot()) return
  resolveStartupRestoreDecision(false)
})

dom.welcomeDisableCheckbox?.addEventListener('change', () => {
  const shouldShowWelcome = !dom.welcomeDisableCheckbox.checked
  applyUISettings({
    ...getCurrentUISettings(),
    showWelcomeScreen: shouldShowWelcome
  })
  syncWelcomePreferenceCheckboxes()
})
bindShellInteractionHandlers()

checkUpdateButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.checkForUpdates) {
    await showMissingBridge('checkForUpdates')
    return
  }

  const currentAutoUpdateState = getCurrentAutoUpdateState()
  if (currentAutoUpdateState?.state === 'downloaded') {
    await promptInstallDownloadedUpdate(currentAutoUpdateState, { force: true })
    return
  }

  const result = await window.electronAPI.checkForUpdates()
  if (!result.success) {
    await showAlert({
      title: result.disabled ? '自动更新暂不可用' : '检查更新失败',
      message: result.message || '当前无法检查更新'
    })
    return
  }

  if (result.busy) {
    showToast(result.message || '更新任务已经在进行中。', {
      title: '自动更新'
    })
    return
  }

  if (result.state === 'up-to-date') {
    showToast(result.message || '当前已是最新版本。', {
      title: '检查完成',
      type: 'success'
    })
    return
  }

  if (result.state === 'checking') {
    showToast('正在检查更新...', {
      title: '自动更新'
    })
  }
})

aboutButton?.addEventListener('click', async () => {
  await ensureAppInfoLoaded()
  openHelpCenterModal()
})

reopenTutorialButton?.addEventListener('click', () => {
  closeHelpCenterModal()
  showWelcomeOverlay({ force: true, tutorialMode: true, manualTutorial: true })
})

openGitHubRepoButton?.addEventListener('click', async () => {
  if (!currentAppInfo.repositoryUrl) {
    await showAlert({
      title: 'GitHub 地址未配置',
      message: '当前版本没有可打开的 GitHub 仓库地址。'
    })
    return
  }

  if (!window.electronAPI?.openExternalUrl) {
    await showMissingBridge('openExternalUrl')
    return
  }

  const result = await window.electronAPI.openExternalUrl(currentAppInfo.repositoryUrl)
  if (!result?.success) {
    await showAlert({
      title: '打开 GitHub 失败',
      message: result?.message || '暂时无法打开 GitHub 仓库地址。'
    })
    return
  }

  showToast('已打开 GitHub 仓库页面。', {
    title: '帮助中心',
    type: 'success'
  })
})

closeHelpCenterButton?.addEventListener('click', () => {
  closeHelpCenterModal()
})

taskCenterButton?.addEventListener('click', () => {
  taskCenter.setOpen(!taskCenter.isOpen())
  if (taskCenter.isOpen()) {
    clearTaskCenterAttention()
  }
})

closeTaskCenterButton?.addEventListener('click', () => {
  taskCenter.setOpen(false)
})

queueToggleButton?.addEventListener('click', () => {
  analysisQueuePaused = !analysisQueuePaused
  updateAnalysisQueueControls()
  if (!analysisQueuePaused) {
    void runAnalysisQueueIfNeeded()
  }
})

retryFailedTaskButton?.addEventListener('click', () => {
  retryFailedQueueTasks()
})

cancelQueuedTaskButton?.addEventListener('click', () => {
  const cancelledCount = cancelQueuedAnalysisTasks('已取消排队任务')
  if (cancelledCount <= 0) {
    showToast('当前没有可取消的排队任务。', {
      title: '任务队列'
    })
    return
  }
  showToast(`已取消 ${formatCount(cancelledCount)} 项排队任务。`, {
    title: '队列已清理',
    type: 'success'
  })
})

document.addEventListener('click', event => {
  const target = event.target
  if (!(target instanceof Node)) return
  if (taskCenter.isOpen() && taskCenterPanel && taskCenterButton) {
    if (!taskCenterPanel.contains(target) && !taskCenterButton.contains(target)) {
      taskCenter.setOpen(false)
    }
  }
})

document.addEventListener('keydown', event => {
  if (
    event.key === 'Escape' &&
    recycleModal &&
    !recycleModal.classList.contains('hidden') &&
    feedbackModal?.classList.contains('hidden')
  ) {
    closeRecycleModal()
    return
  }
  if (event.key === 'Escape' && helpCenterModal && !helpCenterModal.classList.contains('hidden')) {
    closeHelpCenterModal()
    return
  }
  if (event.key === 'Escape' && taskCenter.isOpen()) {
    taskCenter.setOpen(false)
  }
})

document.addEventListener('visibilitychange', () => {
  if (!document.hidden && pendingTaskAttentionCount > 0) {
    clearTaskCenterAttention()
  }
})

window.addEventListener('focus', () => {
  if (pendingTaskAttentionCount > 0) {
    clearTaskCenterAttention()
  }
})

helpCenterModal?.addEventListener('click', (event) => {
  if (event.target === helpCenterModal) closeHelpCenterModal()
})

uiSettingsButton.addEventListener('click', () => {
  openUISettingsModal()
  void refreshDiagnosticsStatusText()
  void refreshAnalysisCacheState({ silent: true })
})

closeUiSettingsButton.addEventListener('click', () => {
  closeUISettingsModal()
})

resetUiSettingsButton.addEventListener('click', () => {
  applyUISettings(DEFAULT_UI_SETTINGS)
  applyTheme(DEFAULT_THEME)
  syncWelcomePreferenceCheckboxes()
  void refreshDiagnosticsStatusText()
})

lightThemeButton.addEventListener('click', () => {
  applyTheme('light')
})

darkThemeButton.addEventListener('click', () => {
  applyTheme('dark')
})

systemThemeButton?.addEventListener('click', () => {
  applyTheme('system')
})

uiZoomRange.addEventListener('input', () => {
  applyUISettingsFromControls()
})

uiFontSizeRange.addEventListener('input', () => {
  applyUISettingsFromControls()
})

uiFontFamilySelect.addEventListener('change', () => {
  applyUISettingsFromControls()
  syncWelcomePreferenceCheckboxes()
})

dom.showWelcomeScreenToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  syncWelcomePreferenceCheckboxes()
  void refreshDiagnosticsStatusText()
  if (getCurrentUISettings().showWelcomeScreen === false) {
    hideWelcomeOverlay({ immediate: true })
  }
})

restoreWorkspaceToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  if (restoreWorkspaceToggle.checked) {
    scheduleWorkspaceSnapshotSave({ immediate: true })
  }
})

debugLoggingToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  void refreshDiagnosticsStatusText()
  void recordDiagnostic('info', 'diagnostics', debugLoggingToggle.checked ? '用户已开启调试日志。' : '用户已关闭调试日志。')
})

windowAttentionToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  if (windowAttentionToggle.checked) {
    void recordDiagnostic('info', 'window-attention', '用户已开启 Dock/任务栏提醒。')
    return
  }
  clearAllWindowAttention()
  void recordDiagnostic('info', 'window-attention', '用户已关闭 Dock/任务栏提醒。')
})

followSystemAccessibilityToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  void recordDiagnostic(
    'info',
    'ui.accessibility',
    followSystemAccessibilityToggle.checked ? '用户已开启系统可访问性跟随。' : '用户已关闭系统可访问性跟随。'
  )
})

notifyAnalysisCompleteToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  applyReminderCategoryChange('analysis-complete', notifyAnalysisCompleteToggle.checked)
})

notifyUpdateDownloadedToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  applyReminderCategoryChange('update-downloaded', notifyUpdateDownloadedToggle.checked)
})

notifyDiagnosticsExportToggle?.addEventListener('change', () => {
  applyUISettingsFromControls()
  applyReminderCategoryChange('diagnostics-export', notifyDiagnosticsExportToggle.checked)
})

resetWindowsCompatButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.resetWindowsCompatProfile) {
    await showMissingBridge('resetWindowsCompatProfile')
    return
  }

  const result = await window.electronAPI.resetWindowsCompatProfile()
  if (!result?.success) {
    await showAlert({
      title: '重置 Windows 兼容模式失败',
      message: result?.message || '兼容模式状态重置失败，请稍后重试。'
    })
    return
  }

  await refreshDiagnosticsStatusText()
  void recordDiagnostic('info', 'diagnostics', '用户已重置 Windows 兼容模式。')
  showToast('Windows 兼容模式已重置。下次启动会从标准模式开始。', {
    title: '已重置',
    type: 'success',
    duration: 2600
  })
})

exportDiagnosticsButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.exportDiagnosticReport) {
    await showMissingBridge('exportDiagnosticReport')
    return
  }

  void setWindowProgressState({
    source: 'diagnostics-export',
    state: 'indeterminate',
    priority: 30
  })
  const result = await window.electronAPI.exportDiagnosticReport(getDiagnosticRendererState())
  if (!result || !result.success) {
    void setWindowProgressState({
      source: 'diagnostics-export',
      state: 'none'
    })
    if (result?.canceled) {
      showToast('已取消导出诊断报告。', {
        title: '未导出'
      })
      return
    }
    await showAlert({
      title: '导出诊断报告失败',
      message: result?.message || '诊断报告导出失败，请稍后重试。'
    })
    return
  }

  await refreshDiagnosticsStatusText()
  void recordDiagnostic('info', 'diagnostics', '用户已导出诊断报告。', { filePath: result.filePath })
  showToast(`诊断报告已导出到：${result.filePath}`, {
    title: '导出完成',
    type: 'success',
    duration: 2600
  })
  void setWindowProgressState({
    source: 'diagnostics-export',
    state: 'none'
  })
  void notifySystem({
    title: '诊断报告已导出',
    body: result.filePath,
    tag: 'diagnostics-export',
    category: 'diagnostics-export',
    action: {
      actionId: 'reveal-path',
      payload: { path: result.filePath }
    }
  })
})

reportIssueButton?.addEventListener('click', async () => {
  await openGitHubFeedbackIssue({
    issueTitle: '[Bug] 请简要描述问题',
    source: 'manual',
    autoExportDiagnostics: true,
    successMessage: '已打开 GitHub Issues，并自动附带当前会话诊断包路径。'
  })
})

refreshAnalysisCacheButton?.addEventListener('click', () => {
  void refreshAnalysisCacheState()
})

rebuildAnalysisCacheButton?.addEventListener('click', () => {
  void rebuildCurrentAnalysisCache()
})

clearAnalysisCacheButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.clearAnalysisCache) {
    await showMissingBridge('clearAnalysisCache')
    return
  }

  const confirmed = await showConfirm({
    title: '清空分析缓存',
    message: '这会清空全部统计缓存，下一次统计会重新计算。确定继续吗？',
    confirmText: '清空缓存',
    cancelText: '取消'
  })
  if (!confirmed) return

  const result = await window.electronAPI.clearAnalysisCache()
  if (!result?.success) {
    await showAlert({
      title: '清空缓存失败',
      message: result?.message || '当前无法清空分析缓存。'
    })
    return
  }

  currentAnalysisCachePayload = normalizeAnalysisCachePayload({
    schemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
    analysisMode: currentAnalysisMode,
    corpusData:
      currentAnalysisMode === 'segmented'
        ? { sentences: [], tokenObjects: [], tokens: [] }
        : {
            sentences: currentSentenceObjects,
            tokenObjects: currentTokenObjects,
            tokens: currentTokens
          },
    stats: null,
    ngrams: {}
  })
  showToast(`已清空 ${formatCount(result.removedCount || 0)} 条缓存。`, {
    title: '缓存已清理',
    type: 'success'
  })
  await refreshAnalysisCacheState({ silent: true })
})

uiSettingsModal.addEventListener('click', (event) => {
  if (event.target === uiSettingsModal) closeUISettingsModal()
})

selectSavedCorporaButton?.addEventListener('click', async () => {
  syncLibrarySelectionWithCurrentCorpora()
  await openLibraryModal('all')
})

closeLibraryButton.addEventListener('click', () => {
  closeLibraryModal()
})

libraryModal.addEventListener('click', (event) => {
  if (event.target === libraryModal) closeLibraryModal()
})

createFolderButton.addEventListener('click', async () => {
  const folderName = await promptForName({
    title: '新建文件夹',
    message: '请输入新文件夹名称。',
    placeholder: '例如：毕业论文语料',
    confirmText: '创建',
    label: '文件夹名称'
  })
  if (folderName === null) return

  const result = await window.electronAPI.createCorpusFolder(folderName)
  if (!result.success) {
    await showAlert({
      title: '创建文件夹失败',
      message: result.message || '创建文件夹失败'
    })
    return
  }

  await refreshLibraryModal(result.folder.id)
})

importToFolderButton.addEventListener('click', async () => {
  if (!window.electronAPI?.importAndSaveCorpus) {
    await showMissingBridge('importAndSaveCorpus')
    return
  }

  const result = await window.electronAPI.importAndSaveCorpus(getImportTargetFolder().id)
  await loadCorpusResult(result)
  await refreshLibraryModal(currentLibraryFolderId)
})

loadSelectedCorporaButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.openSavedCorpora) {
    await showMissingBridge('openSavedCorpora')
    return
  }

  if (selectedLibraryCorpusIds.size === 0) {
    showToast('请先勾选至少一条已保存语料。', {
      title: '未选择语料'
    })
    return
  }

  const result = await window.electronAPI.openSavedCorpora([...selectedLibraryCorpusIds])
  if (!result.success) {
    await showAlert({
      title: '载入语料失败',
      message: result.message || '无法载入选中的语料'
    })
    return
  }

  closeLibraryModal()
  await loadCorpusResult(result)
})

recycleBinButton?.addEventListener('click', async () => {
  await openRecycleModal()
})

closeRecycleButton?.addEventListener('click', () => {
  closeRecycleModal()
})

recycleModal?.addEventListener('click', event => {
  if (event.target === recycleModal) closeRecycleModal()
})

backupLibraryButton.addEventListener('click', async () => {
  if (!window.electronAPI?.backupCorpusLibrary) {
    await showMissingBridge('backupCorpusLibrary')
    return
  }

  const endBusyState = beginBusyState('正在创建语料库备份...')
  setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
  void setWindowProgressState({
    source: 'library-maintenance',
    state: 'indeterminate',
    priority: 35
  })
  try {
    const result = await window.electronAPI.backupCorpusLibrary()
    if (!result.success) {
      if (result.canceled) {
        showToast('已取消备份位置选择', { title: '未创建备份' })
        return
      }
      await showAlert({
        title: '备份失败',
        message: result.message || '创建语料库备份失败'
      })
      return
    }

    await showAlert({
      title: '备份完成',
      message: buildBackupSummaryMessage(result)
    })
    void notifySystem({
      title: '语料库备份完成',
      body: result.backupPath || '本地语料库备份已创建完成。',
      tag: 'library-backup'
    })
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
    void setWindowProgressState({
      source: 'library-maintenance',
      state: 'none'
    })
  }
})

restoreLibraryButton.addEventListener('click', async () => {
  if (!window.electronAPI?.restoreCorpusLibrary) {
    await showMissingBridge('restoreCorpusLibrary')
    return
  }

  const confirmed = await showConfirm({
    title: '恢复本地语料库',
    message: '这会用一个备份目录替换当前本地语料库。恢复前会自动保留当前语料库快照，便于回退。是否继续？',
    confirmText: '选择备份并恢复',
    cancelText: '取消'
  })
  if (!confirmed) return

  const endBusyState = beginBusyState('正在从备份恢复语料库...')
  setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
  void setWindowProgressState({
    source: 'library-maintenance',
    state: 'indeterminate',
    priority: 35
  })
  try {
    const result = await window.electronAPI.restoreCorpusLibrary()
    if (!result.success) {
      if (result.canceled) {
        showToast('已取消备份目录选择', { title: '未恢复语料库' })
        return
      }
      await showAlert({
        title: '恢复失败',
        message: result.message || '恢复语料库失败'
      })
      return
    }

    await refreshLibraryModal(currentLibraryFolderId)
    await showAlert({
      title: '恢复完成',
      message: buildRestoreSummaryMessage(result)
    })
    void notifySystem({
      title: '语料库恢复完成',
      body: result.restoredFrom || '本地语料库已从备份恢复完成。',
      tag: 'library-restore'
    })
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
    void setWindowProgressState({
      source: 'library-maintenance',
      state: 'none'
    })
  }
})

repairLibraryButton.addEventListener('click', async () => {
  if (!window.electronAPI?.repairCorpusLibrary) {
    await showMissingBridge('repairCorpusLibrary')
    return
  }

  const confirmed = await showConfirm({
    title: '修复本地语料库',
    message: '这会检查语料库结构，自动补回缺失元数据，并把异常目录移动到隔离区。是否继续？',
    confirmText: '开始修复',
    cancelText: '取消'
  })
  if (!confirmed) return

  const endBusyState = beginBusyState('正在检查并修复本地语料库...')
  setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], true)
  void setWindowProgressState({
    source: 'library-maintenance',
    state: 'indeterminate',
    priority: 35
  })
  try {
    const result = await window.electronAPI.repairCorpusLibrary()
    if (!result.success) {
      await showAlert({
        title: '修复失败',
        message: result.message || '语料库修复失败'
      })
      return
    }

    await refreshLibraryModal(currentLibraryFolderId)
    await showAlert({
      title: '修复完成',
      message: buildRepairSummaryMessage(result)
    })
    void notifySystem({
      title: '语料库修复完成',
      body: `已修复 ${formatCount(result.repairedCorpusCount || 0)} 条语料，隔离 ${formatCount(result.quarantinedEntryCount || 0)} 个异常项目。`,
      tag: 'library-repair'
    })
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
    void setWindowProgressState({
      source: 'library-maintenance',
      state: 'none'
    })
  }
})

libraryFolderList.addEventListener('click', async (event) => {
  const folderButton = event.target.closest('[data-library-folder-id]')
  const renameFolderButton = event.target.closest('[data-rename-folder-id]')
  const deleteFolderButton = event.target.closest('[data-delete-folder-id]')

  if (folderButton) {
    await refreshLibraryModal(folderButton.dataset.libraryFolderId)
    return
  }

  if (renameFolderButton) {
    const folderId = renameFolderButton.dataset.renameFolderId
    const currentName = renameFolderButton.dataset.currentFolderName || ''
    const newName = await promptForName({
      title: '重命名文件夹',
      message: '请输入新的文件夹名称。',
      defaultValue: currentName,
      placeholder: '请输入文件夹名称',
      confirmText: '保存',
      label: '文件夹名称'
    })
    if (newName === null) return

    const result = await window.electronAPI.renameCorpusFolder(folderId, newName)
    if (!result.success) {
      await showAlert({
        title: '重命名文件夹失败',
        message: result.message || '重命名文件夹失败'
      })
      return
    }

    if (currentCorpusMode === 'saved' && currentCorpusFolderId === folderId) {
      currentCorpusFolderName = result.folder.name
      updateCurrentCorpusInfo()
    }
    patchCurrentSelectedCorpora(
      item => item.folderId === folderId,
      item => ({ ...item, folderName: result.folder.name })
    )

    await refreshLibraryModal(currentLibraryFolderId)
    return
  }

  if (deleteFolderButton) {
    const folderId = deleteFolderButton.dataset.deleteFolderId
    const folderName = deleteFolderButton.dataset.folderName || '该文件夹'
    const confirmed = await showConfirm({
      title: '删除文件夹',
      message: `删除文件夹「${folderName}」后，它和里面的语料会先移入回收站，你之后仍可恢复。是否继续？`,
      confirmText: '移入回收站',
      cancelText: '取消',
      danger: true
    })
    if (!confirmed) return

    const result = await window.electronAPI.deleteCorpusFolder(folderId)
    if (!result.success) {
      await showAlert({
        title: '删除文件夹失败',
        message: result.message || '删除文件夹失败'
      })
      return
    }

    removeCurrentSelectedCorpora(item => item.folderId === folderId)

    await refreshLibraryModal(currentLibraryFolderId)
    if (!recycleModal.classList.contains('hidden')) {
      await refreshRecycleBinModal()
    }
    showToast(`文件夹「${folderName}」已移入回收站。`, {
      title: '可恢复删除',
      type: 'success'
    })
  }
})

bindLibraryTableEvents({
  libraryTableWrapper,
  recycleTableWrapper,
  getSelectedLibraryCorpusIds: () => selectedLibraryCorpusIds,
  updateLoadSelectedCorporaButton,
  updateLibraryMetaText,
  closeLibraryModal,
  loadCorpusResult,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  promptForName,
  electronAPI: window.electronAPI,
  getCurrentCorpusId: () => currentCorpusId,
  setCurrentCorpusDisplayName: name => {
    currentCorpusDisplayName = name
  },
  setCurrentCorpusFolder: (folderId, folderName) => {
    currentCorpusFolderId = folderId
    currentCorpusFolderName = folderName
  },
  updateCurrentCorpusInfo,
  patchCurrentSelectedCorpora,
  removeCurrentSelectedCorpora,
  getCurrentLibraryFolderId: () => currentLibraryFolderId,
  refreshLibraryModal,
  refreshRecycleBinModal,
  isRecycleModalVisible: () => !recycleModal.classList.contains('hidden'),
  isLibraryModalVisible: () => !libraryModal.classList.contains('hidden')
})

function ensureTaskCenterRunningEntry(taskKey, title, detail) {
  if (!taskKey) return
  if (!taskCenter.promoteQueuedEntry(taskKey, detail)) {
    taskCenter.startEntryWithStatus(taskKey, title, detail, 'running')
  }
}

function inferTaskTypeFromTaskCenterEntry(entry) {
  const taskKey = String(entry?.taskKey || '')
  if (taskKey.includes('stats')) return 'stats'
  if (taskKey.includes('kwic')) return 'kwic'
  if (taskKey.includes('collocate')) return 'collocate'
  return ''
}

function formatEstimatedDuration(durationMs) {
  const safeDuration = Math.max(0, Number(durationMs) || 0)
  if (safeDuration < 1000) return '<1s'
  if (safeDuration < 60000) return `${Math.round(safeDuration / 1000)}s`
  const minutes = Math.floor(safeDuration / 60000)
  const seconds = Math.round((safeDuration % 60000) / 1000)
  return `${minutes}m ${seconds}s`
}

function estimateAnalysisQueueDurationMs() {
  if (analysisQueue.length === 0) return 0
  const completedEntries = taskCenter
    .getEntries()
    .filter(entry => entry.status === 'success' && Number(entry.durationMs) > 0)
  const durationBuckets = {
    stats: [],
    kwic: [],
    collocate: []
  }
  for (const entry of completedEntries) {
    const taskType = inferTaskTypeFromTaskCenterEntry(entry)
    if (!taskType || !durationBuckets[taskType]) continue
    durationBuckets[taskType].push(Number(entry.durationMs) || 0)
  }

  const fallbackDurationByTaskType = {
    stats: 3500,
    kwic: 4800,
    collocate: 5200
  }
  let totalEstimatedMs = 0
  for (const task of analysisQueue) {
    const taskType = String(task?.type || '').trim()
    const bucket = durationBuckets[taskType] || []
    const averageDuration = bucket.length > 0
      ? bucket.reduce((sum, value) => sum + value, 0) / bucket.length
      : (fallbackDurationByTaskType[taskType] || 4000)
    totalEstimatedMs += averageDuration
  }
  return Math.max(0, totalEstimatedMs)
}

function retryFailedQueueTasks() {
  if (analysisQueueFailedItems.length === 0) {
    showToast('当前没有失败任务可重试。', {
      title: '任务队列'
    })
    return 0
  }

  const failedTasks = analysisQueueFailedItems.slice()
  analysisQueueFailedItems = []
  for (const task of failedTasks.reverse()) {
    const queueTaskKey = `queue-${task.type}-${++analysisQueueSeq}`
    const detail = `${task.detail}（重试）`
    analysisQueue.push({
      type: task.type,
      title: task.title,
      detail,
      queueTaskKey,
      run: task.run
    })
    taskCenter.startEntryWithStatus(queueTaskKey, task.title, detail, 'queued')
  }
  updateAnalysisQueueControls()
  if (!analysisQueuePaused) {
    void runAnalysisQueueIfNeeded()
  }
  return failedTasks.length
}

function cancelQueuedAnalysisTasks(detail = '已取消排队任务') {
  const queuedCount = analysisQueue.length
  analysisQueue = []
  const cancelledCount = taskCenter.cancelQueuedEntries(detail)
  updateAnalysisQueueControls()
  return Math.max(queuedCount, cancelledCount)
}

function updateAnalysisQueueControls() {
  const queuedCount = analysisQueue.length
  const failedCount = analysisQueueFailedItems.length

  if (cancelQueuedTaskButton) {
    cancelQueuedTaskButton.disabled = queuedCount === 0
    setButtonLabel(
      cancelQueuedTaskButton,
      queuedCount > 0 ? `取消排队任务（${queuedCount}）` : '取消排队任务'
    )
  }
  if (queueToggleButton) {
    const label = analysisQueuePaused ? '恢复队列' : '暂停队列'
    setButtonLabel(queueToggleButton, label)
    queueToggleButton.disabled = !analysisQueuePaused && queuedCount === 0 && !analysisQueueRunning
  }
  if (retryFailedTaskButton) {
    retryFailedTaskButton.disabled = failedCount === 0
    setButtonLabel(
      retryFailedTaskButton,
      failedCount > 0 ? `重试失败任务（${failedCount}）` : '重试失败任务'
    )
  }
  if (queuedCount > 0) {
    const etaMs = estimateAnalysisQueueDurationMs()
    taskCenter.setMetaSuffix(`预计排队耗时 ${formatEstimatedDuration(etaMs)}`)
  } else {
    taskCenter.setMetaSuffix('')
  }
}

function appendFailedQueueTask(task, status = 'failed') {
  if (!task) return
  analysisQueueFailedItems = [
    {
      type: task.type,
      title: task.title,
      detail: task.detail,
      run: task.run,
      status,
      failedAt: Date.now()
    },
    ...analysisQueueFailedItems
  ].slice(0, MAX_ANALYSIS_QUEUE_LENGTH)
}

async function runAnalysisQueueIfNeeded() {
  if (analysisQueuePaused || analysisQueueRunning || activeCancelableAnalysis) return
  const nextTask = analysisQueue.shift()
  if (!nextTask) {
    updateAnalysisQueueControls()
    return
  }

  analysisQueueRunning = true
  updateAnalysisQueueControls()
  ensureTaskCenterRunningEntry(nextTask.queueTaskKey, nextTask.title, nextTask.detail)

  try {
    const status = await nextTask.run({
      taskCenterTaskKey: nextTask.queueTaskKey,
      fromQueue: true
    })
    if (status === 'failed') {
      appendFailedQueueTask(nextTask, status)
    }
  } catch (error) {
    appendFailedQueueTask(nextTask, 'failed')
    finishTaskEntryWithAttention(
      nextTask.queueTaskKey,
      nextTask.title,
      'failed',
      getErrorMessage(error, '队列任务执行失败'),
      'analysis-complete'
    )
    recordDiagnosticError('analysis.queue.run', error, { type: nextTask.type })
  } finally {
    analysisQueueRunning = false
    updateAnalysisQueueControls()
    if (!analysisQueuePaused && analysisQueue.length > 0) {
      void runAnalysisQueueIfNeeded()
    }
  }
}

async function enqueueOrRunAnalysisTask({ type, title, detail, run }) {
  if (!type || typeof run !== 'function') return 'failed'
  if (!analysisQueuePaused && !analysisQueueRunning && !activeCancelableAnalysis && analysisQueue.length === 0) {
    return run({ taskCenterTaskKey: type, fromQueue: false })
  }

  if (analysisQueue.length >= MAX_ANALYSIS_QUEUE_LENGTH) {
    await showAlert({
      title: '任务队列已满',
      message: `当前最多允许排队 ${MAX_ANALYSIS_QUEUE_LENGTH} 项，请先等待部分任务完成。`
    })
    return 'failed'
  }

  const queueTaskKey = `queue-${type}-${++analysisQueueSeq}`
  const queuedTask = {
    type,
    title,
    detail,
    queueTaskKey,
    run
  }
  analysisQueue.push(queuedTask)
  taskCenter.startEntryWithStatus(queueTaskKey, title, detail, 'queued')
  updateAnalysisQueueControls()
  showToast(`${title} 已加入任务队列。`, {
    title: analysisQueuePaused ? '队列已暂停' : '已排队',
    duration: 1800
  })
  if (!analysisQueuePaused) {
    void runAnalysisQueueIfNeeded()
  }
  return 'queued'
}

async function executeStatsAnalysis({ taskCenterTaskKey = 'stats' } = {}) {
  if (!currentText.trim()) {
    if (taskCenterTaskKey !== 'stats') {
      finishTaskEntryWithAttention(taskCenterTaskKey, '统计结果', 'failed', '缺少语料', 'analysis-complete')
    }
    await showAlert({
      title: '缺少语料',
      message: '请先导入一个 txt / docx / pdf 文件'
    })
    return 'failed'
  }

  const runId = nextAnalysisRun('stats')
  const endBusyState = beginBusyState('正在统计词频与词汇指标...')
  beginCancelableAnalysis('stats')
  void setWindowProgressState({
    source: 'analysis',
    state: 'indeterminate',
    priority: 40
  })
  activeTaskCenterTaskKeys.stats = taskCenterTaskKey
  ensureTaskCenterRunningEntry(taskCenterTaskKey, '统计结果', '正在统计词频与词汇指标...')
  try {
    const segmentedMode = currentAnalysisMode === 'segmented'
    const shouldCompareAcrossCorpora = currentComparisonEntries.length >= 2
    const compareSignature = shouldCompareAcrossCorpora
      ? buildComparisonSignature(currentComparisonEntries)
      : 'none'
    const cachedStats = normalizeCachedStats(currentAnalysisCachePayload?.stats)
    const canUseCachedStats =
      cachedStats &&
      Array.isArray(cachedStats.freqRows) &&
      cachedStats.compareSignature === compareSignature

    const statsResult = canUseCachedStats
      ? cachedStats
      : await runAnalysisTask(
          segmentedMode ? ANALYSIS_TASK_TYPES.computeStatsSegmented : ANALYSIS_TASK_TYPES.computeStats,
          segmentedMode
            ? {
                text: currentText,
                chunkCharSize: SEGMENTED_ANALYSIS_CHUNK_CHARS,
                sttrChunkSize: 1000,
                compareSignature,
                comparisonEntries: shouldCompareAcrossCorpora ? currentComparisonEntries : []
              }
            : {
                comparisonEntries: shouldCompareAcrossCorpora ? currentComparisonEntries : []
              },
          () => {
            const comparison = shouldCompareAcrossCorpora
              ? compareCorpusFrequencies(currentComparisonEntries)
              : { corpora: [], rows: [] }
            if (segmentedMode) {
              const segmentedStats = computeSegmentedStats(currentText, {
                chunkCharSize: SEGMENTED_ANALYSIS_CHUNK_CHARS,
                sttrChunkSize: 1000
              })
              return {
                ...segmentedStats,
                compareCorpora: comparison.corpora,
                compareRows: comparison.rows,
                compareSignature
              }
            }
            const freqMap = countWordFrequency(currentTokens)
            return {
              freqRows: getSortedFrequencyRows(freqMap),
              tokenCount: currentTokens.length,
              typeCount: Object.keys(freqMap).length,
              ttr: calculateTTR(currentTokens),
              sttr: calculateSTTR(currentTokens, 1000),
              compareCorpora: comparison.corpora,
              compareRows: comparison.rows,
              compareSignature
            }
          },
          { taskName: 'stats' }
        )
    if (!isLatestAnalysisRun('stats', runId)) return

    currentFreqRows = statsResult.freqRows || []
    currentTokenCount = statsResult.tokenCount || 0
    currentTypeCount = statsResult.typeCount || 0
    currentTTR = statsResult.ttr || 0
    currentSTTR = statsResult.sttr || 0
    currentComparisonCorpora = Array.isArray(statsResult.compareCorpora) ? statsResult.compareCorpora : []
    currentComparisonRows = Array.isArray(statsResult.compareRows) ? statsResult.compareRows : []
    invalidateSearchCaches()
    const normalizedCompareSignature = String(statsResult.compareSignature || compareSignature || 'none')
    if (!canUseCachedStats) {
      updateCurrentAnalysisCache({
        stats: {
          freqRows: currentFreqRows,
          tokenCount: currentTokenCount,
          typeCount: currentTypeCount,
          ttr: currentTTR,
          sttr: currentSTTR,
          compareCorpora: currentComparisonCorpora,
          compareRows: currentComparisonRows,
          compareSignature: normalizedCompareSignature
        }
      })
      void persistAnalysisCachePayload()
    }
    renderStatsSummaryTable()
    pageSize = resolvePageSize(pageSizeSelect.value, getVisibleFrequencyRows().length)
    currentPage = 1
    currentComparePageSize = resolvePageSize(comparePageSizeSelect.value, getVisibleCompareRows().length)
    currentComparePage = 1
    renderFrequencyTable()
    renderCompareTable()
    renderWordCloud()
    await runNgramAnalysis({ silent: true })
    switchTab('stats')
    finishTaskEntryWithAttention(
      taskCenterTaskKey,
      '统计结果',
      'success',
      `Token ${formatCount(currentTokenCount)} / Type ${formatCount(currentTypeCount)}`,
      'analysis-complete'
    )
    void recordDiagnostic('info', 'analysis.stats', '统计任务完成。', {
      tokenCount: currentTokenCount,
      typeCount: currentTypeCount,
      analysisMode: currentAnalysisMode
    })
    void notifySystem({
      title: '统计完成',
      body: `${currentCorpusDisplayName || '当前语料'} 已完成统计。Token ${formatCount(currentTokenCount)} / Type ${formatCount(currentTypeCount)}`,
      tag: 'stats-finished',
      category: 'analysis-complete',
      action: 'open-stats-tab'
    })
    void refreshAnalysisCacheState({ silent: true })
    maybeWarnMemoryPressure('analysis.stats')
    return 'success'
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskEntryWithAttention(taskCenterTaskKey, '统计结果', 'cancelled', error.message || '统计任务已取消', 'analysis-complete')
      void recordDiagnostic('warn', 'analysis.stats', error.message || '统计任务已取消')
      showToast(error.message || '已取消统计任务', {
        title: '统计已取消',
        duration: 2200
      })
      return 'cancelled'
    }
    finishTaskEntryWithAttention(taskCenterTaskKey, '统计结果', 'failed', getErrorMessage(error, '统计失败'), 'analysis-complete')
    console.error('[countButton]', error)
    recordDiagnosticError('analysis.stats', error, {
      tokenCount: currentTokens.length
    })
    await showAlert({
      title: '统计失败',
      message: getErrorMessage(error, '统计失败')
    })
    return 'failed'
  } finally {
    endBusyState()
    endCancelableAnalysis('stats')
    if (activeTaskCenterTaskKeys.stats === taskCenterTaskKey) {
      activeTaskCenterTaskKeys.stats = 'stats'
    }
    void setWindowProgressState({
      source: 'analysis',
      state: 'none'
    })
  }
}

countButton.addEventListener('click', async () => {
  await enqueueOrRunAnalysisTask({
    type: 'stats',
    title: '统计结果',
    detail: '正在统计词频与词汇指标...',
    run: ({ taskCenterTaskKey }) => executeStatsAnalysis({ taskCenterTaskKey })
  })
})

cancelStatsButton.addEventListener('click', () => {
  if (!requestCancelAnalysis('stats', '正在取消统计...', '已取消统计任务')) return
  showToast('已请求取消当前统计任务。', {
    title: '正在取消',
    duration: 1800
  })
})

pageSizeSelect.addEventListener('change', () => {
  pageSize = resolvePageSize(pageSizeSelect.value, getVisibleFrequencyRows().length)
  currentPage = 1
  renderFrequencyTable()
  scheduleWorkspaceSnapshotSave()
})

comparePageSizeSelect?.addEventListener('change', () => {
  currentComparePageSize = resolvePageSize(comparePageSizeSelect.value, getVisibleCompareRows().length)
  currentComparePage = 1
  renderCompareTable()
  scheduleWorkspaceSnapshotSave()
})

for (const input of searchQueryInputs || []) {
  input.addEventListener('input', () => {
    setSharedSearchQuery(input.value)
  })
}

for (const input of searchOptionInputs || []) {
  input.addEventListener('change', () => {
    const optionName = input.dataset.searchOption || ''
    setSharedSearchOption(optionName, input.checked)
  })
}

for (const control of [chiAInput, chiBInput, chiCInput, chiDInput]) {
  control?.addEventListener('input', () => {
    captureChiSquareInputsFromControls()
    scheduleWorkspaceSnapshotSave()
  })
}

chiYatesToggle?.addEventListener('change', () => {
  captureChiSquareInputsFromControls()
  if (currentChiSquareResult) {
    try {
      currentChiSquareResult = calculateChiSquare2x2(readChiSquareInputNumbers())
    } catch {
      currentChiSquareResult = null
    }
    renderChiSquareResult()
  }
  scheduleWorkspaceSnapshotSave()
})

chiSquareRunButton?.addEventListener('click', async () => {
  try {
    const inputValues = readChiSquareInputNumbers()
    currentChiSquareInputValues = {
      a: String(inputValues.a),
      b: String(inputValues.b),
      c: String(inputValues.c),
      d: String(inputValues.d),
      yates: inputValues.yates
    }
    syncChiSquareInputsFromState()
    currentChiSquareResult = calculateChiSquare2x2(inputValues)
    renderChiSquareResult()
    switchTab('chi-square')
    scheduleWorkspaceSnapshotSave()
    showToast('卡方检验已完成。', {
      title: '统计工具',
      type: 'success',
      duration: 2200
    })
    void recordDiagnostic('info', 'analysis.chi-square', '卡方检验已完成。', {
      chiSquare: currentChiSquareResult.chiSquare,
      pValue: currentChiSquareResult.pValue,
      yates: currentChiSquareResult.yatesCorrection
    })
  } catch (error) {
    await showAlert({
      title: '卡方检验输入无效',
      message: getErrorMessage(error, '请填写合法的 2×2 列联表频数')
    })
  }
})

chiSquareResetButton?.addEventListener('click', () => {
  currentChiSquareInputValues = {
    a: '',
    b: '',
    c: '',
    d: '',
    yates: false
  }
  currentChiSquareResult = null
  syncChiSquareInputsFromState()
  renderChiSquareResult()
  scheduleWorkspaceSnapshotSave()
})

for (const control of [leftWindowSelect, rightWindowSelect, collocateLeftWindowSelect, collocateRightWindowSelect]) {
  control.addEventListener('change', () => {
    normalizeWindowSizeInput(control)
    scheduleWorkspaceSnapshotSave()
  })
  control.addEventListener('blur', () => {
    normalizeWindowSizeInput(control)
    scheduleWorkspaceSnapshotSave()
  })
}

prevPageButton.addEventListener('click', () => {
  if (currentPage > 1) {
    currentPage -= 1
    renderFrequencyTable()
  }
})

nextPageButton.addEventListener('click', () => {
  const totalPages = Math.ceil(getVisibleFrequencyRows().length / pageSize)
  if (currentPage < totalPages) {
    currentPage += 1
    renderFrequencyTable()
  }
})

comparePrevPageButton?.addEventListener('click', () => {
  if (currentComparePage > 1) {
    currentComparePage -= 1
    renderCompareTable()
  }
})

compareNextPageButton?.addEventListener('click', () => {
  const totalPages = Math.ceil(getVisibleCompareRows().length / currentComparePageSize)
  if (currentComparePage < totalPages) {
    currentComparePage += 1
    renderCompareTable()
  }
})

ngramButton?.addEventListener('click', async () => {
  await runNgramAnalysis({ switchToTab: true })
})

ngramSizeSelect?.addEventListener('change', () => {
  currentNgramSize = getSelectedNgramSize()
  scheduleWorkspaceSnapshotSave()
  if (currentTokens.length > 0) {
    void runNgramAnalysis({ silent: true })
  }
})

ngramPageSizeSelect?.addEventListener('change', () => {
  currentNgramPageSize = resolvePageSize(ngramPageSizeSelect.value, currentNgramRows.length)
  currentNgramPage = 1
  renderNgramTable()
  scheduleWorkspaceSnapshotSave()
})

ngramPrevPageButton?.addEventListener('click', () => {
  if (currentNgramPage > 1) {
    currentNgramPage -= 1
    renderNgramTable()
  }
})

ngramNextPageButton?.addEventListener('click', () => {
  const totalPages = Math.ceil(currentNgramRows.length / currentNgramPageSize)
  if (currentNgramPage < totalPages) {
    currentNgramPage += 1
    renderNgramTable()
  }
})

async function executeKWICAnalysis({ taskCenterTaskKey = 'kwic' } = {}) {
  const keyword = String(currentSearchQuery || '').trim()
  if (!keyword) {
    if (taskCenterTaskKey !== 'kwic') {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'failed', '缺少检索词', 'analysis-complete')
    }
    await showAlert({
      title: '缺少检索词',
      message: '请输入要检索的词'
    })
    return 'failed'
  }
  if (currentAnalysisMode === 'segmented') {
    if (taskCenterTaskKey !== 'kwic') {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'failed', '分段模式暂不支持 KWIC', 'analysis-complete')
    }
    await showAlert({
      title: 'KWIC 暂不可用',
      message: '当前语料体量较大，已启用分段分析模式。为保证稳定性，KWIC 检索暂不可用，请切换更小语料后继续。'
    })
    return 'failed'
  }
  let leftWindowSize = DEFAULT_WINDOW_SIZE
  let rightWindowSize = DEFAULT_WINDOW_SIZE
  try {
    leftWindowSize = readWindowSizeInput(leftWindowSelect, 'KWIC 左窗口')
    rightWindowSize = readWindowSizeInput(rightWindowSelect, 'KWIC 右窗口')
  } catch (error) {
    await showAlert({
      title: 'KWIC 设置无效',
      message: getErrorMessage(error, '请输入合法的 KWIC 窗口大小')
    })
    return 'failed'
  }
  const kwicScope = getSelectedKWICScope()
  const searchOptions = { ...currentSearchOptions }
  let kwicScopeLabel = '当前语料'
  let searchedCorpusCount = currentText.trim() ? 1 : 0
  let kwicTaskType = ANALYSIS_TASK_TYPES.searchKWIC
  let kwicTaskPayload = { keyword, leftWindowSize, rightWindowSize, searchOptions }
  let kwicFallback = () => searchKWIC(currentTokenObjects, keyword, leftWindowSize, rightWindowSize, searchOptions)
  let crossCorpusScopeContext = null

  if (kwicScope === 'current') {
    if (!currentText.trim()) {
      if (taskCenterTaskKey !== 'kwic') {
        finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'failed', '缺少语料', 'analysis-complete')
      }
      await showAlert({
        title: '缺少语料',
        message: '请先导入一个 txt / docx / pdf 文件，或把检索范围切到“全部本地语料”。'
      })
      return 'failed'
    }
  } else {
    const scopeContext = await resolveCrossCorpusKWICScope(kwicScope)
    if (!scopeContext) {
      if (taskCenterTaskKey !== 'kwic') {
        finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'failed', '检索范围不可用', 'analysis-complete')
      }
      return 'failed'
    }
    kwicScopeLabel = scopeContext.scopeLabel
    crossCorpusScopeContext = scopeContext
  }

  const runId = nextAnalysisRun('kwic')
  const endBusyState = beginBusyState('正在执行 KWIC 检索...')
  beginCancelableAnalysis('kwic')
  void setWindowProgressState({
    source: 'analysis',
    state: 'indeterminate',
    priority: 40
  })
  activeTaskCenterTaskKeys.kwic = taskCenterTaskKey
  ensureTaskCenterRunningEntry(
    taskCenterTaskKey,
    'KWIC 检索',
    `${kwicScopeLabel} · 关键词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R · ${getSearchOptionsSummary()}`
  )
  try {
    currentKWICKeyword = keyword
    currentKWICLeftWindow = leftWindowSize
    currentKWICRightWindow = rightWindowSize
    currentKWICSortMode = kwicSortSelect.value
    currentKWICScope = kwicScope
    currentKWICScopeLabel = kwicScopeLabel
    if (crossCorpusScopeContext) {
      const searchResult = await runCancelableTask(
        () =>
          window.electronAPI.searchLibraryKWIC({
            folderId: crossCorpusScopeContext.folderId,
            keyword,
            leftWindowSize,
            rightWindowSize,
            searchOptions
          }),
        { taskName: 'kwic' }
      )
      if (!searchResult?.success) {
        throw new Error(searchResult?.message || '跨语料 KWIC 检索失败')
      }
      searchedCorpusCount = Number(searchResult?.searchedCorpusCount) || 0
      currentKWICSearchedCorpusCount = searchedCorpusCount
      currentKWICScopeLabel = String(searchResult?.scopeLabel || crossCorpusScopeContext.scopeLabel || kwicScopeLabel)
      if (searchedCorpusCount === 0) {
        finishTaskEntryWithAttention(
          taskCenterTaskKey,
          'KWIC 检索',
          'failed',
          crossCorpusScopeContext.emptyMessage,
          'analysis-complete'
        )
        await showAlert({
          title: crossCorpusScopeContext.emptyTitle,
          message: crossCorpusScopeContext.emptyMessage
        })
        return 'failed'
      }
      currentKWICResults = Array.isArray(searchResult?.results) ? searchResult.results : []
    } else {
      currentKWICSearchedCorpusCount = searchedCorpusCount
      currentKWICResults = await runAnalysisTask(
        kwicTaskType,
        kwicTaskPayload,
        kwicFallback,
        { taskName: 'kwic' }
      )
    }
    if (!isLatestAnalysisRun('kwic', runId)) return
    invalidateKWICSortCache()
    currentKWICPageSize = resolvePageSize(kwicPageSizeSelect.value, currentKWICResults.length)
    currentKWICPage = 1
    renderKWICTable()
    switchTab('kwic')
    finishTaskEntryWithAttention(
      taskCenterTaskKey,
      'KWIC 检索',
      'success',
      `${kwicScopeLabel} · 关键词：${keyword} · ${formatCount(currentKWICResults.length)} 条结果`,
      'analysis-complete'
    )
    void recordDiagnostic('info', 'analysis.kwic', 'KWIC 检索完成。', {
      keyword,
      scope: kwicScopeLabel,
      resultCount: currentKWICResults.length
    })
    void notifySystem({
      title: 'KWIC 检索完成',
      body: `${kwicScopeLabel} · ${keyword} · ${formatCount(currentKWICResults.length)} 条结果`,
      tag: 'kwic-finished',
      category: 'analysis-complete',
      action: 'open-kwic-tab'
    })
    return 'success'
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'cancelled', error.message || 'KWIC 检索已取消', 'analysis-complete')
      void recordDiagnostic('warn', 'analysis.kwic', error.message || 'KWIC 检索已取消', {
        keyword
      })
      showToast(error.message || '已取消 KWIC 检索', {
        title: 'KWIC 已取消',
        duration: 2200
      })
      return 'cancelled'
    }
    finishTaskEntryWithAttention(taskCenterTaskKey, 'KWIC 检索', 'failed', getErrorMessage(error, 'KWIC 检索失败'), 'analysis-complete')
    console.error('[kwicButton]', error)
    recordDiagnosticError('analysis.kwic', error, {
      keyword,
      scope: kwicScopeLabel
    })
    await showAlert({
      title: 'KWIC 检索失败',
      message: getErrorMessage(error, 'KWIC 检索失败')
    })
    return 'failed'
  } finally {
    endBusyState()
    endCancelableAnalysis('kwic')
    if (activeTaskCenterTaskKeys.kwic === taskCenterTaskKey) {
      activeTaskCenterTaskKeys.kwic = 'kwic'
    }
    void setWindowProgressState({
      source: 'analysis',
      state: 'none'
    })
  }
}

kwicButton.addEventListener('click', async () => {
  await enqueueOrRunAnalysisTask({
    type: 'kwic',
    title: 'KWIC 检索',
    detail: `关键词：${String(currentSearchQuery || '').trim() || '(空)'} · SearchQuery：${getSearchOptionsSummary()}`,
    run: ({ taskCenterTaskKey }) => executeKWICAnalysis({ taskCenterTaskKey })
  })
})

cancelKwicButton.addEventListener('click', () => {
  if (!requestCancelAnalysis('kwic', '正在取消 KWIC 检索...', '已取消 KWIC 检索')) return
  showToast('已请求取消当前 KWIC 检索。', {
    title: '正在取消',
    duration: 1800
  })
})

kwicSortSelect.addEventListener('change', () => {
  currentKWICSortMode = kwicSortSelect.value
  currentKWICPage = 1
  renderKWICTable()
  scheduleWorkspaceSnapshotSave()
})

kwicPageSizeSelect.addEventListener('change', () => {
  currentKWICPageSize = resolvePageSize(kwicPageSizeSelect.value, currentKWICResults.length)
  currentKWICPage = 1
  renderKWICTable()
  scheduleWorkspaceSnapshotSave()
})

kwicScopeSelect?.addEventListener('change', () => {
  currentKWICScope = kwicScopeSelect.value || 'current'
  scheduleWorkspaceSnapshotSave()
})

kwicPrevPageButton.addEventListener('click', () => {
  if (currentKWICPage > 1) {
    currentKWICPage -= 1
    renderKWICTable()
  }
})

kwicNextPageButton.addEventListener('click', () => {
  const totalPages = Math.ceil(currentKWICResults.length / currentKWICPageSize)
  if (currentKWICPage < totalPages) {
    currentKWICPage += 1
    renderKWICTable()
  }
})

async function executeCollocateAnalysis({ taskCenterTaskKey = 'collocate' } = {}) {
  if (!currentText.trim()) {
    if (taskCenterTaskKey !== 'collocate') {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'Collocate 统计', 'failed', '缺少语料', 'analysis-complete')
    }
    await showAlert({
      title: '缺少语料',
      message: '请先导入一个 txt / docx / pdf 文件'
    })
    return 'failed'
  }
  if (currentAnalysisMode === 'segmented') {
    if (taskCenterTaskKey !== 'collocate') {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'Collocate 统计', 'failed', '分段模式暂不支持 Collocate', 'analysis-complete')
    }
    await showAlert({
      title: 'Collocate 暂不可用',
      message: '当前语料体量较大，已启用分段分析模式。为保证稳定性，Collocate 统计暂不可用，请切换更小语料后继续。'
    })
    return 'failed'
  }
  const keyword = String(currentSearchQuery || '').trim()
  if (!keyword) {
    if (taskCenterTaskKey !== 'collocate') {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'Collocate 统计', 'failed', '缺少节点词', 'analysis-complete')
    }
    await showAlert({
      title: '缺少节点词',
      message: '请输入节点词'
    })
    return 'failed'
  }
  let leftWindowSize = DEFAULT_WINDOW_SIZE
  let rightWindowSize = DEFAULT_WINDOW_SIZE
  try {
    leftWindowSize = readWindowSizeInput(collocateLeftWindowSelect, 'Collocate 左窗口')
    rightWindowSize = readWindowSizeInput(collocateRightWindowSelect, 'Collocate 右窗口')
  } catch (error) {
    await showAlert({
      title: 'Collocate 设置无效',
      message: getErrorMessage(error, '请输入合法的 Collocate 窗口大小')
    })
    return 'failed'
  }
  const minFreq = Number(collocateMinFreqSelect.value)
  const searchOptions = { ...currentSearchOptions }
  const runId = nextAnalysisRun('collocate')
  const endBusyState = beginBusyState('正在计算搭配词结果...')
  beginCancelableAnalysis('collocate')
  void setWindowProgressState({
    source: 'analysis',
    state: 'indeterminate',
    priority: 40
  })
  activeTaskCenterTaskKeys.collocate = taskCenterTaskKey
  ensureTaskCenterRunningEntry(
    taskCenterTaskKey,
    'Collocate 统计',
    `节点词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R · ${getSearchOptionsSummary()}`
  )
  try {
    currentCollocateKeyword = keyword
    currentCollocateLeftWindow = leftWindowSize
    currentCollocateRightWindow = rightWindowSize
    currentCollocateMinFreq = minFreq
    currentCollocateRows = await runAnalysisTask(
      ANALYSIS_TASK_TYPES.searchCollocates,
      { keyword, leftWindowSize, rightWindowSize, minFreq, searchOptions },
      () => searchCollocates(currentTokenObjects, currentTokens, keyword, leftWindowSize, rightWindowSize, minFreq, searchOptions),
      { taskName: 'collocate' }
    )
    if (!isLatestAnalysisRun('collocate', runId)) return
    currentCollocatePageSize = resolvePageSize(collocatePageSizeSelect.value, currentCollocateRows.length)
    currentCollocatePage = 1
    collocateMeta.innerHTML = `节点词：${escapeHtml(keyword)} ｜ 范围：${leftWindowSize}L ${rightWindowSize}R ｜ 最低共现次数：${minFreq} ｜ SearchQuery：${escapeHtml(getSearchOptionsSummary())}<br />结果按共现次数降序排列。`
    renderCollocateTable()
    switchTab('collocate')
    finishTaskEntryWithAttention(
      taskCenterTaskKey,
      'Collocate 统计',
      'success',
      `节点词：${keyword} · ${formatCount(currentCollocateRows.length)} 条结果`,
      'analysis-complete'
    )
    void recordDiagnostic('info', 'analysis.collocate', 'Collocate 统计完成。', {
      keyword,
      resultCount: currentCollocateRows.length,
      minFreq
    })
    void notifySystem({
      title: 'Collocate 统计完成',
      body: `${keyword} · ${formatCount(currentCollocateRows.length)} 条结果`,
      tag: 'collocate-finished',
      category: 'analysis-complete',
      action: 'open-collocate-tab'
    })
    return 'success'
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskEntryWithAttention(taskCenterTaskKey, 'Collocate 统计', 'cancelled', error.message || 'Collocate 统计已取消', 'analysis-complete')
      void recordDiagnostic('warn', 'analysis.collocate', error.message || 'Collocate 统计已取消', {
        keyword
      })
      showToast(error.message || '已取消 Collocate 统计', {
        title: 'Collocate 已取消',
        duration: 2200
      })
      return 'cancelled'
    }
    finishTaskEntryWithAttention(taskCenterTaskKey, 'Collocate 统计', 'failed', getErrorMessage(error, 'Collocate 统计失败'), 'analysis-complete')
    console.error('[collocateButton]', error)
    recordDiagnosticError('analysis.collocate', error, {
      keyword,
      minFreq
    })
    await showAlert({
      title: 'Collocate 统计失败',
      message: getErrorMessage(error, 'Collocate 统计失败')
    })
    return 'failed'
  } finally {
    endBusyState()
    endCancelableAnalysis('collocate')
    if (activeTaskCenterTaskKeys.collocate === taskCenterTaskKey) {
      activeTaskCenterTaskKeys.collocate = 'collocate'
    }
    void setWindowProgressState({
      source: 'analysis',
      state: 'none'
    })
  }
}

collocateButton.addEventListener('click', async () => {
  await enqueueOrRunAnalysisTask({
    type: 'collocate',
    title: 'Collocate 统计',
    detail: `节点词：${String(currentSearchQuery || '').trim() || '(空)'} · SearchQuery：${getSearchOptionsSummary()}`,
    run: ({ taskCenterTaskKey }) => executeCollocateAnalysis({ taskCenterTaskKey })
  })
})

cancelCollocateButton.addEventListener('click', () => {
  if (!requestCancelAnalysis('collocate', '正在取消 Collocate 统计...', '已取消 Collocate 统计')) return
  showToast('已请求取消当前 Collocate 统计。', {
    title: '正在取消',
    duration: 1800
  })
})

collocatePageSizeSelect.addEventListener('change', () => {
  currentCollocatePageSize = resolvePageSize(collocatePageSizeSelect.value, currentCollocateRows.length)
  currentCollocatePage = 1
  renderCollocateTable()
  scheduleWorkspaceSnapshotSave()
})

collocateMinFreqSelect?.addEventListener('change', () => {
  currentCollocateMinFreq = Number(collocateMinFreqSelect.value) || 1
  scheduleWorkspaceSnapshotSave()
})

collocatePrevPageButton.addEventListener('click', () => {
  if (currentCollocatePage > 1) {
    currentCollocatePage -= 1
    renderCollocateTable()
  }
})

collocateNextPageButton.addEventListener('click', () => {
  const totalPages = Math.ceil(currentCollocateRows.length / currentCollocatePageSize)
  if (currentCollocatePage < totalPages) {
    currentCollocatePage += 1
    renderCollocateTable()
  }
})

kwicWrapper.addEventListener('click', async (event) => {
  const row = event.target.closest('tr[data-sentence-id]')
  if (!row) return
  const corpusId = row.dataset.corpusId || ''
  if (corpusId && corpusId !== currentCorpusId) {
    const result = await window.electronAPI.openSavedCorpus(corpusId)
    if (!result?.success) {
      await showAlert({
        title: '打开命中语料失败',
        message: result?.message || '无法打开对应语料'
      })
      return
    }
    await loadCorpusResult(result)
  }
  const sentenceId = Number(row.dataset.sentenceId)
  const nodeIndex = Number(row.dataset.nodeIndex)
  const leftWindowSize = Number(row.dataset.leftWindow)
  const rightWindowSize = Number(row.dataset.rightWindow)
  locateSentence(sentenceId, nodeIndex, leftWindowSize, rightWindowSize)
  switchTab('locator')
})

sentenceViewer.addEventListener('click', (event) => {
  const row = event.target.closest('tr[data-sentence-id]')
  if (!row) return
  const sentenceId = Number(row.dataset.sentenceId)
  activeSentenceId = sentenceId
  currentHighlight = null
  renderSentenceViewer()
  locatorMeta.textContent = `已定位到第 ${sentenceId + 1} 句。`
})

copyStatsButton.addEventListener('click', async () => {
  await saveTableFile('统计摘要', buildStatsRows(), exportFeedback)
})

copyFreqButton.addEventListener('click', async () => {
  await saveTableFile('词频表_当前页', buildFrequencyRows(), exportFeedback)
})

exportAllFreqButton.addEventListener('click', async () => {
  await saveTableFile('词频表_全部', buildAllFrequencyRows(), exportFeedback)
})

exportNgramButton?.addEventListener('click', async () => {
  await saveTableFile(`Ngram_${currentNgramSize}gram_当前页`, buildNgramRows(), exportFeedback)
})

exportAllNgramButton?.addEventListener('click', async () => {
  await saveTableFile(`Ngram_${currentNgramSize}gram_全部`, buildAllNgramRows(), exportFeedback)
})

copyCompareButton?.addEventListener('click', async () => {
  await saveTableFile('多语料对比_当前页', buildCompareRows(), exportFeedback)
})

exportAllCompareButton?.addEventListener('click', async () => {
  await saveTableFile('多语料对比_全部', buildAllCompareRows(), exportFeedback)
})

copyKWICButton.addEventListener('click', async () => {
  await saveTableFile('KWIC_当前页', buildKWICRows(), exportFeedback)
})

exportAllKWICButton.addEventListener('click', async () => {
  await saveTableFile('KWIC_全部', buildAllKWICRows(), exportFeedback)
})

exportCollocateButton.addEventListener('click', async () => {
  await saveTableFile('Collocate_当前页', buildCollocateRows(), exportFeedback)
})

exportAllCollocateButton.addEventListener('click', async () => {
  await saveTableFile('Collocate_全部', buildAllCollocateRows(), exportFeedback)
})

copyLocatorButton.addEventListener('click', async () => {
  await saveTableFile('原文定位表', buildLocatorRows(), exportFeedback)
})

wordCloudWrapper?.addEventListener('click', event => {
  const target = event.target.closest('[data-word-cloud-term]')
  if (!target) return
  const query = target.dataset.wordCloudTerm || ''
  if (!query) return
  setSharedSearchQuery(query)
})
