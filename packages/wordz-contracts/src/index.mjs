export const JSON_RPC_VERSION = '2.0'

export const ENGINE_METHODS = Object.freeze({
  appGetInfo: 'app.getInfo',
  appGetPendingLaunchFiles: 'app.getPendingLaunchFiles',
  appConsumeCrashRecoveryState: 'app.consumeCrashRecoveryState',
  libraryList: 'library.list',
  libraryOpenQuickPath: 'library.openQuickPath',
  libraryImportPaths: 'library.importPaths',
  libraryOpenSaved: 'library.openSaved',
  libraryOpenSavedBatch: 'library.openSavedBatch',
  libraryRenameCorpus: 'library.renameCorpus',
  libraryMoveCorpus: 'library.moveCorpus',
  libraryDeleteCorpus: 'library.deleteCorpus',
  libraryCreateFolder: 'library.createFolder',
  libraryRenameFolder: 'library.renameFolder',
  libraryDeleteFolder: 'library.deleteFolder',
  libraryListRecycleBin: 'library.listRecycleBin',
  libraryRestoreRecycleEntry: 'library.restoreRecycleEntry',
  libraryPurgeRecycleEntry: 'library.purgeRecycleEntry',
  libraryBackup: 'library.backup',
  libraryRestore: 'library.restore',
  libraryRepair: 'library.repair',
  librarySearchKwic: 'library.searchKwic',
  workspaceGetState: 'workspace.getState',
  workspaceSaveState: 'workspace.saveState',
  workspaceGetRecentOpen: 'workspace.getRecentOpen',
  workspaceSaveRecentOpen: 'workspace.saveRecentOpen',
  workspaceGetUiSettings: 'workspace.getUiSettings',
  workspaceSaveUiSettings: 'workspace.saveUiSettings',
  workspaceGetOnboarding: 'workspace.getOnboarding',
  workspaceSaveOnboarding: 'workspace.saveOnboarding',
  diagnosticsGetState: 'diagnostics.getState',
  diagnosticsWriteLog: 'diagnostics.writeLog',
  diagnosticsExportReport: 'diagnostics.exportReport',
  diagnosticsGetGitHubIssueUrl: 'diagnostics.getGitHubIssueUrl',
  updateGetState: 'update.getState',
  updateCheck: 'update.check',
  updateInstall: 'update.install',
  analysisStartTask: 'analysis.startTask',
  analysisCancelTask: 'analysis.cancelTask',
  analysisGetTaskState: 'analysis.getTaskState',
  engineShutdown: 'engine.shutdown'
})

export const ENGINE_TASK_TYPES = Object.freeze({
  stats: 'stats',
  ngram: 'ngram',
  kwic: 'kwic',
  libraryKwic: 'library-kwic',
  collocate: 'collocate',
  compare: 'compare',
  chiSquare: 'chi-square',
  wordCloud: 'word-cloud',
  locator: 'locator'
})

export const ENGINE_EVENTS = Object.freeze({
  taskUpdated: 'task.updated',
  taskCompleted: 'task.completed',
  taskFailed: 'task.failed',
  taskCancelled: 'task.cancelled',
  diagnosticsLog: 'diagnostics.log'
})

export const ENGINE_ERROR_CODES = Object.freeze({
  parseError: -32700,
  invalidRequest: -32600,
  methodNotFound: -32601,
  invalidParams: -32602,
  internalError: -32603,
  taskNotFound: 4104
})

export function isEngineMethod(value) {
  return Object.values(ENGINE_METHODS).includes(String(value || ''))
}

export function isEngineTaskType(value) {
  return Object.values(ENGINE_TASK_TYPES).includes(String(value || ''))
}
