const { app, BrowserWindow, ipcMain, dialog, session, shell } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const fs = require('fs/promises')
const ExcelJS = require('exceljs')
const packageManifest = require('./package.json')
const { CorpusStorage } = require('./corpusStorage')
const { readCorpusFile } = require('./corpusFileReader')
const { createAutoUpdateController } = require('./autoUpdate')
const { createDiagnosticsController } = require('./diagnostics')
const { getAppInfo } = require('./main/helpers/appInfo')
const {
  createDialogController,
  normalizeOptionalPathEnv,
  readJsonArrayEnv
} = require('./main/helpers/dialogSupport')
const {
  normalizeBooleanInput,
  normalizeExternalUrlInput,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTableRows,
  normalizeTextInput
} = require('./main/helpers/inputGuards')
const {
  migrateLegacyUserDataDirIfNeeded,
  pathExists
} = require('./main/helpers/userDataMigration')

let corpusStorage = null
let autoUpdateController = null
let diagnosticsController = null
const APP_ENTRY_URL = pathToFileURL(path.join(__dirname, 'index.html')).toString()
const LEGACY_USER_DATA_DIR_NAMES = ['语料助手', 'corpus-lite', 'WordZou']
const SMOKE_USER_DATA_DIR = normalizeOptionalPathEnv('CORPUS_LITE_SMOKE_USER_DATA_DIR')
const SMOKE_OPEN_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE')
const SMOKE_SAVE_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE')
const {
  showOpenDialog: showOpenDialogForApp,
  showSaveDialog: showSaveDialogForApp
} = createDialogController({
  dialog,
  openQueue: SMOKE_OPEN_DIALOG_QUEUE,
  saveQueue: SMOKE_SAVE_DIALOG_QUEUE
})

if (SMOKE_USER_DATA_DIR) {
  app.setPath('userData', SMOKE_USER_DATA_DIR)
  app.setPath('sessionData', path.join(SMOKE_USER_DATA_DIR, 'session-data'))
}

function isTrustedIpcSender(event) {
  const senderUrl = event?.senderFrame?.url || event?.sender?.getURL?.() || ''
  return senderUrl === APP_ENTRY_URL
}

function assertTrustedIpcSender(event) {
  if (!isTrustedIpcSender(event)) {
    throw new Error('拒绝来自未受信任页面的请求')
  }
}

function configureSessionSecurity() {
  const currentSession = session.defaultSession
  if (!currentSession) return

  currentSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
    callback(false)
  })

  if (typeof currentSession.setPermissionCheckHandler === 'function') {
    currentSession.setPermissionCheckHandler(() => false)
  }
}

function captureMainError(scope, error, details = null) {
  diagnosticsController?.captureError?.(scope, error, details)
}

function logMainDiagnostic(level, scope, message, details = null) {
  diagnosticsController?.log?.(level, scope, message, details)
}

function hardenWindow(win) {
  const { webContents } = win

  webContents.setWindowOpenHandler(() => ({ action: 'deny' }))

  webContents.on('will-navigate', (event, targetUrl) => {
    if (targetUrl !== APP_ENTRY_URL) {
      event.preventDefault()
    }
  })

  webContents.on('will-attach-webview', event => {
    event.preventDefault()
  })
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1100,
    minHeight: 760,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      allowRunningInsecureContent: false
    }
  })

  hardenWindow(win)
  win.on('unresponsive', () => {
    captureMainError('window.unresponsive', new Error('窗口无响应'))
  })
  win.webContents.on('render-process-gone', (_event, details) => {
    captureMainError('window.render-process-gone', new Error(`渲染进程已退出：${details?.reason || 'unknown'}`), details)
  })
  win.loadFile('index.html')
  win.webContents.on('did-finish-load', () => {
    autoUpdateController?.broadcastStatus?.()
    logMainDiagnostic('info', 'window', '主窗口已完成加载。')
  })
  return win
}

function getCorpusStorage() {
  if (!corpusStorage) {
    corpusStorage = new CorpusStorage(path.join(app.getPath('userData'), 'corpus-library'))
  }

  return corpusStorage
}

function registerSafeIpcHandler(channel, handler) {
  ipcMain.handle(channel, async (event, payload) => {
    try {
      assertTrustedIpcSender(event)
      return await handler(event, payload)
    } catch (error) {
      console.error(`[${channel}]`, error)
      captureMainError(`ipc:${channel}`, error, { payload })
      return {
        success: false,
        message: error && error.message ? error.message : '操作失败'
      }
    }
  })
}

registerSafeIpcHandler('save-table-file', async (event, { defaultBaseName, rows } = {}) => {
  const normalizedBaseName = normalizeTextInput(defaultBaseName, {
    fallback: '导出结果',
    maxLength: 120
  })
  const normalizedRows = normalizeTableRows(rows)

  const result = await showSaveDialogForApp({
    defaultPath: `${normalizedBaseName || '导出结果'}.xlsx`,
    filters: [
      { name: 'Excel 工作簿', extensions: ['xlsx'] },
      { name: 'CSV 文件', extensions: ['csv'] }
    ]
  })

  if (result.canceled || !result.filePath) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了保存'
    }
  }

  const outputPath = result.filePath
  const ext = path.extname(outputPath).toLowerCase()

  if (normalizedRows.length === 0) {
    return {
      success: false,
      message: '没有可导出的表格数据'
    }
  }

  if (ext === '.csv') {
    const csvLines = normalizedRows.map(row =>
      row
        .map(value => {
          const text = String(value ?? '')
          return '"' + text.replace(/"/g, '""') + '"'
        })
        .join(',')
    )

    await fs.writeFile(outputPath, '\uFEFF' + csvLines.join('\r\n'), 'utf8')

    return {
      success: true,
      filePath: outputPath
    }
  }

  const workbook = new ExcelJS.Workbook()
  const worksheet = workbook.addWorksheet('Sheet1')
  worksheet.addRows(normalizedRows)
  await workbook.xlsx.writeFile(outputPath)

  return {
    success: true,
    filePath: outputPath
  }
})

registerSafeIpcHandler('get-app-info', async () => {
  return {
    success: true,
    appInfo: getAppInfo({ app, packageManifest, autoUpdateController })
  }
})

registerSafeIpcHandler('get-auto-update-state', async () => {
  return {
    success: true,
    updateState: autoUpdateController?.getStatusSnapshot?.() || null
  }
})

registerSafeIpcHandler('check-for-updates', async () => {
  return autoUpdateController?.checkForUpdates?.() || {
    success: false,
    disabled: true,
    message: '自动更新当前不可用。'
  }
})

registerSafeIpcHandler('install-downloaded-update', async () => {
  return autoUpdateController?.quitAndInstall?.() || {
    success: false,
    message: '当前没有已下载完成的更新。'
  }
})

registerSafeIpcHandler('get-diagnostic-state', async () => {
  return {
    success: true,
    diagnostics: diagnosticsController?.getSnapshot?.() || null
  }
})

registerSafeIpcHandler('set-diagnostic-logging-enabled', async (event, enabled) => {
  const diagnostics = diagnosticsController?.setDebugLoggingEnabled?.(normalizeBooleanInput(enabled)) || null
  return {
    success: true,
    diagnostics
  }
})

registerSafeIpcHandler('write-diagnostic-log', async (event, payload = {}) => {
  diagnosticsController?.log?.(
    normalizeTextInput(payload?.level, { fallback: 'info', maxLength: 16 }),
    normalizeTextInput(payload?.scope, { fallback: 'renderer', maxLength: 80 }),
    normalizeTextInput(payload?.message, { fallback: '', maxLength: 600 }),
    payload?.details ?? null
  )
  return {
    success: true
  }
})

registerSafeIpcHandler('export-diagnostic-report', async (event, rendererState = {}) => {
  const snapshot = diagnosticsController?.getSnapshot?.() || {}
  const defaultPath = path.join(
    snapshot.diagnosticsDir || path.join(app.getPath('userData'), 'diagnostics'),
    `WordZ-diagnostics-${snapshot.sessionId || Date.now()}.md`
  )
  const result = await showSaveDialogForApp({
    defaultPath,
    filters: [{ name: 'Markdown 文件', extensions: ['md'] }, { name: '文本文件', extensions: ['txt'] }]
  })

  if (result.canceled || !result.filePath) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了诊断报告导出'
    }
  }

  const exportResult = await diagnosticsController.exportReport(result.filePath, rendererState)
  return {
    success: true,
    filePath: exportResult.filePath
  }
})

registerSafeIpcHandler('open-github-feedback', async (event, payload = {}) => {
  const issueUrl = diagnosticsController?.getGitHubIssueUrl?.(
    payload?.rendererState ?? {},
    normalizeTextInput(payload?.issueTitle, { fallback: '[Bug] 请简要描述问题', maxLength: 120 })
  ) || ''

  if (!issueUrl) {
    return {
      success: false,
      message: '当前仓库未配置可用的 GitHub Issues 地址。'
    }
  }

  await shell.openExternal(issueUrl)
  return {
    success: true,
    issueUrl
  }
})

registerSafeIpcHandler('open-external-url', async (event, rawUrl) => {
  const externalUrl = normalizeExternalUrlInput(rawUrl)
  await shell.openExternal(externalUrl)
  return {
    success: true,
    url: externalUrl
  }
})

registerSafeIpcHandler('open-quick-corpus', async () => {
  const result = await showOpenDialogForApp({
    properties: ['openFile'],
    filters: [{ name: '语料文件', extensions: ['txt', 'docx', 'pdf'] }]
  })

  if (result.canceled || result.filePaths.length === 0) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了选择'
    }
  }

  const filePath = result.filePaths[0]
  const { content, encoding } = await readCorpusFile(filePath)

  return {
    success: true,
    mode: 'quick',
    filePath,
    fileName: path.basename(filePath),
    displayName: path.basename(filePath, path.extname(filePath)),
    content,
    sourceEncoding: encoding
  }
})

registerSafeIpcHandler('open-quick-corpus-at-path', async (event, filePath) => {
  const resolvedFilePath = normalizeFilePathInput(filePath, { fieldName: '语料路径' })
  if (!(await pathExists(fs, resolvedFilePath))) {
    return {
      success: false,
      message: '原始语料文件已不存在'
    }
  }

  const { content, encoding } = await readCorpusFile(resolvedFilePath)

  return {
    success: true,
    mode: 'quick',
    filePath: resolvedFilePath,
    fileName: path.basename(resolvedFilePath),
    displayName: path.basename(resolvedFilePath, path.extname(resolvedFilePath)),
    content,
    sourceEncoding: encoding
  }
})

registerSafeIpcHandler('import-and-save-corpus', async (event, payload = {}) => {
  const result = await showOpenDialogForApp({
    properties: ['openFile'],
    filters: [{ name: '语料文件', extensions: ['txt', 'docx', 'pdf'] }]
  })

  if (result.canceled || result.filePaths.length === 0) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了选择'
    }
  }

  const sourcePath = result.filePaths[0]
  const originalName = path.basename(sourcePath)
  const originalExt = path.extname(sourcePath).toLowerCase()
  const { content, encoding } = await readCorpusFile(sourcePath)
  const savedRecord = await getCorpusStorage().importCorpus({
    originalName,
    sourceType: originalExt === '.docx' ? 'docx' : originalExt === '.pdf' ? 'pdf' : 'txt',
    content,
    folderId:
      normalizeIdentifier(payload?.folderId, {
        fieldName: '文件夹 ID',
        allowEmpty: true
      }) || ''
  })

  return {
    success: true,
    mode: 'saved',
    corpusId: savedRecord.meta.id,
    filePath: savedRecord.filePath,
    fileName: savedRecord.fileName,
    displayName: savedRecord.meta.name,
    folderId: savedRecord.meta.folderId,
    folderName: savedRecord.meta.folderName,
    content,
    sourceEncoding: encoding
  }
})

registerSafeIpcHandler('backup-corpus-library', async () => {
  const result = await showOpenDialogForApp({
    properties: ['openDirectory', 'createDirectory']
  })

  if (result.canceled || result.filePaths.length === 0) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了备份位置选择'
    }
  }

  return getCorpusStorage().backupLibrary(result.filePaths[0])
})

registerSafeIpcHandler('restore-corpus-library', async () => {
  const result = await showOpenDialogForApp({
    properties: ['openDirectory']
  })

  if (result.canceled || result.filePaths.length === 0) {
    return {
      success: false,
      canceled: true,
      message: '用户取消了备份目录选择'
    }
  }

  return getCorpusStorage().restoreLibrary(result.filePaths[0])
})

registerSafeIpcHandler('repair-corpus-library', async () => {
  return getCorpusStorage().repairLibrary()
})

registerSafeIpcHandler('create-corpus-folder', async (event, folderName) => {
  return getCorpusStorage().createFolder(normalizeTextInput(folderName, { maxLength: 80 }))
})

registerSafeIpcHandler('rename-corpus-folder', async (event, { folderId, newName } = {}) => {
  return getCorpusStorage().renameFolder(
    normalizeIdentifier(folderId, { fieldName: '文件夹 ID' }),
    normalizeTextInput(newName, { maxLength: 80 })
  )
})

registerSafeIpcHandler('delete-corpus-folder', async (event, folderId) => {
  return getCorpusStorage().deleteFolder(normalizeIdentifier(folderId, { fieldName: '文件夹 ID' }))
})

registerSafeIpcHandler('list-saved-corpora', async (event, payload = {}) => {
  return getCorpusStorage().listLibrary(
    normalizeIdentifier(payload?.folderId, {
      fieldName: '文件夹 ID',
      allowAll: true,
      allowEmpty: true
    }) || 'all'
  )
})

registerSafeIpcHandler('list-searchable-corpora', async (event, payload = {}) => {
  return getCorpusStorage().listSearchableCorpora(
    normalizeIdentifier(payload?.folderId, {
      fieldName: '文件夹 ID',
      allowAll: true,
      allowEmpty: true
    }) || 'all'
  )
})

registerSafeIpcHandler('list-recycle-bin', async () => {
  return getCorpusStorage().listRecycleBin()
})

registerSafeIpcHandler('restore-recycle-entry', async (event, recycleEntryId) => {
  return getCorpusStorage().restoreRecycleEntry(
    normalizeIdentifier(recycleEntryId, { fieldName: '回收站条目 ID' })
  )
})

registerSafeIpcHandler('purge-recycle-entry', async (event, recycleEntryId) => {
  return getCorpusStorage().purgeRecycleEntry(
    normalizeIdentifier(recycleEntryId, { fieldName: '回收站条目 ID' })
  )
})

registerSafeIpcHandler('open-saved-corpus', async (event, corpusId) => {
  return getCorpusStorage().openCorpus(normalizeIdentifier(corpusId, { fieldName: '语料 ID' }))
})

registerSafeIpcHandler('open-saved-corpora', async (event, corpusIds = []) => {
  if (!Array.isArray(corpusIds) || corpusIds.length === 0) {
    return {
      success: false,
      message: '请至少选择一条语料'
    }
  }

  return getCorpusStorage().openCorpora(
    corpusIds.map(corpusId => normalizeIdentifier(corpusId, { fieldName: '语料 ID' }))
  )
})

registerSafeIpcHandler('rename-saved-corpus', async (event, { corpusId, newName } = {}) => {
  return getCorpusStorage().renameCorpus(
    normalizeIdentifier(corpusId, { fieldName: '语料 ID' }),
    normalizeTextInput(newName, { maxLength: 120 })
  )
})

registerSafeIpcHandler('move-saved-corpus', async (event, { corpusId, targetFolderId } = {}) => {
  return getCorpusStorage().moveCorpus(
    normalizeIdentifier(corpusId, { fieldName: '语料 ID' }),
    normalizeIdentifier(targetFolderId, {
      fieldName: '目标文件夹 ID',
      allowEmpty: true
    }) || ''
  )
})

registerSafeIpcHandler('delete-saved-corpus', async (event, corpusId) => {
  return getCorpusStorage().deleteCorpus(normalizeIdentifier(corpusId, { fieldName: '语料 ID' }))
})

process.on('uncaughtException', error => {
  captureMainError('main.uncaughtException', error)
  console.error('[uncaughtException]', error)
})

process.on('unhandledRejection', reason => {
  const normalizedError = reason instanceof Error ? reason : new Error(String(reason))
  captureMainError('main.unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  console.error('[unhandledRejection]', reason)
})

app.whenReady().then(async () => {
  diagnosticsController = createDiagnosticsController({
    app,
    packageManifest,
    logger: console
  })
  logMainDiagnostic('info', 'app', 'WordZ 正在启动。')

  try {
    await migrateLegacyUserDataDirIfNeeded({
      app,
      fs,
      path,
      legacyDirNames: LEGACY_USER_DATA_DIR_NAMES,
      smokeUserDataDir: SMOKE_USER_DATA_DIR,
      logger: console
    })
    await getCorpusStorage().prepare()
    logMainDiagnostic('info', 'storage', '本地语料库已准备完成。')
  } catch (error) {
    console.error('[corpus-library.prepare]', error)
    captureMainError('storage.prepare', error)
  }

  configureSessionSecurity()
  autoUpdateController = createAutoUpdateController({
    app,
    packageManifest,
    getWindows: () => BrowserWindow.getAllWindows(),
    logger: console
  })
  createWindow()
  autoUpdateController.initialize()
  logMainDiagnostic('info', 'app', '主窗口与自动更新已初始化。')

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow()
    }
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('before-quit', () => {
  logMainDiagnostic('info', 'app', '应用即将退出。')
  autoUpdateController?.dispose?.()
})
