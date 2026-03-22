const CHECKBOX_FALLBACK_IDS = new Set([
  'welcomeDisableCheckbox',
  'chiYatesToggle',
  'showWelcomeScreenToggle',
  'restoreWorkspaceToggle',
  'systemNotificationsToggle',
  'windowAttentionToggle',
  'notifyAnalysisCompleteToggle',
  'notifyUpdateDownloadedToggle',
  'notifyDiagnosticsExportToggle',
  'followSystemAccessibilityToggle',
  'debugLoggingToggle'
])

const RANGE_FALLBACK_IDS = new Set([
  'uiZoomRange',
  'uiFontSizeRange'
])

const NUMBER_INPUT_FALLBACK_IDS = new Set([
  'chiAInput',
  'chiBInput',
  'chiCInput',
  'chiDInput'
])

function getFallbackRoot() {
  let root = document.getElementById('wordzFallbackDomRefsRoot')
  if (root) return root
  root = document.createElement('div')
  root.id = 'wordzFallbackDomRefsRoot'
  root.className = 'hidden'
  root.setAttribute('aria-hidden', 'true')
  root.style.display = 'none'
  ;(document.body || document.documentElement).appendChild(root)
  return root
}

function createFallbackNode(id) {
  let tagName = 'div'

  if (id.endsWith('Button')) {
    tagName = 'button'
  } else if (id.endsWith('Select')) {
    tagName = 'select'
  } else if (id === 'feedbackInput') {
    tagName = 'textarea'
  } else if (id.endsWith('Url')) {
    tagName = 'a'
  } else if (CHECKBOX_FALLBACK_IDS.has(id) || id.endsWith('Checkbox')) {
    tagName = 'input'
  } else if (RANGE_FALLBACK_IDS.has(id) || NUMBER_INPUT_FALLBACK_IDS.has(id) || id.endsWith('Input')) {
    tagName = 'input'
  }

  const node = document.createElement(tagName)
  node.id = id
  node.classList.add('hidden')
  node.setAttribute('aria-hidden', 'true')
  node.setAttribute('data-wordz-fallback-node', '1')

  if (tagName === 'button') {
    node.type = 'button'
  } else if (tagName === 'input') {
    if (CHECKBOX_FALLBACK_IDS.has(id) || id.endsWith('Checkbox')) {
      node.type = 'checkbox'
    } else if (RANGE_FALLBACK_IDS.has(id)) {
      node.type = 'range'
    } else if (NUMBER_INPUT_FALLBACK_IDS.has(id)) {
      node.type = 'number'
    } else {
      node.type = 'text'
    }
  } else if (tagName === 'a') {
    node.href = '#'
  }

  getFallbackRoot().appendChild(node)
  return node
}

function ensureDomNode(id, existingNode) {
  return existingNode || createFallbackNode(id)
}

export const dom = {
  welcomeOverlay: document.getElementById('welcomeOverlay'),
  dropImportOverlay: document.getElementById('dropImportOverlay'),
  dropImportHint: document.getElementById('dropImportHint'),
  welcomeVersionBadge: document.getElementById('welcomeVersionBadge'),
  welcomeTitle: document.getElementById('welcomeTitle'),
  welcomeSubtitle: document.getElementById('welcomeSubtitle'),
  welcomeFeatureSummary: document.getElementById('welcomeFeatureSummary'),
  welcomeTutorialBlock: document.getElementById('welcomeTutorialBlock'),
  welcomeProgressTitle: document.getElementById('welcomeProgressTitle'),
  welcomeProgressText: document.getElementById('welcomeProgressText'),
  welcomeProgressPercent: document.getElementById('welcomeProgressPercent'),
  welcomeProgressFill: document.getElementById('welcomeProgressFill'),
  welcomeRestorePrompt: document.getElementById('welcomeRestorePrompt'),
  welcomeRestoreSummary: document.getElementById('welcomeRestoreSummary'),
  welcomeDisableCheckbox: document.getElementById('welcomeDisableCheckbox'),
  restoreWorkspaceButton: document.getElementById('restoreWorkspaceButton'),
  skipWorkspaceRestoreButton: document.getElementById('skipWorkspaceRestoreButton'),
  closeWelcomeButton: document.getElementById('closeWelcomeButton'),
  appTitleHeading: document.getElementById('appTitleHeading'),
  appSubtitle: document.getElementById('appSubtitle'),
  topbarVersionBadge: document.getElementById('topbarVersionBadge'),
  settingsPreviewText: document.getElementById('settingsPreviewText'),
  openCorpusMenuButton: document.getElementById('openCorpusMenuButton'),
  openCorpusMenuPanel: document.getElementById('openCorpusMenuPanel'),
  quickOpenButton: document.getElementById('quickOpenButton'),
  saveImportButton: document.getElementById('saveImportButton'),
  libraryButton: document.getElementById('libraryButton'),
  recentOpenSection: document.getElementById('recentOpenSection'),
  recentOpenList: document.getElementById('recentOpenList'),
  clearRecentOpenButton: document.getElementById('clearRecentOpenButton'),
  selectSavedCorporaButton: document.getElementById('selectSavedCorporaButton'),
  countButton: document.getElementById('countButton'),
  cancelStatsButton: document.getElementById('cancelStatsButton'),
  checkUpdateButton: document.getElementById('checkUpdateButton'),
  aboutButton: document.getElementById('aboutButton'),
  uiSettingsButton: document.getElementById('uiSettingsButton'),
  taskCenterButton: document.getElementById('taskCenterButton'),
  taskCenterPanel: document.getElementById('taskCenterPanel'),
  taskCenterMeta: document.getElementById('taskCenterMeta'),
  taskCenterList: document.getElementById('taskCenterList'),
  queueToggleButton: document.getElementById('queueToggleButton'),
  retryFailedTaskButton: document.getElementById('retryFailedTaskButton'),
  cancelQueuedTaskButton: document.getElementById('cancelQueuedTaskButton'),
  closeTaskCenterButton: document.getElementById('closeTaskCenterButton'),
  kwicButton: document.getElementById('kwicButton'),
  cancelKwicButton: document.getElementById('cancelKwicButton'),
  kwicInput: document.getElementById('kwicInput'),
  kwicScopeSelect: document.getElementById('kwicScopeSelect'),
  leftWindowSelect: document.getElementById('leftWindowSelect'),
  rightWindowSelect: document.getElementById('rightWindowSelect'),
  fileInfo: document.getElementById('fileInfo'),
  previewToggleButton: document.getElementById('previewToggleButton'),
  previewPanelBody: document.getElementById('previewPanelBody'),
  previewBox: document.getElementById('previewBox'),
  selectedCorporaWrapper: document.getElementById('selectedCorporaWrapper'),
  systemStatus: document.getElementById('systemStatus'),
  systemStatusText: document.getElementById('systemStatusText'),
  workspaceCorpusValue: document.getElementById('workspaceCorpusValue'),
  workspaceCorpusNote: document.getElementById('workspaceCorpusNote'),
  workspaceModeValue: document.getElementById('workspaceModeValue'),
  workspaceModeNote: document.getElementById('workspaceModeNote'),
  workspaceTokenValue: document.getElementById('workspaceTokenValue'),
  workspaceTokenNote: document.getElementById('workspaceTokenNote'),
  workspaceMetricValue: document.getElementById('workspaceMetricValue'),
  workspaceMetricNote: document.getElementById('workspaceMetricNote'),
  statsSummaryWrapper: document.getElementById('statsSummaryWrapper'),
  tableWrapper: document.getElementById('tableWrapper'),
  compareSummaryWrapper: document.getElementById('compareSummaryWrapper'),
  compareFilterInput: document.getElementById('compareFilterInput'),
  compareMeta: document.getElementById('compareMeta'),
  compareWrapper: document.getElementById('compareWrapper'),
  comparePageSizeSelect: document.getElementById('comparePageSizeSelect'),
  comparePrevPageButton: document.getElementById('comparePrevPageButton'),
  compareNextPageButton: document.getElementById('compareNextPageButton'),
  comparePageInfo: document.getElementById('comparePageInfo'),
  compareTotalRowsInfo: document.getElementById('compareTotalRowsInfo'),
  chiSquareMeta: document.getElementById('chiSquareMeta'),
  chiSquareResultWrapper: document.getElementById('chiSquareResultWrapper'),
  chiAInput: document.getElementById('chiAInput'),
  chiBInput: document.getElementById('chiBInput'),
  chiCInput: document.getElementById('chiCInput'),
  chiDInput: document.getElementById('chiDInput'),
  chiYatesToggle: document.getElementById('chiYatesToggle'),
  chiSquareRunButton: document.getElementById('chiSquareRunButton'),
  chiSquareResetButton: document.getElementById('chiSquareResetButton'),
  wordCloudMeta: document.getElementById('wordCloudMeta'),
  wordCloudWrapper: document.getElementById('wordCloudWrapper'),
  ngramButton: document.getElementById('ngramButton'),
  ngramSizeSelect: document.getElementById('ngramSizeSelect'),
  ngramMeta: document.getElementById('ngramMeta'),
  ngramWrapper: document.getElementById('ngramWrapper'),
  ngramPageSizeSelect: document.getElementById('ngramPageSizeSelect'),
  ngramPrevPageButton: document.getElementById('ngramPrevPageButton'),
  ngramNextPageButton: document.getElementById('ngramNextPageButton'),
  ngramPageInfo: document.getElementById('ngramPageInfo'),
  ngramTotalRowsInfo: document.getElementById('ngramTotalRowsInfo'),
  exportNgramButton: document.getElementById('exportNgramButton'),
  exportAllNgramButton: document.getElementById('exportAllNgramButton'),
  freqFilterInput: document.getElementById('freqFilterInput'),
  searchQueryInputs: Array.from(document.querySelectorAll('[data-shared-search-input]')),
  searchOptionInputs: Array.from(document.querySelectorAll('[data-search-option]')),
  pageSizeSelect: document.getElementById('pageSizeSelect'),
  prevPageButton: document.getElementById('prevPageButton'),
  nextPageButton: document.getElementById('nextPageButton'),
  pageInfo: document.getElementById('pageInfo'),
  totalRowsInfo: document.getElementById('totalRowsInfo'),
  kwicMeta: document.getElementById('kwicMeta'),
  kwicWrapper: document.getElementById('kwicWrapper'),
  kwicSortSelect: document.getElementById('kwicSortSelect'),
  kwicPageSizeSelect: document.getElementById('kwicPageSizeSelect'),
  kwicPrevPageButton: document.getElementById('kwicPrevPageButton'),
  kwicNextPageButton: document.getElementById('kwicNextPageButton'),
  kwicPageInfo: document.getElementById('kwicPageInfo'),
  kwicTotalRowsInfo: document.getElementById('kwicTotalRowsInfo'),
  collocateInput: document.getElementById('collocateInput'),
  collocateButton: document.getElementById('collocateButton'),
  cancelCollocateButton: document.getElementById('cancelCollocateButton'),
  collocateLeftWindowSelect: document.getElementById('collocateLeftWindowSelect'),
  collocateRightWindowSelect: document.getElementById('collocateRightWindowSelect'),
  collocateMinFreqSelect: document.getElementById('collocateMinFreqSelect'),
  collocateWrapper: document.getElementById('collocateWrapper'),
  collocateMeta: document.getElementById('collocateMeta'),
  collocatePageSizeSelect: document.getElementById('collocatePageSizeSelect'),
  collocatePrevPageButton: document.getElementById('collocatePrevPageButton'),
  collocateNextPageButton: document.getElementById('collocateNextPageButton'),
  collocatePageInfo: document.getElementById('collocatePageInfo'),
  collocateTotalRowsInfo: document.getElementById('collocateTotalRowsInfo'),
  exportCollocateButton: document.getElementById('exportCollocateButton'),
  exportAllCollocateButton: document.getElementById('exportAllCollocateButton'),
  locatorMeta: document.getElementById('locatorMeta'),
  sentenceViewer: document.getElementById('sentenceViewer'),
  copyStatsButton: document.getElementById('copyStatsButton'),
  copyFreqButton: document.getElementById('copyFreqButton'),
  exportAllFreqButton: document.getElementById('exportAllFreqButton'),
  copyCompareButton: document.getElementById('copyCompareButton'),
  exportAllCompareButton: document.getElementById('exportAllCompareButton'),
  copyKWICButton: document.getElementById('copyKWICButton'),
  exportAllKWICButton: document.getElementById('exportAllKWICButton'),
  copyLocatorButton: document.getElementById('copyLocatorButton'),
  tabButtons: Array.from(document.querySelectorAll('.tab-button')),
  statsSection: document.getElementById('statsSection'),
  compareSection: document.getElementById('compareSection'),
  chiSquareSection: document.getElementById('chiSquareSection'),
  wordCloudSection: document.getElementById('wordCloudSection'),
  ngramSection: document.getElementById('ngramSection'),
  kwicSection: document.getElementById('kwicSection'),
  collocateSection: document.getElementById('collocateSection'),
  locatorSection: document.getElementById('locatorSection'),
  libraryModal: document.getElementById('libraryModal'),
  libraryMeta: document.getElementById('libraryMeta'),
  libraryFolderList: document.getElementById('libraryFolderList'),
  libraryTableWrapper: document.getElementById('libraryTableWrapper'),
  libraryTargetChip: document.getElementById('libraryTargetChip'),
  createFolderButton: document.getElementById('createFolderButton'),
  importToFolderButton: document.getElementById('importToFolderButton'),
  recycleBinButton: document.getElementById('recycleBinButton'),
  backupLibraryButton: document.getElementById('backupLibraryButton'),
  restoreLibraryButton: document.getElementById('restoreLibraryButton'),
  repairLibraryButton: document.getElementById('repairLibraryButton'),
  loadSelectedCorporaButton: document.getElementById('loadSelectedCorporaButton'),
  closeLibraryButton: document.getElementById('closeLibraryButton'),
  recycleModal: document.getElementById('recycleModal'),
  recycleMeta: document.getElementById('recycleMeta'),
  recycleTableWrapper: document.getElementById('recycleTableWrapper'),
  closeRecycleButton: document.getElementById('closeRecycleButton'),
  helpCenterModal: document.getElementById('helpCenterModal'),
  helpCenterTitle: document.getElementById('helpCenterTitle'),
  helpCenterSummary: document.getElementById('helpCenterSummary'),
  helpCenterVersionChip: document.getElementById('helpCenterVersionChip'),
  helpCenterAuthorChip: document.getElementById('helpCenterAuthorChip'),
  helpCenterHelpList: document.getElementById('helpCenterHelpList'),
  helpCenterRepositoryUrl: document.getElementById('helpCenterRepositoryUrl'),
  helpCenterReleaseList: document.getElementById('helpCenterReleaseList'),
  reopenTutorialButton: document.getElementById('reopenTutorialButton'),
  openGitHubRepoButton: document.getElementById('openGitHubRepoButton'),
  closeHelpCenterButton: document.getElementById('closeHelpCenterButton'),
  uiSettingsModal: document.getElementById('uiSettingsModal'),
  uiZoomRange: document.getElementById('uiZoomRange'),
  uiZoomValue: document.getElementById('uiZoomValue'),
  uiFontSizeRange: document.getElementById('uiFontSizeRange'),
  uiFontSizeValue: document.getElementById('uiFontSizeValue'),
  uiFontFamilySelect: document.getElementById('uiFontFamilySelect'),
  showWelcomeScreenToggle: document.getElementById('showWelcomeScreenToggle'),
  restoreWorkspaceToggle: document.getElementById('restoreWorkspaceToggle'),
  systemNotificationsToggle: document.getElementById('systemNotificationsToggle'),
  windowAttentionToggle: document.getElementById('windowAttentionToggle'),
  notifyAnalysisCompleteToggle: document.getElementById('notifyAnalysisCompleteToggle'),
  notifyUpdateDownloadedToggle: document.getElementById('notifyUpdateDownloadedToggle'),
  notifyDiagnosticsExportToggle: document.getElementById('notifyDiagnosticsExportToggle'),
  followSystemAccessibilityToggle: document.getElementById('followSystemAccessibilityToggle'),
  debugLoggingToggle: document.getElementById('debugLoggingToggle'),
  diagnosticsStatusText: document.getElementById('diagnosticsStatusText'),
  resetWindowsCompatButton: document.getElementById('resetWindowsCompatButton'),
  exportDiagnosticsButton: document.getElementById('exportDiagnosticsButton'),
  reportIssueButton: document.getElementById('reportIssueButton'),
  analysisCacheValue: document.getElementById('analysisCacheValue'),
  analysisCacheStatusText: document.getElementById('analysisCacheStatusText'),
  refreshAnalysisCacheButton: document.getElementById('refreshAnalysisCacheButton'),
  rebuildAnalysisCacheButton: document.getElementById('rebuildAnalysisCacheButton'),
  clearAnalysisCacheButton: document.getElementById('clearAnalysisCacheButton'),
  themeModeValue: document.getElementById('themeModeValue'),
  lightThemeButton: document.getElementById('lightThemeButton'),
  darkThemeButton: document.getElementById('darkThemeButton'),
  systemThemeButton: document.getElementById('systemThemeButton'),
  resetUiSettingsButton: document.getElementById('resetUiSettingsButton'),
  closeUiSettingsButton: document.getElementById('closeUiSettingsButton'),
  feedbackModal: document.getElementById('feedbackModal'),
  feedbackTitle: document.getElementById('feedbackTitle'),
  feedbackMessage: document.getElementById('feedbackMessage'),
  feedbackInputWrap: document.getElementById('feedbackInputWrap'),
  feedbackInput: document.getElementById('feedbackInput'),
  feedbackError: document.getElementById('feedbackError'),
  feedbackCancelButton: document.getElementById('feedbackCancelButton'),
  feedbackConfirmButton: document.getElementById('feedbackConfirmButton'),
  commandPaletteModal: document.getElementById('commandPaletteModal'),
  commandPaletteInput: document.getElementById('commandPaletteInput'),
  commandPaletteList: document.getElementById('commandPaletteList'),
  closeCommandPaletteButton: document.getElementById('closeCommandPaletteButton'),
  toastViewport: document.getElementById('toastViewport')
}

for (const [key, value] of Object.entries(dom)) {
  if (Array.isArray(value)) continue
  dom[key] = ensureDomNode(key, value)
}

if (!dom.searchQueryInputs.length) {
  const fallbackInput = createFallbackNode('sharedSearchInput')
  fallbackInput.setAttribute('data-shared-search-input', '')
  dom.searchQueryInputs = [fallbackInput]
}

if (!dom.searchOptionInputs.length) {
  const options = ['words', 'case', 'regex'].map(option => {
    const input = document.createElement('input')
    input.type = 'checkbox'
    input.classList.add('hidden')
    input.setAttribute('aria-hidden', 'true')
    input.setAttribute('data-wordz-fallback-node', '1')
    input.setAttribute('data-search-option', option)
    if (option === 'words') {
      input.checked = true
    }
    getFallbackRoot().appendChild(input)
    return input
  })
  dom.searchOptionInputs = options
}
