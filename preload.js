const { contextBridge, ipcRenderer, webFrame } = require('electron')

const SAFE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/
const MAX_EXPORT_ROWS = 250000
const MAX_EXPORT_COLUMNS = 256
const MAX_EXPORT_CELL_LENGTH = 100000

function normalizeTextInput(value, maxLength) {
  return String(value ?? '').trim().slice(0, maxLength)
}

function normalizeIdentifier(value, { allowAll = false, allowEmpty = false } = {}) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) return allowEmpty ? '' : ''
  if (allowAll && normalizedValue === 'all') return 'all'
  if (!SAFE_ID_PATTERN.test(normalizedValue)) return ''
  return normalizedValue
}

function normalizeTableRows(rows) {
  if (!Array.isArray(rows)) return []

  return rows.slice(0, MAX_EXPORT_ROWS).map(row => {
    if (!Array.isArray(row)) return []
    return row
      .slice(0, MAX_EXPORT_COLUMNS)
      .map(cell => String(cell ?? '').slice(0, MAX_EXPORT_CELL_LENGTH))
  })
}

function normalizeIdentifierList(values, { allowEmpty = false } = {}) {
  if (!Array.isArray(values)) return []
  const seen = new Set()
  const normalizedValues = []

  for (const value of values) {
    const normalizedValue = normalizeIdentifier(value, { allowEmpty })
    if (!normalizedValue || seen.has(normalizedValue)) continue
    seen.add(normalizedValue)
    normalizedValues.push(normalizedValue)
  }

  return normalizedValues
}

function clampZoomFactor(factor) {
  const numericFactor = Number(factor)
  if (!Number.isFinite(numericFactor)) return 1
  return Math.min(Math.max(numericFactor, 0.8), 1.35)
}

function clampSmokeDelayMs(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue) || numericValue <= 0) return 0
  return Math.min(Math.trunc(numericValue), 10000)
}

function normalizeBoolean(value) {
  if (typeof value === 'boolean') return value
  return ['1', 'true', 'yes', 'on'].includes(String(value ?? '').trim().toLowerCase())
}

const electronAPI = Object.freeze({
  getAppInfo: () =>
    ipcRenderer.invoke('get-app-info'),

  getDiagnosticState: () =>
    ipcRenderer.invoke('get-diagnostic-state'),

  setDiagnosticLoggingEnabled: (enabled) =>
    ipcRenderer.invoke('set-diagnostic-logging-enabled', normalizeBoolean(enabled)),

  writeDiagnosticLog: ({ level, scope, message, details } = {}) =>
    ipcRenderer.invoke('write-diagnostic-log', {
      level: normalizeTextInput(level, 16),
      scope: normalizeTextInput(scope, 80),
      message: normalizeTextInput(message, 600),
      details: details ?? null
    }),

  exportDiagnosticReport: (rendererState) =>
    ipcRenderer.invoke('export-diagnostic-report', rendererState ?? {}),

  openGitHubFeedback: ({ issueTitle, rendererState } = {}) =>
    ipcRenderer.invoke('open-github-feedback', {
      issueTitle: normalizeTextInput(issueTitle, 120),
      rendererState: rendererState ?? {}
    }),

  getAutoUpdateState: () =>
    ipcRenderer.invoke('get-auto-update-state'),

  checkForUpdates: () =>
    ipcRenderer.invoke('check-for-updates'),

  installDownloadedUpdate: () =>
    ipcRenderer.invoke('install-downloaded-update'),

  onAutoUpdateStatus: (callback) => {
    if (typeof callback !== 'function') return () => {}
    const listener = (_event, payload) => {
      callback(payload)
    }
    ipcRenderer.on('auto-update-status', listener)
    return () => {
      ipcRenderer.removeListener('auto-update-status', listener)
    }
  },

  saveTableFile: (defaultBaseName, rows) =>
    ipcRenderer.invoke('save-table-file', {
      defaultBaseName: normalizeTextInput(defaultBaseName, 120),
      rows: normalizeTableRows(rows)
    }),

  openQuickCorpus: () =>
    ipcRenderer.invoke('open-quick-corpus'),

  openQuickCorpusAtPath: (filePath) =>
    ipcRenderer.invoke('open-quick-corpus-at-path', normalizeTextInput(filePath, 4096)),

  importAndSaveCorpus: (folderId) =>
    ipcRenderer.invoke('import-and-save-corpus', {
      folderId: normalizeIdentifier(folderId, { allowEmpty: true })
    }),

  backupCorpusLibrary: () =>
    ipcRenderer.invoke('backup-corpus-library'),

  restoreCorpusLibrary: () =>
    ipcRenderer.invoke('restore-corpus-library'),

  repairCorpusLibrary: () =>
    ipcRenderer.invoke('repair-corpus-library'),

  listSavedCorpora: (folderId) =>
    ipcRenderer.invoke('list-saved-corpora', {
      folderId: normalizeIdentifier(folderId, { allowAll: true, allowEmpty: true })
    }),

  listSearchableCorpora: (folderId) =>
    ipcRenderer.invoke('list-searchable-corpora', {
      folderId: normalizeIdentifier(folderId, { allowAll: true, allowEmpty: true })
    }),

  listRecycleBin: () =>
    ipcRenderer.invoke('list-recycle-bin'),

  restoreRecycleEntry: (recycleEntryId) =>
    ipcRenderer.invoke('restore-recycle-entry', normalizeIdentifier(recycleEntryId)),

  purgeRecycleEntry: (recycleEntryId) =>
    ipcRenderer.invoke('purge-recycle-entry', normalizeIdentifier(recycleEntryId)),

  createCorpusFolder: (folderName) =>
    ipcRenderer.invoke('create-corpus-folder', normalizeTextInput(folderName, 80)),

  renameCorpusFolder: (folderId, newName) =>
    ipcRenderer.invoke('rename-corpus-folder', {
      folderId: normalizeIdentifier(folderId),
      newName: normalizeTextInput(newName, 80)
    }),

  deleteCorpusFolder: (folderId) =>
    ipcRenderer.invoke('delete-corpus-folder', normalizeIdentifier(folderId)),

  openSavedCorpus: (corpusId) =>
    ipcRenderer.invoke('open-saved-corpus', normalizeIdentifier(corpusId)),

  openSavedCorpora: (corpusIds) =>
    ipcRenderer.invoke('open-saved-corpora', normalizeIdentifierList(corpusIds)),

  renameSavedCorpus: (corpusId, newName) =>
    ipcRenderer.invoke('rename-saved-corpus', {
      corpusId: normalizeIdentifier(corpusId),
      newName: normalizeTextInput(newName, 120)
    }),

  moveSavedCorpus: (corpusId, targetFolderId) =>
    ipcRenderer.invoke('move-saved-corpus', {
      corpusId: normalizeIdentifier(corpusId),
      targetFolderId: normalizeIdentifier(targetFolderId, { allowEmpty: true })
    }),

  deleteSavedCorpus: (corpusId) =>
    ipcRenderer.invoke('delete-saved-corpus', normalizeIdentifier(corpusId)),

  getSmokeAnalysisDelayMs: () =>
    clampSmokeDelayMs(process.env.CORPUS_LITE_SMOKE_ANALYSIS_DELAY_MS),

  setZoomFactor: (factor) =>
    webFrame.setZoomFactor(clampZoomFactor(factor)),

  getZoomFactor: () =>
    webFrame.getZoomFactor()
})

contextBridge.exposeInMainWorld('electronAPI', electronAPI)
