export const HOST_API_CATALOG = Object.freeze({
  getAppInfo: { kind: 'invoke' },
  getSystemAppearanceState: { kind: 'invoke' },
  consumePendingSystemOpenFiles: { kind: 'invoke' },
  onSystemOpenFileRequest: { kind: 'subscribe' },
  onAppMenuAction: { kind: 'subscribe' },
  onSystemNotificationAction: { kind: 'subscribe' },
  getDiagnosticState: { kind: 'invoke' },
  setDiagnosticLoggingEnabled: { kind: 'invoke' },
  writeDiagnosticLog: { kind: 'invoke' },
  exportDiagnosticReport: { kind: 'invoke' },
  exportDiagnosticReportAuto: { kind: 'invoke' },
  openGitHubFeedback: { kind: 'invoke' },
  getAnalysisCache: { kind: 'invoke' },
  setAnalysisCache: { kind: 'invoke' },
  deleteAnalysisCache: { kind: 'invoke' },
  clearAnalysisCache: { kind: 'invoke' },
  getAnalysisCacheState: { kind: 'invoke' },
  pruneAnalysisCache: { kind: 'invoke' },
  openExternalUrl: { kind: 'invoke' },
  showPathInFolder: { kind: 'invoke' },
  consumeCrashRecoveryState: { kind: 'invoke' },
  showSystemNotification: { kind: 'invoke' },
  setWindowProgressState: { kind: 'invoke' },
  setWindowAttentionState: { kind: 'invoke' },
  setWindowDocumentState: { kind: 'invoke' },
  getSmokeObserverState: { kind: 'invoke' },
  getPackagedSmokeConfig: { kind: 'invoke' },
  reportPackagedSmokeResult: { kind: 'invoke' },
  getAutoUpdateState: { kind: 'invoke' },
  setAutoUpdatePreferences: { kind: 'invoke' },
  checkForUpdates: { kind: 'invoke' },
  installDownloadedUpdate: { kind: 'invoke' },
  onAutoUpdateStatus: { kind: 'subscribe' },
  saveTableFile: { kind: 'invoke' },
  openQuickCorpus: { kind: 'invoke' },
  openQuickCorpusAtPath: { kind: 'invoke' },
  importAndSaveCorpus: { kind: 'invoke' },
  importCorpusPaths: { kind: 'invoke' },
  backupCorpusLibrary: { kind: 'invoke' },
  restoreCorpusLibrary: { kind: 'invoke' },
  repairCorpusLibrary: { kind: 'invoke' },
  listSavedCorpora: { kind: 'invoke' },
  listSearchableCorpora: { kind: 'invoke' },
  searchLibraryKWIC: { kind: 'invoke' },
  listRecycleBin: { kind: 'invoke' },
  restoreRecycleEntry: { kind: 'invoke' },
  purgeRecycleEntry: { kind: 'invoke' },
  createCorpusFolder: { kind: 'invoke' },
  renameCorpusFolder: { kind: 'invoke' },
  deleteCorpusFolder: { kind: 'invoke' },
  showSavedCorpusInFolder: { kind: 'invoke' },
  showRecycleEntryInFolder: { kind: 'invoke' },
  openSavedCorpus: { kind: 'invoke' },
  openSavedCorpora: { kind: 'invoke' },
  renameSavedCorpus: { kind: 'invoke' },
  moveSavedCorpus: { kind: 'invoke' },
  deleteSavedCorpus: { kind: 'invoke' },
  getSmokeAnalysisDelayMs: { kind: 'sync' },
  setZoomFactor: { kind: 'sync' },
  getZoomFactor: { kind: 'sync' }
})

export const HOST_SERVICE_GROUPS = Object.freeze({
  app: Object.freeze([
    'getAppInfo',
    'getSystemAppearanceState',
    'consumePendingSystemOpenFiles',
    'onSystemOpenFileRequest',
    'onAppMenuAction',
    'onSystemNotificationAction',
    'openExternalUrl'
  ]),
  settings: Object.freeze([
    'getSystemAppearanceState',
    'setDiagnosticLoggingEnabled',
    'getAutoUpdateState',
    'setAutoUpdatePreferences',
    'setZoomFactor',
    'getZoomFactor'
  ]),
  update: Object.freeze([
    'getAutoUpdateState',
    'setAutoUpdatePreferences',
    'checkForUpdates',
    'installDownloadedUpdate',
    'onAutoUpdateStatus'
  ]),
  diagnostics: Object.freeze([
    'getDiagnosticState',
    'setDiagnosticLoggingEnabled',
    'writeDiagnosticLog',
    'exportDiagnosticReport',
    'exportDiagnosticReportAuto',
    'openGitHubFeedback'
  ]),
  cache: Object.freeze([
    'getAnalysisCache',
    'setAnalysisCache',
    'deleteAnalysisCache',
    'clearAnalysisCache',
    'getAnalysisCacheState',
    'pruneAnalysisCache'
  ]),
  library: Object.freeze([
    'openQuickCorpus',
    'openQuickCorpusAtPath',
    'importAndSaveCorpus',
    'importCorpusPaths',
    'backupCorpusLibrary',
    'restoreCorpusLibrary',
    'repairCorpusLibrary',
    'listSavedCorpora',
    'listSearchableCorpora',
    'searchLibraryKWIC',
    'listRecycleBin',
    'restoreRecycleEntry',
    'purgeRecycleEntry',
    'createCorpusFolder',
    'renameCorpusFolder',
    'deleteCorpusFolder',
    'showSavedCorpusInFolder',
    'showRecycleEntryInFolder',
    'openSavedCorpus',
    'openSavedCorpora',
    'renameSavedCorpus',
    'moveSavedCorpus',
    'deleteSavedCorpus'
  ]),
  workspace: Object.freeze([
    'openQuickCorpusAtPath',
    'openSavedCorpus',
    'openSavedCorpora',
    'consumeCrashRecoveryState',
    'exportDiagnosticReport'
  ]),
  window: Object.freeze([
    'showSystemNotification',
    'setWindowProgressState',
    'setWindowAttentionState',
    'setWindowDocumentState',
    'showPathInFolder'
  ]),
  files: Object.freeze([
    'saveTableFile',
    'showPathInFolder'
  ]),
  smoke: Object.freeze([
    'getSmokeObserverState',
    'getPackagedSmokeConfig',
    'reportPackagedSmokeResult',
    'getSmokeAnalysisDelayMs'
  ])
})

export function getHostServiceMethodNames(serviceName = '') {
  return HOST_SERVICE_GROUPS[String(serviceName || '').trim()] || Object.freeze([])
}
