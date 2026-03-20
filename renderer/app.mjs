import {
  buildCorpusData,
  calculateSTTR,
  calculateTTR,
  countWordFrequency,
  getSortedFrequencyRows,
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
  TABLE_RENDER_CHUNK_SIZE,
  UI_FONT_FAMILIES,
  UI_SETTINGS_STORAGE_KEY
} from './constants.mjs'
import { dom } from './domRefs.mjs'
import { createAnalysisBridge } from './analysisBridge.mjs'
import {
  buildAllCollocateRows as buildAllCollocateRowsData,
  buildCollocateRows as buildCollocateRowsData,
  renderCollocateTable as renderCollocateTableSection
} from './features/collocate.mjs'
import { createFeedbackController } from './feedback.mjs'
import {
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
  appTitleHeading,
  appSubtitle,
  settingsPreviewText,
  openCorpusMenuButton,
  openCorpusMenuPanel,
  quickOpenButton,
  saveImportButton,
  libraryButton,
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
  copyKWICButton,
  exportAllKWICButton,
  copyLocatorButton,
  tabButtons,
  statsSection,
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
  closeLibraryButton,
  recycleModal,
  recycleMeta,
  recycleTableWrapper,
  closeRecycleButton,
  uiSettingsModal,
  uiZoomRange,
  uiFontSizeRange,
  uiFontFamilySelect,
  lightThemeButton,
  darkThemeButton,
  resetUiSettingsButton,
  closeUiSettingsButton,
  feedbackModal
} = dom

const DEFAULT_APP_INFO = Object.freeze({
  name: 'WordZ',
  version: '',
  description: '',
  author: '',
  autoUpdateConfigured: false,
  autoUpdateProvider: '',
  autoUpdateProviderLabel: '',
  autoUpdateTarget: '',
  help: [],
  releaseNotes: []
})

const APP_FEATURE_SUMMARY = '支持 txt / docx / pdf 导入、词频统计、跨语料库 KWIC、Collocate、原文定位，以及本地语料库分类、备份、恢复、修复与自动更新。'
const APP_SUBTITLE_TEXT = '支持 Quick Corpus、本地语料库、词频统计、跨语料库 KWIC、Collocate、原文定位、自动更新，以及 xlsx / csv 导出。当前版本按空格分词，适合英文等空格分隔语言。'

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
let currentLibraryFolderId = localStorage.getItem(LIBRARY_FOLDER_STORAGE_KEY) || 'all'
let currentLibraryFolders = []

let currentText = ''
let currentTokens = []
let currentTokenObjects = []
let currentSentenceObjects = []
let currentFreqRows = []
let currentPage = 1
let pageSize = 10

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
const activeTaskCenterEntryIds = new Map()
const TASK_CENTER_LIMIT = 8
const taskCenterTimeFormatter = new Intl.DateTimeFormat('zh-CN', {
  hour: '2-digit',
  minute: '2-digit'
})

function invalidateKWICSortCache() {
  currentKWICSortCache = { source: null, mode: 'original', rows: [] }
}

function getErrorMessage(error, fallbackMessage) {
  return error && error.message ? error.message : fallbackMessage
}

function setPreviewCollapsed(collapsed) {
  if (!previewPanelBody || !previewToggleButton) return
  previewPanelBody.classList.toggle('hidden', collapsed)
  previewToggleButton.setAttribute('aria-expanded', String(!collapsed))
  previewToggleButton.textContent = collapsed ? '展开预览' : '收起预览'
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
  setButtonLabel(taskCenterButton, activeCount > 0 ? `任务中心（${activeCount}）` : '任务中心')
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

function getAutoUpdateButtonLabel(updateState) {
  if (!updateState) return '检查更新'
  if (updateState.state === 'checking') return '检查中...'
  if (updateState.state === 'downloading') {
    const progressPercent = Math.round(Number(updateState.progressPercent) || 0)
    return progressPercent > 0 ? `下载更新 ${progressPercent}%` : '下载更新中...'
  }
  if (updateState.state === 'downloaded') return '安装更新'
  return '检查更新'
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
  decorateButton(openCorpusMenuButton, 'open')
  decorateButton(quickOpenButton, 'open')
  decorateButton(saveImportButton, 'import')
  decorateButton(libraryButton, 'library')
  decorateButton(countButton, 'stats')
  decorateButton(cancelStatsButton, 'stop')
  decorateButton(checkUpdateButton, 'update')
  decorateButton(aboutButton, 'about')
  decorateButton(uiSettingsButton, 'settings')
  decorateButton(taskCenterButton, 'tasks')
  decorateButton(closeTaskCenterButton, 'close')
  decorateButton(kwicButton, 'spark')
  decorateButton(cancelKwicButton, 'stop')
  decorateButton(collocateButton, 'stats')
  decorateButton(cancelCollocateButton, 'stop')
  decorateButton(copyStatsButton, 'export')
  decorateButton(copyFreqButton, 'export')
  decorateButton(exportAllFreqButton, 'exportAll')
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
  statsSection.classList.add('hidden')
  kwicSection.classList.add('hidden')
  collocateSection.classList.add('hidden')
  locatorSection.classList.add('hidden')
  tabButtons.forEach(button => button.classList.remove('active'))
  if (tabName === 'stats') statsSection.classList.remove('hidden')
  else if (tabName === 'kwic') kwicSection.classList.remove('hidden')
  else if (tabName === 'collocate') collocateSection.classList.remove('hidden')
  else if (tabName === 'locator') {
    locatorSection.classList.remove('hidden')
    if (locatorNeedsRender) renderSentenceViewer()
  }
  const activeButton = document.querySelector(`.tab-button[data-tab="${tabName}"]`)
  if (activeButton) activeButton.classList.add('active')
}

tabButtons.forEach(button => {
  button.addEventListener('click', () => switchTab(button.dataset.tab))
})

function getStatsState() {
  return {
    currentCorpusMode,
    currentCorpusDisplayName,
    currentCorpusFolderName,
    currentTokens,
    currentFreqRows,
    currentPage,
    pageSize,
    currentTokenCount,
    currentTypeCount,
    currentTTR,
    currentSTTR
  }
}

function getKWICState() {
  return {
    currentKWICResults,
    currentKWICPage,
    currentKWICPageSize,
    currentKWICSortMode,
    currentKWICKeyword,
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
    renderWorkspaceOverview()
    return
  }

  if (currentCorpusMode === 'saved') {
    const folderLabel = currentCorpusFolderName || '未分类'
    fileInfo.textContent = `当前语料（已保存 / ${folderLabel}）：${currentCorpusDisplayName}`
    renderWorkspaceOverview()
    return
  }

  fileInfo.textContent = '当前语料（Quick Corpus）：' + currentCorpusDisplayName
  renderWorkspaceOverview()
}

function demoteCurrentSavedCorpusToQuick() {
  if (currentCorpusMode !== 'saved') return
  currentCorpusMode = 'quick'
  currentCorpusId = null
  currentCorpusFolderId = null
  currentCorpusFolderName = ''
  updateCurrentCorpusInfo()
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
    setLibraryFolderSelection(result.selectedFolderId || 'all')
    updateLibraryTargetChip()
    libraryFolderList.innerHTML = buildLibraryFolderList(
      currentLibraryFolders,
      currentLibraryFolderId,
      result.totalCount || 0,
      escapeHtml
    )
    libraryTableWrapper.innerHTML = buildLibraryTable(result.items || [], currentLibraryFolders, currentLibraryFolderId, escapeHtml)
    decorateLibraryControls()

    if (currentLibraryFolderId === 'all') {
      libraryMeta.textContent = `共 ${result.totalCount || 0} 条本地语料，已整理到 ${currentLibraryFolders.length} 个文件夹中。`
    } else {
      const folder = getFolderByIdFromList(currentLibraryFolders, currentLibraryFolderId)
      libraryMeta.textContent = `文件夹「${folder ? folder.name : '未分类'}」中共 ${(result.items || []).length} 条语料。`
    }
  } finally {
    endBusyState()
  }
}

async function openLibraryModal(folderId = currentLibraryFolderId) {
  if (!window.electronAPI?.listSavedCorpora) {
    await showMissingBridge('listSavedCorpora')
    return
  }

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

async function loadCorpusResult(result) {
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
    currentKWICResults = []
    currentCollocateRows = []
    invalidateKWICSortCache()
    currentPage = 1
    currentKWICPage = 1
    currentCollocatePage = 1
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
    kwicInput.value = ''
    leftWindowSelect.value = '5'
    rightWindowSelect.value = '5'
    kwicPageSizeSelect.value = '10'
    collocateInput.value = ''
    collocateLeftWindowSelect.value = '5'
    collocateRightWindowSelect.value = '5'
    collocateMinFreqSelect.value = '1'
    collocatePageSizeSelect.value = '10'

    updateCurrentCorpusInfo()

    previewBox.textContent = getPreviewText(result.content, PREVIEW_CHAR_LIMIT)
    statsSummaryWrapper.innerHTML = '<div class="empty-tip">文本已导入，请点击“开始统计”</div>'
    totalRowsInfo.textContent = '共 0 个单词'
    pageInfo.textContent = '第 0 / 0 页'
    prevPageButton.disabled = true
    nextPageButton.disabled = true
    tableWrapper.innerHTML = '<div class="empty-tip">文本已导入，请点击“开始统计”</div>'
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
  } catch (error) {
    console.error('[loadCorpusResult]', error)
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

decorateStaticButtons()
updateAnalysisActionButtons()
setPreviewCollapsed(true)
renderTaskCenter()
setOpenCorpusMenuOpen(false)
initUISettings()
renderWorkspaceOverview()
applyAppInfoToShell()
applyAutoUpdateButtonState(null)
void ensureAppInfoLoaded()
void initializeAutoUpdate()

previewToggleButton?.addEventListener('click', () => {
  const isCollapsed = previewPanelBody?.classList.contains('hidden')
  setPreviewCollapsed(!isCollapsed)
})

openCorpusMenuButton?.addEventListener('click', () => {
  setOpenCorpusMenuOpen(!openCorpusMenuOpen)
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
})

closeUiSettingsButton.addEventListener('click', () => {
  closeUISettingsModal()
})

resetUiSettingsButton.addEventListener('click', () => {
  applyUISettings(DEFAULT_UI_SETTINGS)
  applyTheme(DEFAULT_THEME)
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

    if (currentCorpusMode === 'saved' && currentCorpusFolderId === folderId) {
      demoteCurrentSavedCorpusToQuick()
    }

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

    if (currentCorpusId === corpusId) {
      demoteCurrentSavedCorpusToQuick()
    }

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
    const statsResult = await runAnalysisTask(
      ANALYSIS_TASK_TYPES.computeStats,
      {},
      () => {
        const freqMap = countWordFrequency(currentTokens)
        return {
          freqRows: getSortedFrequencyRows(freqMap),
          tokenCount: currentTokens.length,
          typeCount: Object.keys(freqMap).length,
          ttr: calculateTTR(currentTokens),
          sttr: calculateSTTR(currentTokens, 1000),
          freqMap
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
    renderStatsSummaryTable()
    pageSize = resolvePageSize(pageSizeSelect.value, currentFreqRows.length)
    currentPage = 1
    renderFrequencyTable()
    switchTab('stats')
    finishTaskCenterEntry('stats', 'success', `Token ${formatCount(currentTokenCount)} / Type ${formatCount(currentTypeCount)}`)
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('stats', 'cancelled', error.message || '统计任务已取消')
      showToast(error.message || '已取消统计任务', {
        title: '统计已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('stats', 'failed', getErrorMessage(error, '统计失败'))
    console.error('[countButton]', error)
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
  pageSize = resolvePageSize(pageSizeSelect.value, currentFreqRows.length)
  currentPage = 1
  renderFrequencyTable()
})

for (const control of [leftWindowSelect, rightWindowSelect, collocateLeftWindowSelect, collocateRightWindowSelect]) {
  control.addEventListener('change', () => {
    normalizeWindowSizeInput(control)
  })
  control.addEventListener('blur', () => {
    normalizeWindowSizeInput(control)
  })
}

prevPageButton.addEventListener('click', () => {
  if (currentPage > 1) {
    currentPage -= 1
    renderFrequencyTable()
  }
})

nextPageButton.addEventListener('click', () => {
  const totalPages = Math.ceil(currentFreqRows.length / pageSize)
  if (currentPage < totalPages) {
    currentPage += 1
    renderFrequencyTable()
  }
})

kwicButton.addEventListener('click', async () => {
  const keyword = kwicInput.value.trim().toLowerCase()
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
  let kwicScopeLabel = '当前语料'
  let searchedCorpusCount = currentText.trim() ? 1 : 0
  let kwicTaskType = ANALYSIS_TASK_TYPES.searchKWIC
  let kwicTaskPayload = { keyword, leftWindowSize, rightWindowSize }
  let kwicFallback = () => searchKWIC(currentTokenObjects, keyword, leftWindowSize, rightWindowSize)

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
      corpusEntries: scopeContext.corpora
    }
    kwicFallback = () => searchLibraryKWIC(scopeContext.corpora, keyword, leftWindowSize, rightWindowSize)
  }

  const runId = nextAnalysisRun('kwic')
  const endBusyState = beginBusyState('正在执行 KWIC 检索...')
  beginCancelableAnalysis('kwic')
  startTaskCenterEntry('kwic', 'KWIC 检索', `${kwicScopeLabel} · 关键词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R`)
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
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('kwic', 'cancelled', error.message || 'KWIC 检索已取消')
      showToast(error.message || '已取消 KWIC 检索', {
        title: 'KWIC 已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('kwic', 'failed', getErrorMessage(error, 'KWIC 检索失败'))
    console.error('[kwicButton]', error)
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
})

kwicPageSizeSelect.addEventListener('change', () => {
  currentKWICPageSize = resolvePageSize(kwicPageSizeSelect.value, currentKWICResults.length)
  currentKWICPage = 1
  renderKWICTable()
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
  const keyword = collocateInput.value.trim().toLowerCase()
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
  const runId = nextAnalysisRun('collocate')
  const endBusyState = beginBusyState('正在计算搭配词结果...')
  beginCancelableAnalysis('collocate')
  startTaskCenterEntry('collocate', 'Collocate 统计', `节点词：${keyword} · 范围：${leftWindowSize}L ${rightWindowSize}R`)
  try {
    currentCollocateKeyword = keyword
    currentCollocateLeftWindow = leftWindowSize
    currentCollocateRightWindow = rightWindowSize
    currentCollocateMinFreq = minFreq
    currentCollocateRows = await runAnalysisTask(
      ANALYSIS_TASK_TYPES.searchCollocates,
      { keyword, leftWindowSize, rightWindowSize, minFreq },
      () => searchCollocates(currentTokenObjects, currentTokens, keyword, leftWindowSize, rightWindowSize, minFreq),
      { taskName: 'collocate' }
    )
    if (!isLatestAnalysisRun('collocate', runId)) return
    currentCollocatePageSize = resolvePageSize(collocatePageSizeSelect.value, currentCollocateRows.length)
    currentCollocatePage = 1
    collocateMeta.innerHTML = `节点词：${escapeHtml(keyword)} ｜ 范围：${leftWindowSize}L ${rightWindowSize}R ｜ 最低共现次数：${minFreq}<br />结果按共现次数降序排列。`
    renderCollocateTable()
    switchTab('collocate')
    finishTaskCenterEntry('collocate', 'success', `节点词：${keyword} · ${formatCount(currentCollocateRows.length)} 条结果`)
  } catch (error) {
    if (isAbortError(error)) {
      finishTaskCenterEntry('collocate', 'cancelled', error.message || 'Collocate 统计已取消')
      showToast(error.message || '已取消 Collocate 统计', {
        title: 'Collocate 已取消',
        duration: 2200
      })
      return
    }
    finishTaskCenterEntry('collocate', 'failed', getErrorMessage(error, 'Collocate 统计失败'))
    console.error('[collocateButton]', error)
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
