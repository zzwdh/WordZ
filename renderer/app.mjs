import {
  compareCorpusFrequencies,
  buildTokenMatcher,
  buildCorpusData,
  calculateSTTR,
  calculateTTR,
  countWordFrequency,
  getSortedFrequencyRows,
  normalizeSearchOptions,
  getSortedKWICResults as sortKWICResults,
  searchLibraryKWIC,
  searchCollocates,
  searchKWIC
} from '../analysisCore.mjs'
import {
  ANALYSIS_TASK_TYPES,
  BUTTON_ICONS,
  DEFAULT_THEME,
  DEFAULT_UI_SETTINGS,
  DEFAULT_WINDOW_SIZE,
  LARGE_TABLE_THRESHOLD,
  LIBRARY_FOLDER_STORAGE_KEY,
  PREVIEW_CHAR_LIMIT,
  RECENT_OPEN_STORAGE_KEY,
  TABLE_RENDER_CHUNK_SIZE,
  UI_FONT_FAMILIES,
  UI_SETTINGS_STORAGE_KEY,
  WORKSPACE_STATE_STORAGE_KEY
} from './constants.mjs'
import { dom } from './domRefs.mjs'
import { createAnalysisBridge } from './analysisBridge.mjs'
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

const {
  welcomeRestorePrompt,
  welcomeRestoreSummary,
  restoreWorkspaceButton,
  skipWorkspaceRestoreButton,
  appTitleHeading,
  appSubtitle,
  settingsPreviewText,
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
  wordCloudWrapper,
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
  wordCloudSection,
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
  uiSettingsModal,
  uiZoomRange,
  uiFontSizeRange,
  uiFontFamilySelect,
  restoreWorkspaceToggle,
  lightThemeButton,
  darkThemeButton,
  debugLoggingToggle,
  diagnosticsStatusText,
  exportDiagnosticsButton,
  reportIssueButton,
  resetUiSettingsButton,
  closeUiSettingsButton,
  feedbackModal
} = dom

const DEFAULT_APP_INFO = Object.freeze({
  name: 'WordZ',
  version: '',
  description: '',
  author: '',
  releaseChannel: 'stable',
  releaseChannelLabel: '稳定版',
  autoUpdateConfigured: false,
  autoUpdateProvider: '',
  autoUpdateProviderLabel: '',
  autoUpdateTarget: '',
  help: [],
  releaseNotes: []
})

const APP_FEATURE_SUMMARY = '支持 txt / docx / pdf 导入、词频统计、多语料对比分析、跨语料库 KWIC、Collocate、原文定位，以及本地语料库分类、备份、恢复、修复与自动更新。'
const APP_SUBTITLE_TEXT = '本地语料工作台 · 打开、统计、检索与导出'

const {
  beginBusyState,
  nextAnalysisRun,
  isLatestAnalysisRun,
  runAnalysisTask,
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
const exportFeedback = { showAlert, showToast }
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
let taskCenterOpen = false
let openCorpusMenuOpen = false
let taskCenterEntrySeq = 0
let taskCenterEntries = []
let currentAutoUpdateState = null
let announcedAvailableVersion = ''
let promptedDownloadedVersion = ''
let welcomeOverlayVisible = false
let welcomeReady = false
let pendingWorkspaceRestoreSnapshot = null
let startupRestoreDecisionResolver = null
let workspaceSnapshotTimer = null
let workspaceSnapshotReady = false
let workspaceRestoreInProgress = false
let recentOpenEntries = []
const activeTaskCenterEntryIds = new Map()
const TASK_CENTER_LIMIT = 8
const WORKSPACE_SNAPSHOT_VERSION = 1
const RECENT_OPEN_LIMIT = 8
const taskCenterTimeFormatter = new Intl.DateTimeFormat('zh-CN', {
  hour: '2-digit',
  minute: '2-digit'
})

function invalidateKWICSortCache() {
  currentKWICSortCache = { source: null, mode: 'original', rows: [] }
}

function getCurrentSearchContext() {
  return buildTokenMatcher(currentSearchQuery, currentSearchOptions)
}

function getVisibleFrequencyRows() {
  const { matcher, normalizedQuery, error } = getCurrentSearchContext()
  if (error) return []
  if (!normalizedQuery) return currentFreqRows
  return currentFreqRows.filter(([word]) => matcher(String(word || '')))
}

function getVisibleCompareRows() {
  const { matcher, normalizedQuery, error } = getCurrentSearchContext()
  if (error) return []
  if (!normalizedQuery) return currentComparisonRows
  return currentComparisonRows.filter(row => matcher(String(row?.word || '')))
}

function getTabLabel(tabName) {
  if (tabName === 'compare') return '对比分析'
  if (tabName === 'word-cloud') return '词云'
  if (tabName === 'kwic') return 'KWIC 检索'
  if (tabName === 'collocate') return 'Collocate 统计'
  if (tabName === 'locator') return '原文定位'
  return '统计结果'
}

function normalizeRecentOpenEntry(rawEntry) {
  if (!rawEntry || typeof rawEntry !== 'object') return null
  const type = ['quick', 'saved', 'saved-multi'].includes(rawEntry.type) ? rawEntry.type : ''
  if (!type) return null

  const label = String(rawEntry.label || '').trim()
  if (!label) return null

  const corpusIds = Array.isArray(rawEntry.corpusIds)
    ? rawEntry.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const filePath = String(rawEntry.filePath || '').trim()
  const corpusId = String(rawEntry.corpusId || '').trim()
  const entryKey = String(rawEntry.key || '').trim() || (
    type === 'quick'
      ? `quick:${filePath}`
      : type === 'saved'
        ? `saved:${corpusId}`
        : `saved-multi:${[...corpusIds].sort().join(',')}`
  )

  if (!entryKey) return null
  if (type === 'quick' && !filePath) return null
  if (type === 'saved' && !corpusId) return null
  if (type === 'saved-multi' && corpusIds.length === 0) return null

  return {
    key: entryKey,
    type,
    label,
    detail: String(rawEntry.detail || '').trim(),
    filePath,
    corpusId,
    corpusIds,
    sourceType: String(rawEntry.sourceType || '').trim(),
    openedAt: String(rawEntry.openedAt || '').trim() || new Date().toISOString()
  }
}

function loadRecentOpenEntries() {
  try {
    const rawValue = localStorage.getItem(RECENT_OPEN_STORAGE_KEY)
    if (!rawValue) return []
    const parsedValue = JSON.parse(rawValue)
    if (!Array.isArray(parsedValue)) return []
    return parsedValue
      .map(normalizeRecentOpenEntry)
      .filter(Boolean)
      .slice(0, RECENT_OPEN_LIMIT)
  } catch (error) {
    console.warn('[recent-open.load]', error)
    return []
  }
}

function persistRecentOpenEntries() {
  try {
    localStorage.setItem(RECENT_OPEN_STORAGE_KEY, JSON.stringify(recentOpenEntries.slice(0, RECENT_OPEN_LIMIT)))
  } catch (error) {
    console.warn('[recent-open.save]', error)
  }
}

function getRecentOpenTypeLabel(type) {
  if (type === 'quick') return '外部文件'
  if (type === 'saved-multi') return '多语料'
  return '本地语料'
}

function renderRecentOpenList() {
  if (!recentOpenSection || !recentOpenList) return

  recentOpenSection.classList.toggle('hidden', recentOpenEntries.length === 0)
  if (clearRecentOpenButton) clearRecentOpenButton.disabled = recentOpenEntries.length === 0

  if (recentOpenEntries.length === 0) {
    recentOpenList.innerHTML = '<div class="recent-open-empty">最近打开的语料会显示在这里。</div>'
    return
  }

  recentOpenList.innerHTML = recentOpenEntries
    .map((entry, index) => `
      <button class="recent-open-item" type="button" data-recent-open-index="${index}">
        <span class="recent-open-item-head">
          <span class="recent-open-item-title">${escapeHtml(entry.label)}</span>
          <span class="recent-open-badge">${escapeHtml(getRecentOpenTypeLabel(entry.type))}</span>
        </span>
        <span class="recent-open-item-detail">${escapeHtml(entry.detail || '点击后重新载入该语料')}</span>
      </button>
    `)
    .join('')
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

function buildRecentOpenEntryFromResult(result) {
  if (!result?.success) return null

  if (result.mode === 'quick') {
    const filePath = String(result.filePath || '').trim()
    if (!filePath) return null
    const sourceLabel = String(result.sourceEncoding || '').trim()
    return {
      key: `quick:${filePath}`,
      type: 'quick',
      label: String(result.displayName || result.fileName || '外部文件').trim(),
      detail: sourceLabel ? `${String(result.fileName || filePath).trim()} · ${sourceLabel}` : String(result.fileName || filePath).trim(),
      filePath,
      sourceType: String(result.sourceType || '').trim(),
      openedAt: new Date().toISOString()
    }
  }

  if (result.mode === 'saved-multi') {
    const corpusIds = Array.isArray(result.corpusIds)
      ? result.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
      : []
    if (corpusIds.length === 0) return null
    const selectedItems = Array.isArray(result.selectedItems) ? result.selectedItems : []
    const itemNames = selectedItems.map(item => String(item?.name || '').trim()).filter(Boolean)
    const previewNames = itemNames.slice(0, 2).join('、')
    const remainingCount = Math.max(itemNames.length - 2, 0)
    const detailParts = []
    if (previewNames) detailParts.push(remainingCount > 0 ? `${previewNames} 等 ${itemNames.length} 条语料` : previewNames)
    if (result.folderName) detailParts.push(String(result.folderName).trim())
    return {
      key: `saved-multi:${[...corpusIds].sort().join(',')}`,
      type: 'saved-multi',
      label: String(result.displayName || `已选 ${corpusIds.length} 条语料`).trim(),
      detail: detailParts.join(' · ') || `共 ${corpusIds.length} 条已保存语料`,
      corpusIds,
      openedAt: new Date().toISOString()
    }
  }

  const corpusId = String(result.corpusId || '').trim()
  if (!corpusId) return null
  const detailParts = []
  if (result.folderName) detailParts.push(String(result.folderName).trim())
  if (result.sourceEncoding) detailParts.push(String(result.sourceEncoding).trim())
  return {
    key: `saved:${corpusId}`,
    type: 'saved',
    label: String(result.displayName || result.fileName || '已保存语料').trim(),
    detail: detailParts.join(' · ') || '本地语料库',
    corpusId,
    openedAt: new Date().toISOString()
  }
}

function getWorkspaceSnapshotSummary(snapshot) {
  const corpusNames = Array.isArray(snapshot?.workspace?.corpusNames)
    ? snapshot.workspace.corpusNames.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const summaryParts = []
  if (corpusNames.length > 0) {
    const namesPreview = corpusNames.slice(0, 2).join('、')
    summaryParts.push(corpusNames.length > 2 ? `${namesPreview} 等 ${corpusNames.length} 条语料` : namesPreview)
  } else if (snapshot?.workspace?.corpusIds?.length > 0) {
    summaryParts.push(`已保存语料 ${snapshot.workspace.corpusIds.length} 条`)
  }

  summaryParts.push(getTabLabel(getRestorableTabFromSnapshot(snapshot)))

  if (snapshot?.search?.query) {
    summaryParts.push(`搜索词：${snapshot.search.query}`)
  }

  return summaryParts.join(' · ') || '上次工作区包含已保存语料与检索状态。'
}

function setWelcomeRestorePromptSnapshot(snapshot) {
  pendingWorkspaceRestoreSnapshot = snapshot || null
  if (welcomeRestorePrompt) welcomeRestorePrompt.classList.toggle('hidden', !snapshot)
  if (welcomeRestoreSummary) {
    welcomeRestoreSummary.textContent = snapshot ? getWorkspaceSnapshotSummary(snapshot) : ''
  }
}

function hasMeaningfulWorkspaceSnapshot(snapshot) {
  if (!snapshot) return false
  return Array.isArray(snapshot.workspace?.corpusIds) && snapshot.workspace.corpusIds.length > 0
}

function resolveStartupRestoreDecision(shouldRestore) {
  const resolver = startupRestoreDecisionResolver
  startupRestoreDecisionResolver = null
  setWelcomeRestorePromptSnapshot(null)
  if (typeof resolver === 'function') resolver(Boolean(shouldRestore))
}

async function requestWorkspaceRestoreDecision(snapshot) {
  if (!snapshot || !hasMeaningfulWorkspaceSnapshot(snapshot)) return false
  const title = '检测到上次会话'
  const message = `${getWorkspaceSnapshotSummary(snapshot)}\n\n是否恢复上次工作区？`

  if (getCurrentUISettings().showWelcomeScreen !== false && welcomeOverlayVisible && welcomeRestorePrompt) {
    setWelcomeProgress(74, '检测到上次工作区，请选择是否恢复。', title)
    setWelcomeRestorePromptSnapshot(snapshot)
    return new Promise(resolve => {
      startupRestoreDecisionResolver = resolve
    })
  }

  return showConfirm({
    title,
    message,
    confirmText: '恢复上次会话',
    cancelText: '从空白开始'
  })
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
  syncSharedSearchInputs()
  scheduleWorkspaceSnapshotSave()
  if (rerender) {
    rerenderSearchDrivenViews()
  }
}

function setSharedSearchOption(optionName, checked, { rerender = true } = {}) {
  if (optionName === 'words') currentSearchOptions.words = Boolean(checked)
  else if (optionName === 'case') currentSearchOptions.caseSensitive = Boolean(checked)
  else if (optionName === 'regex') currentSearchOptions.regex = Boolean(checked)
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

function formatTaskCenterTime(timestamp) {
  return taskCenterTimeFormatter.format(new Date(timestamp))
}

function formatTaskCenterDuration(durationMs) {
  const normalizedDuration = Math.max(0, Number(durationMs) || 0)
  if (normalizedDuration < 1000) return `${normalizedDuration}ms`
  if (normalizedDuration < 10000) return `${(normalizedDuration / 1000).toFixed(1)}s`
  if (normalizedDuration < 60000) return `${Math.round(normalizedDuration / 1000)}s`
  const minutes = Math.floor(normalizedDuration / 60000)
  const seconds = Math.round((normalizedDuration % 60000) / 1000)
  return `${minutes}m ${seconds}s`
}

function getTaskCenterStatusLabel(status) {
  if (status === 'running') return '进行中'
  if (status === 'success') return '已完成'
  if (status === 'cancelled') return '已取消'
  return '失败'
}

function updateTaskCenterButtonLabel() {
  if (!taskCenterButton) return
  const activeCount = taskCenterEntries.filter(entry => entry.status === 'running').length
  setButtonLabel(taskCenterButton, activeCount > 0 ? `任务（${activeCount}）` : '任务')
}

function setTaskCenterOpen(open) {
  if (!taskCenterPanel || !taskCenterButton) return
  taskCenterOpen = Boolean(open)
  taskCenterPanel.classList.toggle('hidden', !taskCenterOpen)
  taskCenterButton.setAttribute('aria-expanded', String(taskCenterOpen))
}

function setOpenCorpusMenuOpen(open) {
  if (!openCorpusMenuButton || !openCorpusMenuPanel) return
  openCorpusMenuOpen = Boolean(open)
  if (openCorpusMenuOpen) renderRecentOpenList()
  openCorpusMenuPanel.classList.toggle('hidden', !openCorpusMenuOpen)
  openCorpusMenuButton.setAttribute('aria-expanded', String(openCorpusMenuOpen))
}

function renderTaskCenter() {
  if (!taskCenterList || !taskCenterMeta) return

  const activeCount = taskCenterEntries.filter(entry => entry.status === 'running').length
  if (activeCount > 0) {
    taskCenterMeta.textContent = `运行中 ${activeCount} 项，已保留最近 ${taskCenterEntries.length} 条记录。`
  } else if (taskCenterEntries.length > 0) {
    taskCenterMeta.textContent = `最近 ${taskCenterEntries.length} 条分析任务记录。`
  } else {
    taskCenterMeta.textContent = '最近的分析任务会显示在这里。'
  }

  if (taskCenterEntries.length === 0) {
    taskCenterList.innerHTML = '<div class="task-center-empty">最近的统计、KWIC 和 Collocate 任务会显示在这里。</div>'
    updateTaskCenterButtonLabel()
    return
  }

  taskCenterList.innerHTML = taskCenterEntries
    .map(entry => {
      const metaText = entry.status === 'running'
        ? `开始于 ${formatTaskCenterTime(entry.startedAt)}`
        : `${formatTaskCenterTime(entry.finishedAt || entry.startedAt)} · 用时 ${formatTaskCenterDuration(entry.durationMs)}`

      return `
        <article class="task-center-item">
          <div class="task-center-item-head">
            <div class="task-center-title">${escapeHtml(entry.title)}</div>
            <span class="task-center-status is-${escapeHtml(entry.status)}">${escapeHtml(getTaskCenterStatusLabel(entry.status))}</span>
          </div>
          <div class="task-center-detail">${escapeHtml(entry.detail)}</div>
          <div class="task-center-item-meta">${escapeHtml(metaText)}</div>
        </article>
      `
    })
    .join('')

  updateTaskCenterButtonLabel()
}

function startTaskCenterEntry(taskKey, title, detail) {
  const entryId = `task-${++taskCenterEntrySeq}`
  const entry = {
    id: entryId,
    taskKey,
    title,
    detail,
    status: 'running',
    startedAt: Date.now(),
    finishedAt: null,
    durationMs: 0
  }

  taskCenterEntries = [entry, ...taskCenterEntries].slice(0, TASK_CENTER_LIMIT)
  activeTaskCenterEntryIds.set(taskKey, entryId)
  renderTaskCenter()
  return entryId
}

function updateTaskCenterEntry(entryId, patch) {
  let hasUpdated = false
  taskCenterEntries = taskCenterEntries.map(entry => {
    if (entry.id !== entryId) return entry
    hasUpdated = true
    return { ...entry, ...patch }
  })
  if (hasUpdated) renderTaskCenter()
}

function updateActiveTaskCenterEntry(taskKey, patch) {
  const entryId = activeTaskCenterEntryIds.get(taskKey)
  if (!entryId) return
  updateTaskCenterEntry(entryId, patch)
}

function finishTaskCenterEntry(taskKey, status, detail) {
  const entryId = activeTaskCenterEntryIds.get(taskKey)
  if (!entryId) return

  const entry = taskCenterEntries.find(item => item.id === entryId)
  if (!entry) {
    activeTaskCenterEntryIds.delete(taskKey)
    return
  }

  updateTaskCenterEntry(entryId, {
    status,
    detail,
    finishedAt: Date.now(),
    durationMs: Date.now() - entry.startedAt
  })
  activeTaskCenterEntryIds.delete(taskKey)
}

function setButtonLabel(button, label) {
  if (!button) return
  const labelNode = button.querySelector('.button-content span:last-child')
  if (labelNode) labelNode.textContent = label
  else button.textContent = label
}

function syncWelcomePreferenceCheckboxes() {
  const enabled = getCurrentUISettings().showWelcomeScreen !== false
  if (dom.showWelcomeScreenToggle) dom.showWelcomeScreenToggle.checked = enabled
  if (dom.welcomeDisableCheckbox) dom.welcomeDisableCheckbox.checked = !enabled
}

function syncWelcomeStartButton() {
  if (!dom.closeWelcomeButton) return
  dom.closeWelcomeButton.disabled = !welcomeReady
  setButtonLabel(dom.closeWelcomeButton, welcomeReady ? '开始使用' : '正在准备...')
}

function updateWelcomeContent() {
  if (dom.welcomeTitle) dom.welcomeTitle.textContent = `欢迎使用 ${currentAppInfo.name}`
  if (dom.welcomeSubtitle) {
    dom.welcomeSubtitle.textContent = getAppAboutDescription()
  }
  if (dom.welcomeFeatureSummary) {
    dom.welcomeFeatureSummary.textContent = APP_FEATURE_SUMMARY
  }
  const versionText = currentAppInfo.version ? `当前版本 v${currentAppInfo.version}` : '正在读取版本...'
  if (dom.topbarVersionBadge) dom.topbarVersionBadge.textContent = versionText
  if (dom.welcomeVersionBadge) dom.welcomeVersionBadge.textContent = versionText
}

function setWelcomeProgress(progress, text, title = text) {
  const safeProgress = Math.max(0, Math.min(100, Number(progress) || 0))
  if (dom.welcomeProgressFill) dom.welcomeProgressFill.style.width = `${safeProgress}%`
  if (dom.welcomeProgressPercent) dom.welcomeProgressPercent.textContent = `${Math.round(safeProgress)}%`
  if (dom.welcomeProgressText) dom.welcomeProgressText.textContent = text
  if (dom.welcomeProgressTitle) dom.welcomeProgressTitle.textContent = title
}

function showWelcomeOverlay() {
  if (!dom.welcomeOverlay || getCurrentUISettings().showWelcomeScreen === false) return
  welcomeOverlayVisible = true
  welcomeReady = false
  setWelcomeRestorePromptSnapshot(null)
  dom.welcomeOverlay.classList.remove('hidden')
  document.body.classList.add('welcome-open')
  syncWelcomePreferenceCheckboxes()
  syncWelcomeStartButton()
}

function hideWelcomeOverlay({ immediate = false } = {}) {
  if (!dom.welcomeOverlay || !welcomeOverlayVisible) return
  void immediate
  dom.welcomeOverlay.classList.add('hidden')
  document.body.classList.remove('welcome-open')
  welcomeOverlayVisible = false
  setWelcomeRestorePromptSnapshot(null)
}

function markWelcomeReady() {
  welcomeReady = true
  setWelcomeProgress(100, `准备完成，点击“开始使用”进入 ${currentAppInfo.name}。`, '工作台已准备就绪')
  syncWelcomeStartButton()
}

function getAutoUpdateButtonLabel(updateState) {
  if (!updateState) return '更新'
  if (updateState.state === 'checking') return '检查中...'
  if (updateState.state === 'downloading') {
    const progressPercent = Math.round(Number(updateState.progressPercent) || 0)
    return progressPercent > 0 ? `下载 ${progressPercent}%` : '下载中...'
  }
  if (updateState.state === 'downloaded') return '安装更新'
  return '更新'
}

function applyAutoUpdateButtonState(updateState = null) {
  if (!checkUpdateButton) return
  currentAutoUpdateState = updateState
  setButtonLabel(checkUpdateButton, getAutoUpdateButtonLabel(updateState))
  checkUpdateButton.disabled = updateState?.state === 'checking' || updateState?.state === 'downloading'
}

async function promptInstallDownloadedUpdate(updateState = currentAutoUpdateState, { force = false } = {}) {
  if (!updateState || updateState.state !== 'downloaded') return
  const targetVersion = updateState.downloadedVersion || updateState.availableVersion || ''
  if (!force && targetVersion && promptedDownloadedVersion === targetVersion) return
  if (targetVersion) promptedDownloadedVersion = targetVersion

  const releaseNotes = Array.isArray(updateState.releaseNotes) ? updateState.releaseNotes : []
  const messageLines = [
    `新版本 ${targetVersion || '已下载完成'} 已准备好。`,
    '现在重启应用即可完成安装。'
  ]
  if (releaseNotes.length > 0) {
    messageLines.push('', '更新内容')
    for (const item of releaseNotes.slice(0, 5)) {
      messageLines.push(`- ${item}`)
    }
  }

  const confirmed = await showConfirm({
    title: '安装更新',
    message: messageLines.join('\n'),
    confirmText: '立即重启安装',
    cancelText: '稍后'
  })
  if (!confirmed) return

  const result = await window.electronAPI.installDownloadedUpdate()
  if (!result.success) {
    await showAlert({
      title: '安装更新失败',
      message: result.message || '当前无法安装更新'
    })
  }
}

async function handleAutoUpdateStatus(updateState, { announce = true, promptOnDownloaded = false } = {}) {
  applyAutoUpdateButtonState(updateState)
  if (!updateState) return

  if (announce) {
    if (updateState.state === 'downloading' && updateState.availableVersion && announcedAvailableVersion !== updateState.availableVersion) {
      announcedAvailableVersion = updateState.availableVersion
      showToast(`发现新版本 ${updateState.availableVersion}，正在后台下载。`, {
        title: '自动更新',
        type: 'success',
        duration: 3600
      })
    }

    if (updateState.state === 'error' && updateState.enabled) {
      showToast(updateState.message || '自动更新失败。', {
        title: '更新失败',
        type: 'error',
        duration: 4200
      })
    }
  }

  if (promptOnDownloaded && updateState.state === 'downloaded') {
    await promptInstallDownloadedUpdate(updateState)
  }
}

async function initializeAutoUpdate() {
  if (!window.electronAPI?.getAutoUpdateState) {
    applyAutoUpdateButtonState(null)
    return
  }

  const stateResult = await window.electronAPI.getAutoUpdateState()
  if (stateResult?.success && stateResult.updateState) {
    await handleAutoUpdateStatus(stateResult.updateState, { announce: false, promptOnDownloaded: false })
  } else {
    applyAutoUpdateButtonState(null)
  }

  if (window.electronAPI?.onAutoUpdateStatus) {
    window.electronAPI.onAutoUpdateStatus(updateState => {
      void handleAutoUpdateStatus(updateState, { announce: true, promptOnDownloaded: true })
    })
  }
}

function updateAnalysisActionButtons() {
  const disablePrimaryActions = isCorpusLoading || Boolean(activeCancelableAnalysis)
  countButton.disabled = disablePrimaryActions
  kwicButton.disabled = disablePrimaryActions
  collocateButton.disabled = disablePrimaryActions

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
  }
}

function requestCancelAnalysis(taskName, busyMessage, cancelMessage) {
  if (!isAnalysisTaskActive(taskName)) return false
  cancellingAnalysis = taskName
  updateAnalysisActionButtons()
  if (systemStatusText) systemStatusText.textContent = busyMessage
  updateActiveTaskCenterEntry(taskName, { detail: busyMessage })
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

function normalizeAppInfo(rawInfo = {}) {
  const normalizedName = String(rawInfo.name || '').trim() || DEFAULT_APP_INFO.name
  return {
    name: normalizedName,
    version: String(rawInfo.version || '').trim(),
    description: String(rawInfo.description || '').trim(),
    author: String(rawInfo.author || '').trim(),
    releaseChannel: String(rawInfo.releaseChannel || 'stable').trim() || 'stable',
    releaseChannelLabel: String(rawInfo.releaseChannelLabel || '稳定版').trim() || '稳定版',
    autoUpdateConfigured: Boolean(rawInfo.autoUpdateConfigured),
    autoUpdateProvider: String(rawInfo.autoUpdateProvider || '').trim(),
    autoUpdateProviderLabel: String(rawInfo.autoUpdateProviderLabel || '').trim(),
    autoUpdateTarget: String(rawInfo.autoUpdateTarget || '').trim(),
    help: Array.isArray(rawInfo.help)
      ? rawInfo.help.map(item => String(item).trim()).filter(Boolean)
      : [],
    releaseNotes: Array.isArray(rawInfo.releaseNotes)
      ? rawInfo.releaseNotes.map(item => String(item).trim()).filter(Boolean)
      : []
  }
}

function getAppAboutDescription() {
  const description = String(currentAppInfo.description || '').trim()
  if (!description || description === currentAppInfo.name) {
    return '一个本地桌面语料分析工具。'
  }
  return description
}

function applyAppInfoToShell() {
  document.title = currentAppInfo.name
  if (appTitleHeading) appTitleHeading.textContent = currentAppInfo.name
  if (appSubtitle) appSubtitle.textContent = APP_SUBTITLE_TEXT
  if (settingsPreviewText) {
    settingsPreviewText.textContent = `${currentAppInfo.name} Corpus Helper 123 ABC。这里会实时预览你当前选择的字体和字号效果。`
  }
  updateWelcomeContent()
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

function buildAboutMessage() {
  const autoUpdateLabel =
    currentAppInfo.autoUpdateProviderLabel ||
    (currentAppInfo.autoUpdateProvider === 'github'
      ? 'GitHub Releases'
      : currentAppInfo.autoUpdateProvider === 'generic'
        ? '通用更新源'
        : '自动更新')
  const autoUpdateTarget = currentAppInfo.autoUpdateTarget ? `（${currentAppInfo.autoUpdateTarget}）` : ''
  const lines = [
    currentAppInfo.name,
    '',
    getAppAboutDescription(),
    APP_FEATURE_SUMMARY
  ]

  if (currentAppInfo.author) {
    lines.push(`作者：${currentAppInfo.author}`)
  }

  lines.push('', `当前版本：${currentAppInfo.version || '未知版本'}`)
  lines.push(`发布渠道：${currentAppInfo.releaseChannelLabel || '稳定版'}`)
  lines.push(`自动更新：${autoUpdateLabel}${autoUpdateTarget}`)
  lines.push(`更新源状态：${currentAppInfo.autoUpdateConfigured ? '已配置' : '尚未配置'}`)

  if (currentAppInfo.help.length > 0) {
    lines.push('', '帮助')
    for (const item of currentAppInfo.help) {
      lines.push(`- ${item}`)
    }
  }

  if (currentAppInfo.releaseNotes.length > 0) {
    lines.push('', '发布说明')
    for (const item of currentAppInfo.releaseNotes) {
      lines.push(`- ${item}`)
    }
  }

  return lines.join('\n')
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
  decorateButton(copyStatsButton, 'export')
  decorateButton(copyFreqButton, 'export')
  decorateButton(exportAllFreqButton, 'exportAll')
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
  decorateButton(resetUiSettingsButton, 'reset')
  decorateButton(closeUiSettingsButton, 'close')
  decorateButton(closeLibraryButton, 'close')
  decorateButton(closeRecycleButton, 'close')
  decorateButton(lightThemeButton, 'sun')
  decorateButton(darkThemeButton, 'moon')
}

function decorateLibraryControls() {
  libraryFolderList.querySelectorAll('[data-rename-folder-id]').forEach(button => decorateButton(button, 'edit'))
  libraryFolderList.querySelectorAll('[data-delete-folder-id]').forEach(button => decorateButton(button, 'delete'))
  libraryTableWrapper.querySelectorAll('[data-open-corpus-id]').forEach(button => decorateButton(button, 'open'))
  libraryTableWrapper.querySelectorAll('[data-rename-corpus-id]').forEach(button => decorateButton(button, 'edit'))
  libraryTableWrapper.querySelectorAll('[data-move-corpus-id]').forEach(button => decorateButton(button, 'move'))
  libraryTableWrapper.querySelectorAll('[data-delete-corpus-id]').forEach(button => decorateButton(button, 'delete'))
}

function decorateRecycleControls() {
  recycleTableWrapper.querySelectorAll('[data-restore-recycle-entry-id]').forEach(button => decorateButton(button, 'restore'))
  recycleTableWrapper.querySelectorAll('[data-purge-recycle-entry-id]').forEach(button => decorateButton(button, 'delete'))
}

function switchTab(tabName) {
  currentTab = tabName || 'stats'
  statsSection.classList.add('hidden')
  compareSection.classList.add('hidden')
  wordCloudSection.classList.add('hidden')
  kwicSection.classList.add('hidden')
  collocateSection.classList.add('hidden')
  locatorSection.classList.add('hidden')
  tabButtons.forEach(button => button.classList.remove('active'))
  if (tabName === 'stats') statsSection.classList.remove('hidden')
  else if (tabName === 'compare') compareSection.classList.remove('hidden')
  else if (tabName === 'word-cloud') wordCloudSection.classList.remove('hidden')
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

function recordDiagnosticError(scope, error, details = null) {
  const normalizedError =
    error instanceof Error
      ? {
          name: error.name,
          message: error.message,
          stack: error.stack || ''
        }
      : {
          name: 'Error',
          message: String(error || '未知错误')
        }
  void recordDiagnostic('error', scope, normalizedError.message, {
    ...(details && typeof details === 'object' ? details : {}),
    error: normalizedError
  })
}

function getDiagnosticRendererState() {
  return {
    currentTab,
    corpusMode: currentCorpusMode,
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
    kwicKeyword: currentKWICKeyword,
    kwicResultCount: currentKWICResults.length,
    kwicScope: currentKWICScopeLabel,
    collocateKeyword: currentCollocateKeyword,
    collocateResultCount: currentCollocateRows.length,
    locatorSentenceCount: currentSentenceObjects.length,
    taskCenter: taskCenterEntries.slice(0, 5).map(entry => ({
      type: entry.type,
      status: entry.status,
      detail: entry.detail,
      durationMs: entry.durationMs || 0
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
    if (!diagnostics) {
      diagnosticsStatusText.textContent = fallbackText
      return
    }
    const errorCount = Array.isArray(diagnostics.recentErrors) ? diagnostics.recentErrors.length : 0
    const logStatus = diagnostics.debugLoggingEnabled ? '已开启' : '未开启'
    diagnosticsStatusText.textContent = `本次会话 ${diagnostics.sessionId || ''} ｜ 调试日志${logStatus} ｜ 最近错误 ${errorCount} 条${diagnostics.logFilePath ? ` ｜ 日志：${diagnostics.logFilePath}` : ''}`
  } catch (error) {
    console.warn('[diagnostics.state]', error)
    diagnosticsStatusText.textContent = fallbackText
  }
}

function normalizeWorkspaceSnapshot(rawSnapshot) {
  if (!rawSnapshot || typeof rawSnapshot !== 'object') return null
  if (Number(rawSnapshot.version) !== WORKSPACE_SNAPSHOT_VERSION) return null

  const corpusIds = Array.isArray(rawSnapshot.workspace?.corpusIds)
    ? rawSnapshot.workspace.corpusIds.map(item => String(item || '').trim()).filter(Boolean)
    : []
  const corpusNames = Array.isArray(rawSnapshot.workspace?.corpusNames)
    ? rawSnapshot.workspace.corpusNames.map(item => String(item || '').trim()).filter(Boolean)
    : []

  return {
    version: WORKSPACE_SNAPSHOT_VERSION,
    savedAt: String(rawSnapshot.savedAt || '').trim(),
    currentTab: ['stats', 'compare', 'word-cloud', 'kwic', 'collocate', 'locator'].includes(rawSnapshot.currentTab)
      ? rawSnapshot.currentTab
      : 'stats',
    currentLibraryFolderId: String(rawSnapshot.currentLibraryFolderId || 'all').trim() || 'all',
    previewCollapsed: rawSnapshot.previewCollapsed !== false,
    workspace: {
      corpusIds,
      corpusNames
    },
    search: {
      query: String(rawSnapshot.search?.query || ''),
      options: normalizeSearchOptions(rawSnapshot.search?.options || {})
    },
    stats: {
      pageSize: String(rawSnapshot.stats?.pageSize || '10')
    },
    compare: {
      pageSize: String(rawSnapshot.compare?.pageSize || '10')
    },
    kwic: {
      pageSize: String(rawSnapshot.kwic?.pageSize || '10'),
      scope: String(rawSnapshot.kwic?.scope || 'current'),
      sortMode: String(rawSnapshot.kwic?.sortMode || 'original'),
      leftWindow: String(rawSnapshot.kwic?.leftWindow || '5'),
      rightWindow: String(rawSnapshot.kwic?.rightWindow || '5')
    },
    collocate: {
      pageSize: String(rawSnapshot.collocate?.pageSize || '10'),
      leftWindow: String(rawSnapshot.collocate?.leftWindow || '5'),
      rightWindow: String(rawSnapshot.collocate?.rightWindow || '5'),
      minFreq: String(rawSnapshot.collocate?.minFreq || '1')
    }
  }
}

function loadStoredWorkspaceSnapshot() {
  try {
    const rawValue = localStorage.getItem(WORKSPACE_STATE_STORAGE_KEY)
    if (!rawValue) return null
    return normalizeWorkspaceSnapshot(JSON.parse(rawValue))
  } catch (error) {
    console.warn('[workspace.snapshot.load]', error)
    return null
  }
}

function getRestorableTabFromSnapshot(snapshot) {
  if (!snapshot) return 'stats'
  if (snapshot.currentTab === 'locator') {
    return snapshot.search?.query ? 'kwic' : 'stats'
  }
  return snapshot.currentTab || 'stats'
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

    currentSearchOptions = normalizeSearchOptions(snapshot.search.options)
    syncSearchOptionInputs()
    setSharedSearchQuery(snapshot.search.query, { rerender: false })

    pageSize = resolvePageSize(pageSizeSelect?.value || '10', getVisibleFrequencyRows().length)
    currentComparePageSize = resolvePageSize(comparePageSizeSelect?.value || '10', getVisibleCompareRows().length)
    currentKWICPageSize = resolvePageSize(kwicPageSizeSelect?.value || '10', currentKWICResults.length)
    currentCollocatePageSize = resolvePageSize(collocatePageSizeSelect?.value || '10', currentCollocateRows.length)
    currentKWICSortMode = kwicSortSelect?.value || 'original'
    currentKWICScope = kwicScopeSelect?.value || 'current'

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

function buildKWICRows() {
  const result = buildKWICRowsData(getKWICState(), sortKWICResults)
  currentKWICSortCache = result.cache
  return result.rows
}

function buildAllFrequencyRows() {
  return buildAllFrequencyRowsData(getStatsState())
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

async function resolveCrossCorpusKWICScope(scope) {
  if (!window.electronAPI?.listSearchableCorpora) {
    await showMissingBridge('listSearchableCorpora')
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

    const result = await window.electronAPI.listSearchableCorpora(currentCorpusFolderId)
    if (!result.success) {
      await showAlert({
        title: '读取当前文件夹失败',
        message: result.message || '无法读取当前文件夹中的语料'
      })
      return null
    }

    if (!(result.corpora || []).length) {
      await showAlert({
        title: '当前文件夹为空',
        message: `文件夹「${currentCorpusFolderName || result.selectedFolderName || '未分类'}」里还没有可检索的语料。`
      })
      return null
    }

    return {
      corpora: result.corpora || [],
      scopeLabel: `当前文件夹 · ${currentCorpusFolderName || result.selectedFolderName || '未分类'}`
    }
  }

  const result = await window.electronAPI.listSearchableCorpora('all')
  if (!result.success) {
    await showAlert({
      title: '读取本地语料库失败',
      message: result.message || '无法读取本地语料库中的语料'
    })
    return null
  }

  if (!(result.corpora || []).length) {
    await showAlert({
      title: '本地语料库为空',
      message: '请先导入并保存至少一条本地语料，再使用“全部本地语料”检索。'
    })
    return null
  }

  return {
    corpora: result.corpora || [],
    scopeLabel: '全部本地语料'
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
  nextAnalysisRun('kwic')
  nextAnalysisRun('collocate')
  const endBusyState = beginBusyState('正在解析语料...')
  isCorpusLoading = true
  updateAnalysisActionButtons()
  setButtonsBusy([openCorpusMenuButton, quickOpenButton, saveImportButton, importToFolderButton], true)

  try {
    currentText = result.content
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
      currentCorpusMode === 'saved-multi' && Array.isArray(result.comparisonEntries)
        ? result.comparisonEntries
            .map(entry => ({
              corpusId: String(entry?.corpusId || '').trim(),
              corpusName: String(entry?.corpusName || '').trim(),
              folderId: String(entry?.folderId || '').trim(),
              folderName: String(entry?.folderName || '').trim(),
              sourceType: String(entry?.sourceType || 'txt').trim() || 'txt',
              content: String(entry?.content || '')
            }))
            .filter(entry => entry.corpusId && entry.content.trim())
        : []
    const corpusData = await runAnalysisTask(
      ANALYSIS_TASK_TYPES.loadCorpus,
      { text: currentText },
      () => buildCorpusData(currentText)
    )
    if (!isLatestAnalysisRun('loadCorpus', runId)) return

    currentSentenceObjects = corpusData.sentences
    currentTokenObjects = corpusData.tokenObjects
    currentTokens = corpusData.tokens || currentTokenObjects.map(item => item.token)
    currentFreqRows = []
    currentComparisonRows = []
    currentComparisonCorpora = []
    setSharedSearchQuery('', { rerender: false })
    currentKWICResults = []
    currentCollocateRows = []
    invalidateKWICSortCache()
    currentPage = 1
    currentComparePage = 1
    currentKWICPage = 1
    currentCollocatePage = 1
    currentComparePageSize = 10
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
    kwicPageSizeSelect.value = '10'
    collocateLeftWindowSelect.value = '5'
    collocateRightWindowSelect.value = '5'
    collocateMinFreqSelect.value = '1'
    collocatePageSizeSelect.value = '10'

    syncCurrentWorkspaceSelectionState()

    previewBox.textContent = getPreviewText(result.content, PREVIEW_CHAR_LIMIT)
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
    kwicTotalRowsInfo.textContent = '共 0 条结果'
    kwicPageInfo.textContent = '第 0 / 0 页'
    kwicPrevPageButton.disabled = true
    kwicNextPageButton.disabled = true
    kwicMeta.innerHTML = '文本已导入。请输入检索词，选择检索范围，并设置左右窗口大小后点击“KWIC 检索”。<br />支持当前语料、当前文件夹和全部本地语料。'
    kwicWrapper.innerHTML = '<div class="empty-tip">这里会显示关键词前后文结果</div>'
    collocateTotalRowsInfo.textContent = '共 0 条结果'
    collocatePageInfo.textContent = '第 0 / 0 页'
    collocatePrevPageButton.disabled = true
    collocateNextPageButton.disabled = true
    collocateMeta.innerHTML = '文本已导入。请输入节点词后开始统计 Collocate。'
    collocateWrapper.innerHTML = '<div class="empty-tip">这里会显示 Collocate 统计结果</div>'
    locatorMeta.textContent = '原文已载入。点击任一 KWIC 结果行后，会自动定位并高亮对应原句。'
    sentenceViewer.innerHTML = '<div class="empty-tip">切换到“原文定位”或点击某条 KWIC 结果后，这里会按需加载定位表。</div>'
    switchTab('stats')
    if (trackRecent) {
      addRecentOpenEntry(buildRecentOpenEntryFromResult(result))
    }
    void recordDiagnostic('info', 'corpus.load', '语料已载入工作区。', {
      mode: currentCorpusMode,
      corpusName: currentCorpusDisplayName,
      selectedCorporaCount: currentSelectedCorpora.length,
      tokenCount: currentTokens.length
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

decorateStaticButtons()
updateAnalysisActionButtons()
setPreviewCollapsed(true)
renderTaskCenter()
setOpenCorpusMenuOpen(false)
const initialUISettings = initUISettings()
recentOpenEntries = loadRecentOpenEntries()
renderWorkspaceOverview()
renderSelectedCorporaTable()
updateLoadSelectedCorporaButton()
renderRecentOpenList()
syncSharedSearchInputs()
syncSearchOptionInputs()
renderCompareSection()
renderWordCloud()
applyAppInfoToShell()
applyAutoUpdateButtonState(null)
syncWelcomePreferenceCheckboxes()
void refreshDiagnosticsStatusText()
if (initialUISettings.showWelcomeScreen !== false) {
  showWelcomeOverlay()
  setWelcomeProgress(12, '正在载入界面设置...', '正在准备欢迎界面')
}
void recordDiagnostic('info', 'app', 'Renderer 已完成初始化。', {
  tab: currentTab,
  showWelcomeScreen: initialUISettings.showWelcomeScreen !== false
})

window.addEventListener('error', event => {
  recordDiagnosticError('renderer.error', event.error || new Error(event.message || '未捕获错误'), {
    filename: event.filename || '',
    lineno: event.lineno || 0,
    colno: event.colno || 0
  })
})

window.addEventListener('unhandledrejection', event => {
  recordDiagnosticError(
    'renderer.unhandledrejection',
    event.reason instanceof Error ? event.reason : new Error(String(event.reason || '未处理 Promise 拒绝')),
    {
      reason: event.reason instanceof Error ? event.reason.message : String(event.reason || '')
    }
  )
})

void (async () => {
  setWelcomeProgress(32, '正在同步版本信息...', '正在读取当前版本')
  await ensureAppInfoLoaded()
  setWelcomeProgress(58, '正在初始化自动更新...', '正在连接桌面更新能力')
  await initializeAutoUpdate()
  if (getCurrentUISettings().restoreWorkspace !== false) {
    const workspaceSnapshot = loadStoredWorkspaceSnapshot()
    if (hasMeaningfulWorkspaceSnapshot(workspaceSnapshot)) {
      const shouldRestoreWorkspace = await requestWorkspaceRestoreDecision(workspaceSnapshot)
      if (shouldRestoreWorkspace) {
        setWelcomeProgress(76, '正在恢复上次工作区...', '正在连接上次分析状态')
        await restoreWorkspaceFromSnapshot(workspaceSnapshot)
      } else {
        void recordDiagnostic('info', 'workspace.restore', '用户选择跳过恢复上次工作区。', {
          snapshotCorpusCount: workspaceSnapshot?.workspace?.corpusIds?.length || 0
        })
      }
    }
  }
  workspaceSnapshotReady = true
  scheduleWorkspaceSnapshotSave({ immediate: true })
  setWelcomeProgress(90, '正在整理工作区与工具栏...', '正在准备分析工作台')
  await new Promise(resolve => requestAnimationFrame(() => resolve()))
  markWelcomeReady()
})()

previewToggleButton?.addEventListener('click', () => {
  const isCollapsed = previewPanelBody?.classList.contains('hidden')
  setPreviewCollapsed(!isCollapsed)
})

dom.closeWelcomeButton?.addEventListener('click', () => {
  if (!welcomeReady) return
  const shouldShowWelcome = !(dom.welcomeDisableCheckbox?.checked)
  applyUISettings({
    ...getCurrentUISettings(),
    showWelcomeScreen: shouldShowWelcome
  })
  syncWelcomePreferenceCheckboxes()
  hideWelcomeOverlay({ immediate: true })
})

restoreWorkspaceButton?.addEventListener('click', () => {
  if (!pendingWorkspaceRestoreSnapshot) return
  resolveStartupRestoreDecision(true)
})

skipWorkspaceRestoreButton?.addEventListener('click', () => {
  if (!pendingWorkspaceRestoreSnapshot) return
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

openCorpusMenuButton?.addEventListener('click', () => {
  setOpenCorpusMenuOpen(!openCorpusMenuOpen)
})

openCorpusMenuPanel?.addEventListener('click', async event => {
  const target = event.target
  if (!(target instanceof Element)) return

  const recentButton = target.closest('[data-recent-open-index]')
  if (recentButton instanceof HTMLButtonElement) {
    const recentIndex = Number(recentButton.dataset.recentOpenIndex)
    const entry = recentOpenEntries[recentIndex]
    if (!entry) return
    await openRecentOpenEntry(entry)
    return
  }

  if (clearRecentOpenButton && (target === clearRecentOpenButton || clearRecentOpenButton.contains(target))) {
    clearRecentOpenEntries()
    showToast('最近打开列表已清空。', {
      title: '已清空'
    })
  }
})

checkUpdateButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.checkForUpdates) {
    await showMissingBridge('checkForUpdates')
    return
  }

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
  await showAlert({
    title: `关于 ${currentAppInfo.name}`,
    message: buildAboutMessage(),
    confirmText: '知道了'
  })
})

taskCenterButton?.addEventListener('click', () => {
  setTaskCenterOpen(!taskCenterOpen)
})

closeTaskCenterButton?.addEventListener('click', () => {
  setTaskCenterOpen(false)
})

document.addEventListener('click', event => {
  const target = event.target
  if (!(target instanceof Node)) return
  if (openCorpusMenuOpen && openCorpusMenuPanel && openCorpusMenuButton) {
    if (!openCorpusMenuPanel.contains(target) && !openCorpusMenuButton.contains(target)) {
      setOpenCorpusMenuOpen(false)
    }
  }
  if (taskCenterOpen && taskCenterPanel && taskCenterButton) {
    if (!taskCenterPanel.contains(target) && !taskCenterButton.contains(target)) {
      setTaskCenterOpen(false)
    }
  }
})

document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && openCorpusMenuOpen) {
    setOpenCorpusMenuOpen(false)
    return
  }
  if (
    event.key === 'Escape' &&
    recycleModal &&
    !recycleModal.classList.contains('hidden') &&
    feedbackModal?.classList.contains('hidden')
  ) {
    closeRecycleModal()
    return
  }
  if (event.key === 'Escape' && taskCenterOpen) {
    setTaskCenterOpen(false)
  }
})

uiSettingsButton.addEventListener('click', () => {
  openUISettingsModal()
  void refreshDiagnosticsStatusText()
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

exportDiagnosticsButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.exportDiagnosticReport) {
    await showMissingBridge('exportDiagnosticReport')
    return
  }

  const result = await window.electronAPI.exportDiagnosticReport(getDiagnosticRendererState())
  if (!result || !result.success) {
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
})

reportIssueButton?.addEventListener('click', async () => {
  if (!window.electronAPI?.openGitHubFeedback) {
    await showMissingBridge('openGitHubFeedback')
    return
  }

  const result = await window.electronAPI.openGitHubFeedback({
    issueTitle: '[Bug] 请简要描述问题',
    rendererState: getDiagnosticRendererState()
  })

  if (!result || !result.success) {
    await showAlert({
      title: '打开 GitHub 反馈失败',
      message: result?.message || '暂时无法打开 GitHub 反馈页。'
    })
    return
  }

  await refreshDiagnosticsStatusText()
  void recordDiagnostic('info', 'diagnostics', '用户已打开 GitHub 反馈页。', { issueUrl: result.issueUrl })
  showToast('已打开 GitHub Issues，新页面里已预填当前会话摘要。', {
    title: '反馈已准备',
    type: 'success',
    duration: 2600
  })
})

uiSettingsModal.addEventListener('click', (event) => {
  if (event.target === uiSettingsModal) closeUISettingsModal()
})

quickOpenButton.addEventListener('click', async () => {
  setOpenCorpusMenuOpen(false)
  if (!window.electronAPI?.openQuickCorpus) {
    await showMissingBridge('openQuickCorpus')
    return
  }

  const result = await window.electronAPI.openQuickCorpus()
  await loadCorpusResult(result)
})

saveImportButton.addEventListener('click', async () => {
  setOpenCorpusMenuOpen(false)
  if (!window.electronAPI?.importAndSaveCorpus) {
    await showMissingBridge('importAndSaveCorpus')
    return
  }
  const result = await window.electronAPI.importAndSaveCorpus(getImportTargetFolder().id)
  await loadCorpusResult(result)
  if (!libraryModal.classList.contains('hidden')) {
    await refreshLibraryModal(currentLibraryFolderId)
  }
})

selectSavedCorporaButton?.addEventListener('click', async () => {
  syncLibrarySelectionWithCurrentCorpora()
  await openLibraryModal('all')
})

libraryButton.addEventListener('click', () => {
  setOpenCorpusMenuOpen(false)
  openLibraryModal()
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
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
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
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
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
  } finally {
    endBusyState()
    setButtonsBusy([backupLibraryButton, restoreLibraryButton, repairLibraryButton], false)
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

libraryTableWrapper.addEventListener('change', event => {
  const target = event.target
  if (!(target instanceof Element)) return
  const checkbox = target.closest('[data-select-corpus-id]')
  if (!(checkbox instanceof HTMLInputElement)) return

  const corpusId = checkbox.dataset.selectCorpusId || ''
  if (!corpusId) return

  if (checkbox.checked) selectedLibraryCorpusIds.add(corpusId)
  else selectedLibraryCorpusIds.delete(corpusId)

  updateLoadSelectedCorporaButton()
  updateLibraryMetaText()
})

libraryTableWrapper.addEventListener('click', async (event) => {
  const openButton = event.target.closest('[data-open-corpus-id]')
  const renameButton = event.target.closest('[data-rename-corpus-id]')
  const moveButton = event.target.closest('[data-move-corpus-id]')
  const deleteButton = event.target.closest('[data-delete-corpus-id]')

  if (openButton) {
    const corpusId = openButton.dataset.openCorpusId
    const result = await window.electronAPI.openSavedCorpus(corpusId)
    closeLibraryModal()
    await loadCorpusResult(result)
    return
  }

  if (renameButton) {
    const corpusId = renameButton.dataset.renameCorpusId
    const currentName = renameButton.dataset.currentName || ''
    const newName = await promptForName({
      title: '重命名语料',
      message: '请输入新的语料名称。',
      defaultValue: currentName,
      placeholder: '请输入语料名称',
      confirmText: '保存',
      label: '语料名称'
    })
    if (newName === null) return
    const result = await window.electronAPI.renameSavedCorpus(corpusId, newName)
    if (!result.success) {
      await showAlert({
        title: '重命名语料失败',
        message: result.message || '重命名失败'
      })
      return
    }
    if (currentCorpusId === corpusId) {
      currentCorpusDisplayName = result.item.name
      updateCurrentCorpusInfo()
    }
    patchCurrentSelectedCorpora(
      item => item.id === corpusId,
      item => ({ ...item, name: result.item.name })
    )
    await refreshLibraryModal(currentLibraryFolderId)
    return
  }

  if (moveButton) {
    const corpusId = moveButton.dataset.moveCorpusId
    const row = moveButton.closest('tr')
    const select = row ? row.querySelector(`[data-move-folder-select="${corpusId}"]`) : null
    const targetFolderId = select ? select.value : ''
    const result = await window.electronAPI.moveSavedCorpus(corpusId, targetFolderId)
    if (!result.success) {
      await showAlert({
        title: '移动语料失败',
        message: result.message || '移动语料失败'
      })
      return
    }

    if (currentCorpusId === corpusId) {
      currentCorpusFolderId = result.item.folderId
      currentCorpusFolderName = result.item.folderName
      updateCurrentCorpusInfo()
    }
    patchCurrentSelectedCorpora(
      item => item.id === corpusId,
      item => ({
        ...item,
        folderId: result.item.folderId,
        folderName: result.item.folderName
      })
    )

    await refreshLibraryModal(currentLibraryFolderId)
    return
  }

  if (deleteButton) {
    const corpusId = deleteButton.dataset.deleteCorpusId
    const corpusName = deleteButton.dataset.corpusName || '该语料'
    const confirmed = await showConfirm({
      title: '删除语料',
      message: `确定要删除语料「${corpusName}」吗？它会先移入回收站，你之后仍可恢复。`,
      confirmText: '移入回收站',
      cancelText: '取消',
      danger: true
    })
    if (!confirmed) return

    const result = await window.electronAPI.deleteSavedCorpus(corpusId)
    if (!result.success) {
      await showAlert({
        title: '删除语料失败',
        message: result.message || '删除语料失败'
      })
      return
    }

    if (selectedLibraryCorpusIds.has(corpusId)) {
      selectedLibraryCorpusIds.delete(corpusId)
      updateLoadSelectedCorporaButton()
      updateLibraryMetaText()
    }
    removeCurrentSelectedCorpora(item => item.id === corpusId)

    await refreshLibraryModal(currentLibraryFolderId)
    if (!recycleModal.classList.contains('hidden')) {
      await refreshRecycleBinModal()
    }
    showToast(`语料「${corpusName}」已移入回收站。`, {
      title: '可恢复删除',
      type: 'success'
    })
  }
})

recycleTableWrapper?.addEventListener('click', async event => {
  const restoreButton = event.target.closest('[data-restore-recycle-entry-id]')
  const purgeButton = event.target.closest('[data-purge-recycle-entry-id]')

  if (restoreButton) {
    const recycleEntryId = restoreButton.dataset.restoreRecycleEntryId
    const entryName = restoreButton.dataset.recycleEntryName || '该项目'
    const entryType = restoreButton.dataset.recycleEntryType === 'folder' ? '文件夹' : '语料'
    const confirmed = await showConfirm({
      title: `恢复${entryType}`,
      message:
        entryType === '文件夹'
          ? `确定要恢复文件夹「${entryName}」吗？如果原位置已存在同 ID 文件夹，会自动恢复为新的文件夹。`
          : `确定要恢复语料「${entryName}」吗？如果原位置已不存在，会恢复到“未分类”或保留的新位置。`,
      confirmText: '恢复',
      cancelText: '取消'
    })
    if (!confirmed) return

    const result = await window.electronAPI.restoreRecycleEntry(recycleEntryId)
    if (!result.success) {
      await showAlert({
        title: '恢复失败',
        message: result.message || `恢复${entryType}失败`
      })
      return
    }

    await refreshRecycleBinModal()
    if (!libraryModal.classList.contains('hidden')) {
      await refreshLibraryModal(currentLibraryFolderId)
    }

    const restoredMessage =
      result.restoredType === 'folder'
        ? (result.restoredAsNewFolder ? `文件夹「${entryName}」已恢复，并因冲突保存为新的文件夹。` : `文件夹「${entryName}」已恢复。`)
        : (result.restoredToOriginalFolder === false ? `语料「${entryName}」已恢复到可用文件夹。` : `语料「${entryName}」已恢复。`)
    showToast(restoredMessage, {
      title: '恢复完成',
      type: 'success'
    })
    return
  }

  if (purgeButton) {
    const recycleEntryId = purgeButton.dataset.purgeRecycleEntryId
    const entryName = purgeButton.dataset.recycleEntryName || '该项目'
    const entryType = purgeButton.dataset.recycleEntryType === 'folder' ? '文件夹' : '语料'
    const confirmed = await showConfirm({
      title: `彻底删除${entryType}`,
      message: `确定要彻底删除${entryType}「${entryName}」吗？删除后将无法再从回收站恢复。`,
      confirmText: '彻底删除',
      cancelText: '取消',
      danger: true
    })
    if (!confirmed) return

    const result = await window.electronAPI.purgeRecycleEntry(recycleEntryId)
    if (!result.success) {
      await showAlert({
        title: '彻底删除失败',
        message: result.message || `彻底删除${entryType}失败`
      })
      return
    }

    await refreshRecycleBinModal()
    showToast(`${entryType}「${entryName}」已从回收站彻底删除。`, {
      title: '删除完成',
      type: 'success'
    })
  }
})

countButton.addEventListener('click', async () => {
  if (!currentText.trim()) {
    await showAlert({
      title: '缺少语料',
      message: '请先导入一个 txt / docx / pdf 文件'
    })
    return
  }
  const runId = nextAnalysisRun('stats')
  const endBusyState = beginBusyState('正在统计词频与词汇指标...')
  beginCancelableAnalysis('stats')
  startTaskCenterEntry('stats', '统计结果', '正在统计词频与词汇指标...')
  try {
    const shouldCompareAcrossCorpora = currentComparisonEntries.length >= 2
    const statsResult = await runAnalysisTask(
      ANALYSIS_TASK_TYPES.computeStats,
      {
        comparisonEntries: shouldCompareAcrossCorpora ? currentComparisonEntries : []
      },
      () => {
        const freqMap = countWordFrequency(currentTokens)
        const comparison = shouldCompareAcrossCorpora
          ? compareCorpusFrequencies(currentComparisonEntries)
          : { corpora: [], rows: [] }
        return {
          freqRows: getSortedFrequencyRows(freqMap),
          tokenCount: currentTokens.length,
          typeCount: Object.keys(freqMap).length,
          ttr: calculateTTR(currentTokens),
          sttr: calculateSTTR(currentTokens, 1000),
          freqMap,
          compareCorpora: comparison.corpora,
          compareRows: comparison.rows
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
    renderStatsSummaryTable()
    pageSize = resolvePageSize(pageSizeSelect.value, getVisibleFrequencyRows().length)
    currentPage = 1
    currentComparePageSize = resolvePageSize(comparePageSizeSelect.value, getVisibleCompareRows().length)
    currentComparePage = 1
    renderFrequencyTable()
    renderCompareTable()
    renderWordCloud()
    switchTab('stats')
    finishTaskCenterEntry('stats', 'success', `Token ${formatCount(currentTokenCount)} / Type ${formatCount(currentTypeCount)}`)
    void recordDiagnostic('info', 'analysis.stats', '统计任务完成。', {
      tokenCount: currentTokenCount,
      typeCount: currentTypeCount
    })
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('stats', 'cancelled', error.message || '统计任务已取消')
      void recordDiagnostic('warn', 'analysis.stats', error.message || '统计任务已取消')
      showToast(error.message || '已取消统计任务', {
        title: '统计已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('stats', 'failed', getErrorMessage(error, '统计失败'))
    console.error('[countButton]', error)
    recordDiagnosticError('analysis.stats', error, {
      tokenCount: currentTokens.length
    })
    await showAlert({
      title: '统计失败',
      message: getErrorMessage(error, '统计失败')
    })
  } finally {
    endBusyState()
    endCancelableAnalysis('stats')
  }
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

kwicButton.addEventListener('click', async () => {
  const keyword = String(currentSearchQuery || '').trim()
  if (!keyword) {
    await showAlert({
      title: '缺少检索词',
      message: '请输入要检索的词'
    })
    return
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
    return
  }
  const kwicScope = getSelectedKWICScope()
  const searchOptions = { ...currentSearchOptions }
  let kwicScopeLabel = '当前语料'
  let searchedCorpusCount = currentText.trim() ? 1 : 0
  let kwicTaskType = ANALYSIS_TASK_TYPES.searchKWIC
  let kwicTaskPayload = { keyword, leftWindowSize, rightWindowSize, searchOptions }
  let kwicFallback = () => searchKWIC(currentTokenObjects, keyword, leftWindowSize, rightWindowSize, searchOptions)

  if (kwicScope === 'current') {
    if (!currentText.trim()) {
      await showAlert({
        title: '缺少语料',
        message: '请先导入一个 txt / docx / pdf 文件，或把检索范围切到“全部本地语料”。'
      })
      return
    }
  } else {
    const scopeContext = await resolveCrossCorpusKWICScope(kwicScope)
    if (!scopeContext) return
    kwicScopeLabel = scopeContext.scopeLabel
    searchedCorpusCount = scopeContext.corpora.length
    kwicTaskType = ANALYSIS_TASK_TYPES.searchLibraryKWIC
    kwicTaskPayload = {
      keyword,
      leftWindowSize,
      rightWindowSize,
      corpusEntries: scopeContext.corpora,
      searchOptions
    }
    kwicFallback = () => searchLibraryKWIC(scopeContext.corpora, keyword, leftWindowSize, rightWindowSize, searchOptions)
  }

  const runId = nextAnalysisRun('kwic')
  const endBusyState = beginBusyState('正在执行 KWIC 检索...')
  beginCancelableAnalysis('kwic')
  startTaskCenterEntry('kwic', 'KWIC 检索', `${kwicScopeLabel} · 关键词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R · ${getSearchOptionsSummary()}`)
  try {
    currentKWICKeyword = keyword
    currentKWICLeftWindow = leftWindowSize
    currentKWICRightWindow = rightWindowSize
    currentKWICSortMode = kwicSortSelect.value
    currentKWICScope = kwicScope
    currentKWICScopeLabel = kwicScopeLabel
    currentKWICSearchedCorpusCount = searchedCorpusCount
    currentKWICResults = await runAnalysisTask(
      kwicTaskType,
      kwicTaskPayload,
      kwicFallback,
      { taskName: 'kwic' }
    )
    if (!isLatestAnalysisRun('kwic', runId)) return
    invalidateKWICSortCache()
    currentKWICPageSize = resolvePageSize(kwicPageSizeSelect.value, currentKWICResults.length)
    currentKWICPage = 1
    renderKWICTable()
    switchTab('kwic')
    finishTaskCenterEntry('kwic', 'success', `${kwicScopeLabel} · 关键词：${keyword} · ${formatCount(currentKWICResults.length)} 条结果`)
    void recordDiagnostic('info', 'analysis.kwic', 'KWIC 检索完成。', {
      keyword,
      scope: kwicScopeLabel,
      resultCount: currentKWICResults.length
    })
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('kwic', 'cancelled', error.message || 'KWIC 检索已取消')
      void recordDiagnostic('warn', 'analysis.kwic', error.message || 'KWIC 检索已取消', {
        keyword
      })
      showToast(error.message || '已取消 KWIC 检索', {
        title: 'KWIC 已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('kwic', 'failed', getErrorMessage(error, 'KWIC 检索失败'))
    console.error('[kwicButton]', error)
    recordDiagnosticError('analysis.kwic', error, {
      keyword,
      scope: kwicScopeLabel
    })
    await showAlert({
      title: 'KWIC 检索失败',
      message: getErrorMessage(error, 'KWIC 检索失败')
    })
  } finally {
    endBusyState()
    endCancelableAnalysis('kwic')
  }
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

collocateButton.addEventListener('click', async () => {
  if (!currentText.trim()) {
    await showAlert({
      title: '缺少语料',
      message: '请先导入一个 txt / docx / pdf 文件'
    })
    return
  }
  const keyword = String(currentSearchQuery || '').trim()
  if (!keyword) {
    await showAlert({
      title: '缺少节点词',
      message: '请输入节点词'
    })
    return
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
    return
  }
  const minFreq = Number(collocateMinFreqSelect.value)
  const searchOptions = { ...currentSearchOptions }
  const runId = nextAnalysisRun('collocate')
  const endBusyState = beginBusyState('正在计算搭配词结果...')
  beginCancelableAnalysis('collocate')
  startTaskCenterEntry('collocate', 'Collocate 统计', `节点词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R · ${getSearchOptionsSummary()}`)
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
    finishTaskCenterEntry('collocate', 'success', `节点词：${keyword} · ${formatCount(currentCollocateRows.length)} 条结果`)
    void recordDiagnostic('info', 'analysis.collocate', 'Collocate 统计完成。', {
      keyword,
      resultCount: currentCollocateRows.length,
      minFreq
    })
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('collocate', 'cancelled', error.message || 'Collocate 统计已取消')
      void recordDiagnostic('warn', 'analysis.collocate', error.message || 'Collocate 统计已取消', {
        keyword
      })
      showToast(error.message || '已取消 Collocate 统计', {
        title: 'Collocate 已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('collocate', 'failed', getErrorMessage(error, 'Collocate 统计失败'))
    console.error('[collocateButton]', error)
    recordDiagnosticError('analysis.collocate', error, {
      keyword,
      minFreq
    })
    await showAlert({
      title: 'Collocate 统计失败',
      message: getErrorMessage(error, 'Collocate 统计失败')
    })
  } finally {
    endBusyState()
    endCancelableAnalysis('collocate')
  }
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
