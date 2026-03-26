import {
  ANALYSIS_TASK_TYPES,
  DEFAULT_APP_INFO,
  BUTTON_ICONS,
  DEFAULT_THEME,
  DEFAULT_UI_SETTINGS,
  DEFAULT_WINDOW_SIZE,
  LARGE_TABLE_THRESHOLD,
  PREVIEW_CHAR_LIMIT,
  RECENT_OPEN_LIMIT,
  TABLE_RENDER_CHUNK_SIZE,
  UI_FONT_FAMILIES,
  WORKSPACE_SNAPSHOT_VERSION,
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
  renderCollocateTable as renderCollocateTableSection
} from './features/collocate.mjs'
import {
  renderCompareSection as renderCompareSectionData
} from './features/compare.mjs'
import { createFeedbackController } from './feedback.mjs'
import {
  getFolderById as getFolderByIdFromList,
  getImportTargetFolder as getImportTargetFolderForState,
  getLibraryTargetChipText
} from './features/library.mjs'
import {
  renderKWICTable as renderKWICTableSection
} from './features/kwic.mjs'
import {
  renderNgramTable as renderNgramTableSection
} from './features/ngram.mjs'
import {
  renderFrequencyTable as renderFrequencyTableSection,
  renderStatsSummary as renderStatsSummarySection,
  renderWordCloud as renderWordCloudSection
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
  setButtonsBusy
} from './utils.mjs'
import { renderWorkspaceShell } from './views/workspaceShellView.mjs'
import {
  buildAnalysisActionButtonState,
  buildLoadSelectedCorporaButtonState
} from './viewModels/toolbarState.mjs'
import {
  buildRecentOpenEntryFromResult,
} from './recentOpen.mjs'
import {
  getWorkspaceSnapshotSummary,
  hasMeaningfulWorkspaceSnapshot,
  shouldShowFirstRunTutorial
} from './sessionState.mjs'
import { createTaskCenterController } from './taskCenter.mjs'
import { createAnalysisCacheController } from './controllers/analysisCacheController.mjs'
import { createAnalysisQueueController } from './controllers/analysisQueueController.mjs'
import { createDiagnosticsController } from './controllers/diagnosticsController.mjs'
import { createLibraryManagerController } from './controllers/libraryManagerController.mjs'
import { createLocatorController } from './controllers/locatorController.mjs'
import { createOpenCommandController } from './controllers/openCommandController.mjs'
import { createSearchTabsController } from './controllers/searchTabsController.mjs'
import { createTableActionsController } from './controllers/tableActionsController.mjs'
import { createWelcomeUpdateController } from './controllers/welcomeUpdateController.mjs'
import { createWindowDocumentController } from './controllers/windowDocumentController.mjs'
import { createWorkspaceController } from './controllers/workspaceController.mjs'
import { createWorkspaceDocumentService } from './services/workspaceDocumentService.mjs'
import {
  buildAnalysisSnapshotState,
  buildCollocateState,
  buildCompareState,
  buildDiagnosticRendererState,
  buildKWICState,
  buildLocatorState,
  buildNgramState,
  buildStatsState
} from './appStateSelectors.mjs'
import { createAnalysisEngineService } from './engine/analysisEngineService.mjs'
import { createMacHostServices } from './macHostServices.mjs'
import { createPersistedStateStore } from './persistedState.mjs'
import {
  buildStopwordFilterKey,
  createStopwordMatcher,
  DEFAULT_STOPWORD_LIST_TEXT,
  getStopwordSummaryText,
  normalizeStopwordFilterState,
  parseStopwordList
} from './stopwordFilter.mjs'
import { runDeferredRendererStartup, runInitialRendererSetup } from './startup/flow.mjs'
import { createStartupPhaseRunner } from './startup/phaseRunner.mjs'

const hostServices = createMacHostServices(globalThis.window?.electronAPI)
const electronAPI = hostServices.api
const appHost = hostServices.app
const settingsHost = hostServices.settings
const diagnosticsHost = hostServices.diagnostics
const cacheHost = hostServices.cache
const libraryHost = hostServices.library
const workspaceHost = hostServices.workspace
const windowHost = hostServices.window
const updateHost = hostServices.update
const smokeHost = hostServices.smoke
const persistedState = createPersistedStateStore(globalThis.localStorage)
const windowDocumentController = createWindowDocumentController({
  electronAPI: windowHost
})
const workspaceDocumentService = createWorkspaceDocumentService({
  windowDocumentController,
  hasMeaningfulWorkspaceSnapshot,
  workspaceSnapshotVersion: WORKSPACE_SNAPSHOT_VERSION,
  defaultWindowSize: DEFAULT_WINDOW_SIZE
})

document.documentElement?.classList?.add('mac-native-window')
if (document.body) {
  document.body.classList.add('mac-native-window')
} else {
  window.addEventListener(
    'DOMContentLoaded',
    () => {
      document.body?.classList?.add('mac-native-window')
    },
    { once: true }
  )
}

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
  hasElectronAPI: Boolean(electronAPI.raw)
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
  ngramFilterInput,
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
  stopwordToggleInputs,
  stopwordModeSelects,
  stopwordEditButtons,
  stopwordSummaryNodes,
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
  stopwordModal,
  stopwordModalContext,
  stopwordListTextarea,
  stopwordListCount,
  saveStopwordListButton,
  closeStopwordModalButton,
  resetStopwordListButton,
  clearStopwordListButton,
  uiZoomRange,
  uiFontSizeRange,
  uiFontFamilySelect,
  uiAccentSelect,
  restoreWorkspaceToggle,
  autoUpdateEnabledToggle,
  autoUpdateCheckOnLaunchToggle,
  autoUpdateAutoDownloadToggle,
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
  stopwordToggleCount: Array.isArray(stopwordToggleInputs) ? stopwordToggleInputs.length : 0,
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
  systemStatusText,
  electronAPI: smokeHost
})
const ANALYSIS_CACHE_SCHEMA_VERSION = 1
const MAX_ANALYSIS_QUEUE_LENGTH = 12
const LARGE_CORPUS_SEGMENTED_CHAR_THRESHOLD = 1200000
const SEGMENTED_ANALYSIS_CHUNK_CHARS = 180000
const MEMORY_PRESSURE_WARN_RATIO = 0.82
const MEMORY_PRESSURE_WARN_COOLDOWN_MS = 60 * 1000
const analysisEngine = createAnalysisEngineService({
  runAnalysisTask,
  segmentedAnalysisChunkChars: SEGMENTED_ANALYSIS_CHUNK_CHARS,
  segmentedAnalysisThreshold: LARGE_CORPUS_SEGMENTED_CHAR_THRESHOLD
})
const normalizeSearchOptions = analysisEngine.normalizeSearchOptions
const buildTokenMatcher = analysisEngine.buildTokenMatcher
const { cancelTableRender, renderTableInChunks } = createTableRenderer({
  formatCount,
  largeTableThreshold: LARGE_TABLE_THRESHOLD,
  chunkSize: TABLE_RENDER_CHUNK_SIZE
})
const {
  applyAutoUpdatePreferencesFromControls,
  applyTheme,
  applyUISettings,
  applyUISettingsFromControls,
  closeUISettingsModal,
  getCurrentUISettings,
  init: initUISettings,
  openUISettingsModal,
  refreshAutoUpdatePreferences,
  refreshSystemAppearanceState
} = createUISettingsController({
  dom,
  electronAPI: settingsHost,
  stateStore: persistedState,
  defaultTheme: DEFAULT_THEME,
  defaultSettings: DEFAULT_UI_SETTINGS,
  fontFamilies: UI_FONT_FAMILIES,
  clampNumber
})
const { showAlert, showConfirm, showPrompt, showToast } = createFeedbackController(dom)
const {
  bindDiagnosticsEvents,
  maybePromptAutoBugFeedback,
  openGitHubFeedbackIssue,
  recordDiagnostic,
  recordDiagnosticError,
  refreshDiagnosticsStatusText
} = createDiagnosticsController({
  dom,
  electronAPI: diagnosticsHost,
  getCurrentUISettings,
  getDiagnosticRendererState,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  setWindowProgressState
})
const exportFeedback = { showAlert, showToast, notifySystem, electronAPI: hostServices.files }
let currentAppInfo = { ...DEFAULT_APP_INFO }
let appInfoLoaded = false
let appInfoPromise = null

let currentCorpusMode = 'quick'
let currentCorpusId = null
let currentCorpusDisplayName = ''
let currentCorpusFolderId = null
let currentCorpusFolderName = ''
let currentSelectedCorpora = []
let currentLibraryFolderId = persistedState.getLibraryFolderId()
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
let currentStopwordFilter = persistedState.loadStopwordFilter({
  enabled: false,
  mode: 'exclude',
  listText: DEFAULT_STOPWORD_LIST_TEXT
})
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
let onboardingState = persistedState.loadOnboardingState()
let systemOpenRequestQueue = Promise.resolve()
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
let currentAnalysisCacheKey = ''
let currentAnalysisCachePayload = null
let currentAnalysisMode = 'full'
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
let visibleNgramRowsCache = {
  rowsRef: null,
  searchKey: '',
  result: []
}
let renderSentenceViewer = () => {}
let scheduleWorkspaceSnapshotSave = () => {}

void workspaceDocumentService.syncContext({}, { immediate: true })

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

function syncWindowDocumentContext({ immediate = false } = {}) {
  return workspaceDocumentService.syncContext(
    {
      displayName: currentCorpusDisplayName
    },
    { immediate }
  )
}

function buildSearchOptionsKey(options = currentSearchOptions) {
  const normalized = normalizeSearchOptions(options)
  return `${normalized.words ? '1' : '0'}${normalized.caseSensitive ? '1' : '0'}${normalized.regex ? '1' : '0'}`
}

function persistStopwordFilterState() {
  currentStopwordFilter = persistedState.saveStopwordFilter(currentStopwordFilter)
  return currentStopwordFilter
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
  visibleNgramRowsCache = {
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

function getCurrentStopwordMatcher() {
  return createStopwordMatcher(currentStopwordFilter)
}

function getCurrentStopwordSummaryText() {
  return getStopwordSummaryText(currentStopwordFilter)
}

function updateStopwordListCount(text = currentStopwordFilter.listText) {
  if (!stopwordListCount) return
  const count = parseStopwordList(text).length
  stopwordListCount.textContent = `${formatCount(count)} 词`
}

function openStopwordEditor(contextLabel = '') {
  if (!stopwordModal || !stopwordListTextarea) return
  const normalizedContext = String(contextLabel || '').trim().toLowerCase()
  const contextMap = {
    stats: '统计结果',
    compare: '对比分析',
    ngram: 'Ngram'
  }
  if (stopwordModalContext) {
    stopwordModalContext.textContent = contextLabel
      ? `${contextMap[normalizedContext] || contextLabel} · 共享搜索过滤器`
      : '共享搜索过滤器'
  }
  stopwordListTextarea.value =
    typeof currentStopwordFilter.listText === 'string'
      ? currentStopwordFilter.listText
      : DEFAULT_STOPWORD_LIST_TEXT
  updateStopwordListCount(stopwordListTextarea.value)
  stopwordModal.classList.remove('hidden')
  queueMicrotask(() => {
    stopwordListTextarea.focus()
    stopwordListTextarea.select()
  })
}

function closeStopwordEditor() {
  stopwordModal?.classList.add('hidden')
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

function shouldUseSegmentedAnalysis(text) {
  return analysisEngine.shouldUseSegmentedAnalysis(text)
}

function formatBytes(value) {
  const bytes = Math.max(0, Number(value) || 0)
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`
}

const {
  buildAnalysisCacheKey,
  loadAnalysisCachePayload,
  normalizeAnalysisCachePayload,
  normalizeCachedStats,
  persistAnalysisCachePayload,
  rebuildCurrentAnalysisCache,
  refreshAnalysisCacheState,
  updateCurrentAnalysisCache
} = createAnalysisCacheController({
  electronAPI: cacheHost,
  dom,
  analysisCacheSchemaVersion: ANALYSIS_CACHE_SCHEMA_VERSION,
  formatBytes,
  formatCount,
  showToast,
  buildComparisonSignature,
  computeTextFingerprint,
  getCurrentCorpusMode: () => currentCorpusMode,
  getCurrentCorpusId: () => currentCorpusId,
  getCurrentSelectedCorpora: () => currentSelectedCorpora,
  getCurrentComparisonEntries: () => currentComparisonEntries,
  getCurrentAnalysisSnapshot: () =>
    buildAnalysisSnapshotState({
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
    }),
  getCurrentCacheKey: () => currentAnalysisCacheKey,
  getCurrentCachePayload: () => currentAnalysisCachePayload,
  setCurrentCachePayload: nextPayload => {
    currentAnalysisCachePayload = nextPayload
  }
})

const {
  refreshLibraryModal,
  openLibraryModal,
  closeLibraryModal,
  refreshRecycleBinModal,
  openRecycleModal,
  closeRecycleModal,
  isLibraryModalVisible,
  bindLibraryManagerEvents
} = createLibraryManagerController({
  electronAPI: libraryHost,
  dom,
  escapeHtml,
  formatCount,
  beginBusyState,
  setButtonsBusy,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  promptForName,
  loadCorpusResult,
  setWindowProgressState,
  buildBackupSummaryMessage,
  buildRestoreSummaryMessage,
  buildRepairSummaryMessage,
  syncLibrarySelectionWithCurrentCorpora,
  updateLoadSelectedCorporaButton,
  updateLibraryMetaText,
  updateLibraryTargetChip,
  setLibraryFolderSelection,
  getCurrentLibraryFolderId: () => currentLibraryFolderId,
  setCurrentLibraryFolders: nextFolders => {
    currentLibraryFolders = nextFolders
  },
  setCurrentLibraryVisibleCount: nextVisibleCount => {
    currentLibraryVisibleCount = nextVisibleCount
  },
  setCurrentLibraryTotalCount: nextTotalCount => {
    currentLibraryTotalCount = nextTotalCount
  },
  getSelectedLibraryCorpusIds: () => selectedLibraryCorpusIds,
  getImportTargetFolder,
  getCurrentCorpusId: () => currentCorpusId,
  getCurrentCorpusMode: () => currentCorpusMode,
  getCurrentCorpusFolderId: () => currentCorpusFolderId,
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
  decorateButton
})

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

function getVisibleFrequencyRows() {
  const { matcher, normalizedQuery, options, error } = getCurrentSearchContext()
  if (error) return []
  const stopwordKey = buildStopwordFilterKey(currentStopwordFilter)
  const stopwordMatcher = getCurrentStopwordMatcher()
  const searchKey = `${normalizedQuery}|${buildSearchOptionsKey(options)}|${stopwordKey}`
  if (visibleFrequencyRowsCache.rowsRef === currentFreqRows && visibleFrequencyRowsCache.searchKey === searchKey) {
    return visibleFrequencyRowsCache.result
  }
  const queryMatchedRows = !normalizedQuery
    ? currentFreqRows
    : currentFreqRows.filter(([word]) => matcher(String(word || '')))
  const rows = stopwordMatcher.enabled
    ? queryMatchedRows.filter(([word]) => stopwordMatcher.matches(String(word || '')))
    : queryMatchedRows
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
  const stopwordKey = buildStopwordFilterKey(currentStopwordFilter)
  const stopwordMatcher = getCurrentStopwordMatcher()
  const searchKey = `${normalizedQuery}|${buildSearchOptionsKey(options)}|${stopwordKey}`
  if (visibleCompareRowsCache.rowsRef === currentComparisonRows && visibleCompareRowsCache.searchKey === searchKey) {
    return visibleCompareRowsCache.result
  }
  const queryMatchedRows = !normalizedQuery
    ? currentComparisonRows
    : currentComparisonRows.filter(row => matcher(String(row?.word || '')))
  const rows = stopwordMatcher.enabled
    ? queryMatchedRows.filter(row => stopwordMatcher.matches(String(row?.word || '')))
    : queryMatchedRows
  visibleCompareRowsCache = {
    rowsRef: currentComparisonRows,
    searchKey,
    result: rows
  }
  return rows
}

function getVisibleNgramRows() {
  const { matcher, normalizedQuery, options, error } = getCurrentSearchContext()
  if (error) return []
  const stopwordKey = buildStopwordFilterKey(currentStopwordFilter)
  const stopwordMatcher = getCurrentStopwordMatcher()
  const searchKey = `${normalizedQuery}|${buildSearchOptionsKey(options)}|${stopwordKey}`
  if (visibleNgramRowsCache.rowsRef === currentNgramRows && visibleNgramRowsCache.searchKey === searchKey) {
    return visibleNgramRowsCache.result
  }
  const queryMatchedRows = !normalizedQuery
    ? currentNgramRows
    : currentNgramRows.filter(([phrase]) => matcher(String(phrase || '')))
  const rows = stopwordMatcher.enabled
    ? queryMatchedRows.filter(([phrase]) => stopwordMatcher.matches(String(phrase || '')))
    : queryMatchedRows
  visibleNgramRowsCache = {
    rowsRef: currentNgramRows,
    searchKey,
    result: rows
  }
  return rows
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

  if (!windowHost?.showSystemNotification) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await windowHost.showSystemNotification({
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
  if (!windowHost?.setWindowProgressState) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await windowHost.setWindowProgressState({
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

  if (!windowHost?.setWindowAttentionState) {
    return {
      success: false,
      unavailable: true
    }
  }

  try {
    return await windowHost.setWindowAttentionState({
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

function syncLibrarySelectionWithCurrentCorpora() {
  selectedLibraryCorpusIds = new Set(currentSelectedCorpora.map(item => item.id).filter(Boolean))
}

function updateLoadSelectedCorporaButton() {
  if (!loadSelectedCorporaButton) return
  const buttonState = buildLoadSelectedCorporaButtonState(selectedLibraryCorpusIds.size)
  loadSelectedCorporaButton.disabled = buttonState.disabled
  setButtonLabel(loadSelectedCorporaButton, buttonState.label)
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

function updateLibraryMetaText() {
  if (!libraryMeta) return
  if (currentLibraryFolderId === 'all') {
    libraryMeta.textContent = `共 ${currentLibraryTotalCount || 0} 条本地语料，已整理到 ${currentLibraryFolders.length} 个文件夹中。已选 ${selectedLibraryCorpusIds.size} 条。`
    return
  }

  const folder = getFolderByIdFromList(currentLibraryFolders, currentLibraryFolderId)
  libraryMeta.textContent = `文件夹「${folder ? folder.name : '未分类'}」中共 ${currentLibraryVisibleCount || 0} 条语料。已选 ${selectedLibraryCorpusIds.size} 条。`
}

const searchTabsController = createSearchTabsController({
  dom,
  normalizeSearchOptions,
  getCurrentSearchQuery: () => currentSearchQuery,
  setCurrentSearchQuery: nextQuery => {
    currentSearchQuery = nextQuery
  },
  getCurrentSearchOptions: () => currentSearchOptions,
  setCurrentSearchOptions: nextOptions => {
    currentSearchOptions = nextOptions
  },
  getCurrentStopwordFilter: () => currentStopwordFilter,
  setCurrentStopwordFilter: nextState => {
    currentStopwordFilter = normalizeStopwordFilterState({
      ...currentStopwordFilter,
      ...nextState
    })
  },
  setCurrentTab: nextTab => {
    currentTab = nextTab
  },
  getCurrentFreqRowsLength: () => currentFreqRows.length,
  getCurrentCompareRowsLength: () => currentComparisonRows.length,
  getVisibleFrequencyRows,
  getVisibleCompareRows,
  getVisibleNgramRows,
  invalidateSearchCaches,
  renderFrequencyTable,
  renderCompareSection,
  renderWordCloud,
  renderNgramTable,
  renderSentenceViewer,
  getLocatorNeedsRender: () => locatorNeedsRender,
  getStopwordSummaryText,
  openStopwordEditor: context => openStopwordEditor(context),
  persistStopwordFilterState,
  requestWorkspaceSnapshotSave: (...args) => scheduleWorkspaceSnapshotSave(...args),
  resetSearchDrivenPagination: ({ visibleFrequencyCount, visibleCompareCount, visibleNgramCount }) => {
    pageSize = resolvePageSize(pageSizeSelect.value, visibleFrequencyCount)
    currentPage = 1
    currentComparePageSize = resolvePageSize(comparePageSizeSelect?.value || '10', visibleCompareCount)
    currentComparePage = 1
    currentNgramPageSize = resolvePageSize(ngramPageSizeSelect?.value || '10', visibleNgramCount)
    currentNgramPage = 1
  }
})
const {
  bindSearchAndTabEvents,
  getSearchOptionsSummary,
  getTabLabel,
  setSharedSearchOption,
  setSharedSearchQuery,
  setStopwordFilterValue,
  switchTab,
  syncSearchOptionInputs,
  syncSharedSearchInputs,
  syncStopwordFilterControls
} = searchTabsController
const { bindTableActionEvents } = createTableActionsController({
  dom,
  exportFeedback,
  sortKWICResults: analysisEngine.sortKwicResults,
  getStatsState,
  getNgramState,
  getCompareState,
  getKWICState,
  getCollocateState,
  getLocatorState,
  getCurrentNgramSize: () => currentNgramSize,
  setCurrentKWICSortCache: nextCache => {
    currentKWICSortCache = nextCache
  }
})

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
    void workspaceDocumentService.syncContext({ representedPath: '' })
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
  if (!overflowNode || !smokeHost?.getSmokeObserverState) return
  try {
    const result = await smokeHost.getSmokeObserverState()
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
  electronAPI: updateHost,
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
let workspaceController = null
const openCommand = createOpenCommandController({
  dom,
  taskCenter,
  getRecentOpenEntries: () => workspaceController?.getRecentOpenEntries?.() || [],
  renderRecentOpenList: () => workspaceController?.renderRecentOpenList?.(),
  openRecentOpenEntry: entry => workspaceController?.openRecentOpenEntry?.(entry),
  clearRecentOpenEntries: () => workspaceController?.clearRecentOpenEntries?.(),
  showToast,
  showAlert,
  getErrorMessage,
  escapeHtml,
  getCommandPaletteCommands: () => getCommandPaletteCommands(),
  onQuickOpen: async () => {
    if (!libraryHost?.openQuickCorpus) {
      await showMissingBridge('openQuickCorpus')
      return
    }

    const result = await libraryHost.openQuickCorpus()
    await loadCorpusResult(result)
  },
  onImportAndSave: async () => {
    if (!libraryHost?.importAndSaveCorpus) {
      await showMissingBridge('importAndSaveCorpus')
      return
    }

    const result = await libraryHost.importAndSaveCorpus(getImportTargetFolder().id)
    await loadCorpusResult(result)
    if (isLibraryModalVisible()) {
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
workspaceController = createWorkspaceController({
  electronAPI: workspaceHost,
  persistedState,
  dom,
  recentOpenLimit: RECENT_OPEN_LIMIT,
  defaultWindowSize: DEFAULT_WINDOW_SIZE,
  normalizeSearchOptions,
  hasMeaningfulWorkspaceSnapshot,
  getWorkspaceSnapshotSummary,
  getTabLabel,
  getCurrentUISettings,
  beginBusyState,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  recordDiagnostic,
  refreshDiagnosticsStatusText,
  getDiagnosticRendererState,
  openGitHubFeedbackIssue,
  getErrorMessage,
  loadCorpusResult,
  setOpenCorpusMenuOpen,
  setPreviewCollapsed,
  applySelectControlValue,
  normalizeWindowSizeInput,
  resolvePageSize,
  syncChiSquareInputsFromState,
  renderChiSquareResult,
  syncSearchOptionInputs,
  syncStopwordFilterControls,
  setSharedSearchQuery,
  runNgramAnalysis,
  renderNgramTable,
  switchTab,
  updateCurrentCorpusInfo,
  renderCompareSection,
  renderWordCloud,
  requestWorkspaceRestoreDecision,
  getWorkspaceSnapshotState,
  applyRestoredWorkspaceState,
  workspaceDocumentService
})
const {
  addRecentOpenEntry,
  clearRecentOpenEntries,
  getRecentOpenEntries,
  loadRecentOpenEntries,
  loadStoredWorkspaceSnapshot,
  markWorkspaceSnapshotReady,
  openRecentOpenEntry,
  renderRecentOpenList,
  restoreWorkspaceFromSnapshot,
  runCrashRecoveryWizard,
  scheduleWorkspaceSnapshotSave: workspaceScheduleWorkspaceSnapshotSave,
  setRecentOpenEntries,
  wasStartupRestoreHandledByCrashWizard
} = workspaceController
scheduleWorkspaceSnapshotSave = workspaceScheduleWorkspaceSnapshotSave
const analysisQueueController = createAnalysisQueueController({
  dom,
  taskCenter,
  maxQueueLength: MAX_ANALYSIS_QUEUE_LENGTH,
  formatCount,
  getErrorMessage,
  setButtonLabel,
  showAlert,
  showToast,
  finishTaskEntryWithAttention,
  recordDiagnosticError,
  getActiveCancelableAnalysis: () => activeCancelableAnalysis
})
const {
  cancelQueuedAnalysisTasks,
  enqueueOrRunAnalysisTask,
  ensureTaskCenterRunningEntry,
  getFailedQueueCount,
  getQueuedTaskCount,
  isAnalysisQueuePaused,
  isAnalysisQueueRunning,
  retryFailedQueueTasks,
  runAnalysisQueueIfNeeded,
  toggleAnalysisQueuePaused,
  updateAnalysisQueueControls
} = analysisQueueController
let packagedSmokeAutorunPromise = null

async function getPackagedSmokeConfig() {
  if (!smokeHost?.getPackagedSmokeConfig) return null
  try {
    const result = await smokeHost.getPackagedSmokeConfig()
    return result?.success ? result.config || null : null
  } catch {
    return null
  }
}

async function reportPackagedSmokeResult(payload = {}) {
  if (!smokeHost?.reportPackagedSmokeResult) return null
  try {
    return await smokeHost.reportPackagedSmokeResult(payload)
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
      setStopwordFilterValue({ enabled: false }, { rerender: false })
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
  const buttonState = buildAnalysisActionButtonState({
    isCorpusLoading,
    activeCancelableAnalysis,
    cancellingAnalysis,
    currentAnalysisMode
  })

  countButton.disabled = buttonState.buttons.count.disabled
  if (ngramButton) ngramButton.disabled = buttonState.buttons.ngram.disabled
  kwicButton.disabled = buttonState.buttons.kwic.disabled
  collocateButton.disabled = buttonState.buttons.collocate.disabled

  if (kwicButton) kwicButton.title = buttonState.buttons.kwic.title
  if (collocateButton) collocateButton.title = buttonState.buttons.collocate.title

  const cancelButtons = [
    { button: cancelStatsButton, state: buttonState.buttons.cancelStats },
    { button: cancelKwicButton, state: buttonState.buttons.cancelKwic },
    { button: cancelCollocateButton, state: buttonState.buttons.cancelCollocate }
  ]

  for (const { button, state } of cancelButtons) {
    if (!button || !state) continue
    button.classList.toggle('hidden', state.hidden)
    button.disabled = state.disabled
    setButtonLabel(button, state.label)
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
    if (!isAnalysisQueuePaused() && getQueuedTaskCount() > 0) {
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
    if (appHost?.getAppInfo) {
      try {
        const result = await appHost.getAppInfo()
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

function getStatsState() {
  const currentSearchContext = getCurrentSearchContext()
  return buildStatsState({
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
    currentStopwordFilter,
    currentStopwordSummary: getCurrentStopwordSummaryText(),
    currentPage,
    pageSize,
    currentTokenCount,
    currentTypeCount,
    currentTTR,
    currentSTTR
  })
}

function getCompareState() {
  const currentSearchContext = getCurrentSearchContext()
  return buildCompareState({
    currentSelectedCorpora,
    currentFreqRows,
    currentTokenCount,
    currentComparisonEntries,
    currentComparisonRows,
    currentComparisonCorpora,
    currentDisplayedCompareRows: getVisibleCompareRows(),
    currentSearchQuery,
    currentSearchError: currentSearchContext.error,
    currentStopwordFilter,
    currentStopwordSummary: getCurrentStopwordSummaryText(),
    currentComparePage,
    currentComparePageSize,
    hasStats: currentFreqRows.length > 0 || currentTokenCount > 0,
    comparisonEligible: currentComparisonEntries.length >= 2
  })
}

function getNgramState() {
  const currentSearchContext = getCurrentSearchContext()
  return buildNgramState({
    currentNgramRows,
    currentDisplayedNgramRows: getVisibleNgramRows(),
    currentNgramPage,
    currentNgramPageSize,
    currentSearchQuery,
    currentSearchError: currentSearchContext.error,
    currentStopwordFilter,
    currentStopwordSummary: getCurrentStopwordSummaryText()
  })
}

function getKWICState() {
  return buildKWICState({
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
  })
}

function getCollocateState() {
  return buildCollocateState({
    currentCollocateRows,
    currentCollocatePage,
    currentCollocatePageSize
  })
}

function getLocatorState() {
  return buildLocatorState({
    currentSentenceObjects,
    currentHighlight,
    activeSentenceId,
    pendingLocatorScrollSentenceId
  })
}

const locatorController = createLocatorController({
  dom,
  electronAPI,
  cancelTableRender,
  escapeHtml,
  formatCount,
  renderTableInChunks,
  getLocatorState,
  getCurrentCorpusId: () => currentCorpusId,
  loadCorpusResult,
  showAlert,
  switchTab,
  setActiveSentenceId: nextSentenceId => {
    activeSentenceId = nextSentenceId
  },
  setCurrentHighlight: nextHighlight => {
    currentHighlight = nextHighlight
  },
  setPendingLocatorScrollSentenceId: nextSentenceId => {
    pendingLocatorScrollSentenceId = nextSentenceId
  },
  setLocatorNeedsRender: nextNeedsRender => {
    locatorNeedsRender = nextNeedsRender
  }
})
const {
  bindLocatorEvents,
  locateSentence,
  renderSentenceViewer: renderLocatorSentenceViewer
} = locatorController
renderSentenceViewer = renderLocatorSentenceViewer

function getDiagnosticRendererState() {
  return buildDiagnosticRendererState({
    currentTab,
    currentCorpusMode,
    currentAnalysisMode,
    currentCorpusDisplayName,
    currentCorpusFolderName,
    currentSelectedCorpora,
    currentLibraryFolderId,
    currentLibraryFolders,
    currentLibraryVisibleCount,
    currentLibraryTotalCount,
    currentSearchQuery,
    searchOptionsSummary: getSearchOptionsSummary(),
    currentStopwordFilter,
    currentStopwordSummary: getCurrentStopwordSummaryText(),
    currentTokenCount,
    currentTypeCount,
    currentNgramSize,
    currentNgramRows,
    currentKWICKeyword,
    currentKWICResults,
    currentKWICScopeLabel,
    currentCollocateKeyword,
    currentCollocateRows,
    currentChiSquareResult,
    currentChiSquareInputValues,
    currentSentenceObjects,
    taskCenterEntries: taskCenter.getEntries(),
    startupPhaseEvents,
    currentUISettings: getCurrentUISettings()
  })
}

function getWorkspaceSnapshotState() {
  return {
    currentTab,
    currentLibraryFolderId,
    previewCollapsed: previewPanelBody?.classList.contains('hidden') !== false,
    currentCorpusMode,
    currentSelectedCorpora,
    currentSearchQuery,
    currentSearchOptions,
    stopwordFilter: {
      ...currentStopwordFilter
    },
    statsPageSize: pageSizeSelect?.value || '10',
    comparePageSize: comparePageSizeSelect?.value || '10',
    ngramPageSize: ngramPageSizeSelect?.value || '10',
    ngramSize: ngramSizeSelect?.value || String(currentNgramSize || 2),
    kwicPageSize: kwicPageSizeSelect?.value || '10',
    kwicScope: kwicScopeSelect?.value || 'current',
    kwicSortMode: kwicSortSelect?.value || 'original',
    kwicLeftWindow: leftWindowSelect?.value || String(currentKWICLeftWindow || DEFAULT_WINDOW_SIZE),
    kwicRightWindow: rightWindowSelect?.value || String(currentKWICRightWindow || DEFAULT_WINDOW_SIZE),
    collocatePageSize: collocatePageSizeSelect?.value || '10',
    collocateLeftWindow: collocateLeftWindowSelect?.value || String(currentCollocateLeftWindow || DEFAULT_WINDOW_SIZE),
    collocateRightWindow: collocateRightWindowSelect?.value || String(currentCollocateRightWindow || DEFAULT_WINDOW_SIZE),
    collocateMinFreq: collocateMinFreqSelect?.value || String(currentCollocateMinFreq || 1),
    chiSquare: {
      ...currentChiSquareInputValues
    },
    visibleFrequencyRowCount: getVisibleFrequencyRows().length,
    visibleCompareRowCount: getVisibleCompareRows().length,
    ngramRowCount: currentNgramRows.length,
    kwicResultCount: currentKWICResults.length,
    collocateRowCount: currentCollocateRows.length,
    tokenCount: currentTokens.length
  }
}

function applyRestoredWorkspaceState({
  currentLibraryFolderId: nextLibraryFolderId,
  searchOptions,
  stopwordFilter,
  statsPageSize,
  comparePageSize,
  ngramSize,
  ngramPageSize,
  kwicPageSize,
  collocatePageSize,
  kwicSortMode,
  kwicScope,
  kwicLeftWindow,
  kwicRightWindow,
  collocateLeftWindow,
  collocateRightWindow,
  collocateMinFreq,
  chiSquareInputValues
} = {}) {
  if (typeof nextLibraryFolderId === 'string' && nextLibraryFolderId.trim()) {
    setLibraryFolderSelection(nextLibraryFolderId)
  }
  if (searchOptions && typeof searchOptions === 'object') {
    currentSearchOptions = searchOptions
  }
  if (stopwordFilter && typeof stopwordFilter === 'object') {
    currentStopwordFilter = normalizeStopwordFilterState({
      ...currentStopwordFilter,
      ...stopwordFilter
    })
    persistStopwordFilterState()
  }
  if (Number.isFinite(Number(statsPageSize))) {
    pageSize = Number(statsPageSize)
  }
  if (Number.isFinite(Number(comparePageSize))) {
    currentComparePageSize = Number(comparePageSize)
  }
  if (Number.isFinite(Number(ngramSize))) {
    currentNgramSize = Number(ngramSize)
  }
  if (Number.isFinite(Number(ngramPageSize))) {
    currentNgramPageSize = Number(ngramPageSize)
  }
  if (Number.isFinite(Number(kwicPageSize))) {
    currentKWICPageSize = Number(kwicPageSize)
  }
  if (Number.isFinite(Number(collocatePageSize))) {
    currentCollocatePageSize = Number(collocatePageSize)
  }
  if (typeof kwicSortMode === 'string' && kwicSortMode) {
    currentKWICSortMode = kwicSortMode
  }
  if (typeof kwicScope === 'string' && kwicScope) {
    currentKWICScope = kwicScope
  }
  if (Number.isFinite(Number(kwicLeftWindow))) {
    currentKWICLeftWindow = Number(kwicLeftWindow)
  }
  if (Number.isFinite(Number(kwicRightWindow))) {
    currentKWICRightWindow = Number(kwicRightWindow)
  }
  if (Number.isFinite(Number(collocateLeftWindow))) {
    currentCollocateLeftWindow = Number(collocateLeftWindow)
  }
  if (Number.isFinite(Number(collocateRightWindow))) {
    currentCollocateRightWindow = Number(collocateRightWindow)
  }
  if (Number.isFinite(Number(collocateMinFreq))) {
    currentCollocateMinFreq = Number(collocateMinFreq)
  }
  if (chiSquareInputValues && typeof chiSquareInputValues === 'object') {
    currentChiSquareInputValues = {
      a: String(chiSquareInputValues.a || ''),
      b: String(chiSquareInputValues.b || ''),
      c: String(chiSquareInputValues.c || ''),
      d: String(chiSquareInputValues.d || ''),
      yates: chiSquareInputValues.yates === true
    }
    currentChiSquareResult = null
  }
}

function applySelectControlValue(control, value, fallbackValue) {
  if (!control) return
  const nextValue = String(value || fallbackValue || '')
  const options = Array.from(control.options || []).map(option => option.value)
  control.value = options.includes(nextValue) ? nextValue : String(fallbackValue || control.value || '')
}

function renderWorkspaceShellState() {
  return renderWorkspaceShell(
    {
      currentCorpusMode,
      currentCorpusDisplayName,
      currentCorpusFolderName,
      currentSelectedCorpora,
      statsState: getStatsState()
    },
    dom,
    {
      escapeHtml,
      formatCount
    }
  )
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
    sortResults: analysisEngine.sortKwicResults
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

function setLibraryFolderSelection(folderId) {
  currentLibraryFolderId = persistedState.setLibraryFolderId(folderId || 'all')
  scheduleWorkspaceSnapshotSave()
}

function getImportTargetFolder() {
  return getImportTargetFolderForState(currentLibraryFolderId, currentLibraryFolders)
}

function updateLibraryTargetChip() {
  libraryTargetChip.textContent = getLibraryTargetChipText(currentLibraryFolderId, currentLibraryFolders)
}

function updateCurrentCorpusInfo() {
  renderWorkspaceShellState()
  void syncWindowDocumentContext()
}

function demoteCurrentSavedCorpusToQuick() {
  if (currentCorpusMode !== 'saved' && currentCorpusMode !== 'saved-multi') return
  currentCorpusMode = 'quick'
  currentCorpusId = null
  currentCorpusFolderId = null
  currentCorpusFolderName = ''
  currentSelectedCorpora = []
  void workspaceDocumentService.clearContext()
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
      : await analysisEngine.computeNgrams({
          text: currentText,
          tokens: currentTokens,
          n,
          analysisMode: currentAnalysisMode
        })
    if (!isLatestAnalysisRun('ngram', runId)) return false

    currentNgramSize = Number(ngramResult?.n || n) || n
    currentNgramRows = Array.isArray(ngramResult?.rows) ? ngramResult.rows : []
    currentNgramPageSize = resolvePageSize(ngramPageSizeSelect?.value || '10', getVisibleNgramRows().length)
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
  if (!libraryHost?.searchLibraryKWIC) {
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
    void workspaceDocumentService.syncContextFromCorpusResult(result, {
      displayName: currentCorpusDisplayName
    })

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
      corpusData = await analysisEngine.buildCorpusData(currentText)
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
    syncStopwordFilterControls()
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

  if (!workspaceHost?.openQuickCorpusAtPath) {
    await showMissingBridge('openQuickCorpusAtPath')
    return
  }

  setOpenCorpusMenuOpen(false)
  closeHelpCenterModal()
  closeLibraryModal()
  closeRecycleModal()
  hideWelcomeOverlay({ immediate: true })

  const result = await workspaceHost.openQuickCorpusAtPath(filePath)
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
      title: isAnalysisQueuePaused() ? '恢复任务队列' : '暂停任务队列',
      meta: isAnalysisQueuePaused() ? '继续按顺序自动执行排队任务' : '暂停自动执行，仅保留排队',
      keywords: 'queue pause resume',
      run: async () => {
        toggleAnalysisQueuePaused()
      }
    },
    {
      id: 'retry-failed',
      title: '重试失败任务',
      meta: getFailedQueueCount() > 0 ? `当前有 ${getFailedQueueCount()} 条失败任务` : '当前没有失败任务',
      keywords: 'queue retry failed',
      run: async () => {
        retryFailedQueueTasks()
      }
    },
    {
      id: 'cancel-queued',
      title: '取消排队任务',
      meta: getQueuedTaskCount() > 0 ? `当前有 ${getQueuedTaskCount()} 条排队任务` : '当前没有排队任务',
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
  if (!libraryHost?.importCorpusPaths) {
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
    const result = await libraryHost.importCorpusPaths(droppedPaths, {
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
    if (isLibraryModalVisible()) {
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
    if (!targetPath || !windowHost?.showPathInFolder) return
    const showResult = await windowHost.showPathInFolder(targetPath)
    if (!showResult?.success) {
      showToast(showResult?.message || '无法在系统文件管理器中打开该路径。', {
        title: '系统通知',
        type: 'error'
      })
    }
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

let loadedRecentOpenEntries = []
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
    loadRecentOpenEntries,
    renderWorkspaceShell: renderWorkspaceShellState,
    updateLoadSelectedCorporaButton,
    renderRecentOpenList,
    syncSharedSearchInputs,
    syncSearchOptionInputs,
    syncStopwordFilterControls,
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
  setRecentOpenEntries(loadedRecentOpenEntries)
}

if (appHost?.onSystemOpenFileRequest) {
  appHost.onSystemOpenFileRequest(payload => {
    void enqueueSystemOpenFileRequest(payload)
  })
}

if (appHost?.onAppMenuAction) {
  appHost.onAppMenuAction(payload => {
    void handleAppMenuAction(payload).catch(error => {
      console.error('[app-menu-action]', error)
      recordDiagnosticError('app-menu-action', error, {
        action: String(payload?.action || '').trim()
      })
    })
  })
}

if (appHost?.onSystemNotificationAction) {
  appHost.onSystemNotificationAction(payload => {
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
        if (!appHost?.consumePendingSystemOpenFiles) return
        const pendingOpenResult = await appHost.consumePendingSystemOpenFiles()
        if (!pendingOpenResult?.success || !Array.isArray(pendingOpenResult.filePaths)) return
        for (const filePath of pendingOpenResult.filePaths) {
          await enqueueSystemOpenFileRequest({ filePath })
        }
      },
      initializeAutoUpdate,
      runCrashRecoveryWizard,
      maybeRestoreWorkspaceOnStartup: async () => {
        if (getCurrentUISettings().restoreWorkspace === false || wasStartupRestoreHandledByCrashWizard()) return
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
        markWorkspaceSnapshotReady()
      },
      scheduleWorkspaceSnapshotSave,
      waitForNextFrame: () => new Promise(resolve => requestAnimationFrame(() => resolve())),
      markWelcomeReady
    })

void deferredStartupPromise
  .then(async () => {
    try {
      await maybeRunPackagedSmokeAutorun()
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
    onboardingState = persistedState.markOnboardingTutorialCompleted(onboardingState)
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

async function persistAutoUpdateSettings() {
  const result = await applyAutoUpdatePreferencesFromControls()
  if (!result?.success) {
    await showAlert({
      title: '自动更新设置保存失败',
      message: result?.message || '当前无法保存自动更新设置。'
    })
    return false
  }
  void recordDiagnostic('info', 'auto-update.preferences', '用户更新了自动更新设置。', {
    enabled: autoUpdateEnabledToggle?.checked !== false,
    checkOnLaunch: autoUpdateCheckOnLaunchToggle?.checked !== false,
    autoDownload: autoUpdateAutoDownloadToggle?.checked !== false
  })
  return true
}

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
  if (!updateHost?.checkForUpdates) {
    await showMissingBridge('checkForUpdates')
    return
  }

  const currentAutoUpdateState = getCurrentAutoUpdateState()
  if (currentAutoUpdateState?.state === 'downloaded') {
    await promptInstallDownloadedUpdate(currentAutoUpdateState, { force: true })
    return
  }

  const result = await updateHost.checkForUpdates()
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

  if (!appHost?.openExternalUrl) {
    await showMissingBridge('openExternalUrl')
    return
  }

  const result = await appHost.openExternalUrl(currentAppInfo.repositoryUrl)
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
  toggleAnalysisQueuePaused()
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
  if (event.key === 'Escape' && stopwordModal && !stopwordModal.classList.contains('hidden')) {
    closeStopwordEditor()
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
  void refreshSystemAppearanceState({ force: false })
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
  void refreshAutoUpdatePreferences({ silent: true })
})

stopwordModal?.addEventListener('click', event => {
  if (event.target === stopwordModal) closeStopwordEditor()
})

stopwordListTextarea?.addEventListener('input', () => {
  updateStopwordListCount(stopwordListTextarea.value)
})

closeStopwordModalButton?.addEventListener('click', () => {
  closeStopwordEditor()
})

resetStopwordListButton?.addEventListener('click', () => {
  if (!stopwordListTextarea) return
  stopwordListTextarea.value = DEFAULT_STOPWORD_LIST_TEXT.trim()
  updateStopwordListCount(stopwordListTextarea.value)
})

clearStopwordListButton?.addEventListener('click', () => {
  if (!stopwordListTextarea) return
  stopwordListTextarea.value = ''
  updateStopwordListCount(stopwordListTextarea.value)
})

saveStopwordListButton?.addEventListener('click', () => {
  setStopwordFilterValue({
    listText: stopwordListTextarea?.value || ''
  })
  closeStopwordEditor()
})

closeUiSettingsButton.addEventListener('click', () => {
  closeUISettingsModal()
})

resetUiSettingsButton.addEventListener('click', () => {
  applyUISettings(DEFAULT_UI_SETTINGS)
  applyTheme(DEFAULT_THEME)
  if (autoUpdateEnabledToggle) {
    autoUpdateEnabledToggle.checked = true
  }
  if (autoUpdateCheckOnLaunchToggle) {
    autoUpdateCheckOnLaunchToggle.checked = true
  }
  if (autoUpdateAutoDownloadToggle) {
    autoUpdateAutoDownloadToggle.checked = true
  }
  void persistAutoUpdateSettings()
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

uiAccentSelect?.addEventListener('change', () => {
  applyUISettingsFromControls()
  void refreshSystemAppearanceState({ force: true })
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

autoUpdateEnabledToggle?.addEventListener('change', () => {
  void persistAutoUpdateSettings()
})

autoUpdateCheckOnLaunchToggle?.addEventListener('change', () => {
  void persistAutoUpdateSettings()
})

autoUpdateAutoDownloadToggle?.addEventListener('change', () => {
  void persistAutoUpdateSettings()
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

bindDiagnosticsEvents()

refreshAnalysisCacheButton?.addEventListener('click', () => {
  void refreshAnalysisCacheState()
})

rebuildAnalysisCacheButton?.addEventListener('click', () => {
  void rebuildCurrentAnalysisCache()
})

clearAnalysisCacheButton?.addEventListener('click', async () => {
  if (!cacheHost?.clearAnalysisCache) {
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

  const result = await cacheHost.clearAnalysisCache()
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

bindLibraryManagerEvents()

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
      : await analysisEngine.computeStats({
          text: currentText,
          tokens: currentTokens,
          comparisonEntries: shouldCompareAcrossCorpora ? currentComparisonEntries : [],
          analysisMode: currentAnalysisMode,
          compareSignature,
          taskName: 'stats'
        })
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

bindSearchAndTabEvents()

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
      currentChiSquareResult = analysisEngine.calculateChiSquare(readChiSquareInputNumbers())
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
    currentChiSquareResult = analysisEngine.calculateChiSquare(inputValues)
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
  currentNgramPageSize = resolvePageSize(ngramPageSizeSelect.value, getVisibleNgramRows().length)
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
  const totalPages = Math.ceil(getVisibleNgramRows().length / currentNgramPageSize)
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
          libraryHost.searchLibraryKWIC({
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
      currentKWICResults = await analysisEngine.searchKwic({
        tokenObjects: currentTokenObjects,
        keyword,
        leftWindowSize,
        rightWindowSize,
        searchOptions,
        taskName: 'kwic'
      })
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
    currentCollocateRows = await analysisEngine.searchCollocates({
      tokenObjects: currentTokenObjects,
      tokens: currentTokens,
      keyword,
      leftWindowSize,
      rightWindowSize,
      minFreq,
      searchOptions,
      taskName: 'collocate'
    })
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

bindTableActionEvents()
bindLocatorEvents()

wordCloudWrapper?.addEventListener('click', event => {
  const target = event.target.closest('[data-word-cloud-term]')
  if (!target) return
  const query = target.dataset.wordCloudTerm || ''
  if (!query) return
  setSharedSearchQuery(query)
})
