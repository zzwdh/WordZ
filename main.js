const { app, BrowserWindow, ipcMain, dialog, session } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const fs = require('fs/promises')
const ExcelJS = require('exceljs')
const packageManifest = require('./package.json')
const { CorpusStorage } = require('./corpusStorage')
const { readCorpusFile } = require('./corpusFileReader')
const { createAutoUpdateController } = require('./autoUpdate')

let corpusStorage = null
let autoUpdateController = null
const APP_ENTRY_URL = pathToFileURL(path.join(__dirname, 'index.html')).toString()
const LEGACY_USER_DATA_DIR_NAMES = ['语料助手', 'corpus-lite', 'WordZou']
const SAFE_ID_PATTERN = /^[A-Za-z0-9_-]{1,160}$/
const MAX_EXPORT_ROWS = 250000
const MAX_EXPORT_COLUMNS = 256
const MAX_EXPORT_CELL_LENGTH = 100000
const SMOKE_USER_DATA_DIR = normalizeOptionalPathEnv('CORPUS_LITE_SMOKE_USER_DATA_DIR')
const SMOKE_OPEN_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE')
const SMOKE_SAVE_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE')

if (SMOKE_USER_DATA_DIR) {
  app.setPath('userData', SMOKE_USER_DATA_DIR)
  app.setPath('sessionData', path.join(SMOKE_USER_DATA_DIR, 'session-data'))
}

function readJsonArrayEnv(name) {
  const rawValue = process.env[name]
  if (!rawValue) return null

  try {
    const parsedValue = JSON.parse(rawValue)
    return Array.isArray(parsedValue) ? [...parsedValue] : null
  } catch (error) {
    console.warn(`[${name}] 解析失败`, error)
    return null
  }
}

function normalizeOptionalPathEnv(name) {
  const rawValue = String(process.env[name] || '').trim()
  return rawValue ? path.resolve(rawValue) : ''
}

function normalizeTextInput(value, { fallback = '', maxLength = 160 } = {}) {
  return String(value ?? fallback).trim().slice(0, maxLength)
}

function normalizeIdentifier(value, { fieldName = '标识', allowAll = false, allowEmpty = false } = {}) {
  const normalizedValue = String(value ?? '').trim()
  if (!normalizedValue) {
    if (allowEmpty) return ''
    throw new Error(`${fieldName}不能为空`)
  }
  if (allowAll && normalizedValue === 'all') return 'all'
  if (!SAFE_ID_PATTERN.test(normalizedValue)) {
    throw new Error(`${fieldName}格式不合法`)
  }
  return normalizedValue
}

function normalizeTableRows(rows) {
  if (!Array.isArray(rows)) {
    throw new Error('表格数据格式不合法')
  }
  if (rows.length > MAX_EXPORT_ROWS) {
    throw new Error('导出数据过大，请缩小导出范围后重试')
  }

  return rows.map((row, rowIndex) => {
    if (!Array.isArray(row)) {
      throw new Error(`第 ${rowIndex + 1} 行表格数据格式不合法`)
    }
    if (row.length > MAX_EXPORT_COLUMNS) {
      throw new Error(`第 ${rowIndex + 1} 行列数过多，请缩小导出范围后重试`)
    }

    return row.map(cell => String(cell ?? '').slice(0, MAX_EXPORT_CELL_LENGTH))
  })
}

function getAppInfo() {
  const autoUpdateSnapshot = autoUpdateController?.getStatusSnapshot?.() || {}
  const author =
    typeof packageManifest.author === 'string'
      ? packageManifest.author
      : packageManifest.author && typeof packageManifest.author.name === 'string'
        ? packageManifest.author.name
        : ''
  const wordzMeta =
    packageManifest.wordz && typeof packageManifest.wordz === 'object'
      ? packageManifest.wordz
      : {}
  const help = Array.isArray(wordzMeta.help)
    ? wordzMeta.help.map(item => String(item).trim()).filter(Boolean)
    : []

  return {
    name: packageManifest.productName || app.getName() || packageManifest.name || 'WordZ',
    version: app.getVersion() || packageManifest.version || '',
    description: packageManifest.description || '',
    author,
    help,
    autoUpdateConfigured: Boolean(autoUpdateSnapshot.configured),
    autoUpdateProvider: String(autoUpdateSnapshot.provider || '').trim(),
    autoUpdateProviderLabel: String(autoUpdateSnapshot.providerLabel || '').trim(),
    autoUpdateTarget: String(autoUpdateSnapshot.providerTarget || '').trim(),
    releaseNotes: Array.isArray(wordzMeta.releaseNotes)
      ? wordzMeta.releaseNotes.map(item => String(item).trim()).filter(Boolean)
      : []
  }
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

function takeSmokeDialogQueueItem(queue, label) {
  if (!queue) return null
  if (queue.length === 0) {
    throw new Error(`测试 ${label} 对话框队列已耗尽`)
  }
  return queue.shift()
}

function resolveSmokeOpenDialogResult(queuedItem) {
  if (
    queuedItem &&
    typeof queuedItem === 'object' &&
    !Array.isArray(queuedItem) &&
    queuedItem.canceled
  ) {
    return {
      canceled: true,
      filePaths: []
    }
  }

  const filePaths = Array.isArray(queuedItem) ? queuedItem.map(item => String(item)) : [String(queuedItem)]
  return {
    canceled: false,
    filePaths
  }
}

function resolveSmokeSaveDialogResult(queuedItem) {
  if (
    queuedItem &&
    typeof queuedItem === 'object' &&
    !Array.isArray(queuedItem) &&
    queuedItem.canceled
  ) {
    return {
      canceled: true,
      filePath: ''
    }
  }

  return {
    canceled: false,
    filePath: String(queuedItem)
  }
}

async function showOpenDialogForApp(options) {
  const queuedItem = takeSmokeDialogQueueItem(SMOKE_OPEN_DIALOG_QUEUE, '打开')
  if (queuedItem !== null) {
    return resolveSmokeOpenDialogResult(queuedItem)
  }
  return dialog.showOpenDialog(options)
}

async function showSaveDialogForApp(options) {
  const queuedItem = takeSmokeDialogQueueItem(SMOKE_SAVE_DIALOG_QUEUE, '保存')
  if (queuedItem !== null) {
    return resolveSmokeSaveDialogResult(queuedItem)
  }
  return dialog.showSaveDialog(options)
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
  win.loadFile('index.html')
  win.webContents.on('did-finish-load', () => {
    autoUpdateController?.broadcastStatus?.()
  })
  return win
}

function getCorpusStorage() {
  if (!corpusStorage) {
    corpusStorage = new CorpusStorage(path.join(app.getPath('userData'), 'corpus-library'))
  }

  return corpusStorage
}

async function pathExists(targetPath) {
  try {
    await fs.access(targetPath)
    return true
  } catch {
    return false
  }
}

async function copyDirectoryContents(sourceDir, targetDir) {
  await fs.mkdir(targetDir, { recursive: true })
  const entries = await fs.readdir(sourceDir, { withFileTypes: true })
  for (const entry of entries) {
    const sourcePath = path.join(sourceDir, entry.name)
    const targetPath = path.join(targetDir, entry.name)
    if (entry.isDirectory()) {
      await copyDirectoryContents(sourcePath, targetPath)
    } else if (entry.isFile()) {
      await fs.copyFile(sourcePath, targetPath)
    }
  }
}

async function migrateLegacyUserDataDirIfNeeded() {
  if (SMOKE_USER_DATA_DIR) return

  const targetUserDataDir = app.getPath('userData')
  if (await pathExists(targetUserDataDir)) return

  const appDataDir = app.getPath('appData')
  for (const legacyDirName of LEGACY_USER_DATA_DIR_NAMES) {
    const legacyUserDataDir = path.join(appDataDir, legacyDirName)
    if (legacyUserDataDir === targetUserDataDir) continue
    if (!(await pathExists(legacyUserDataDir))) continue

    try {
      await fs.rename(legacyUserDataDir, targetUserDataDir)
      console.log(`[user-data] 已迁移旧目录：${legacyUserDataDir} -> ${targetUserDataDir}`)
      return
    } catch (renameError) {
      console.warn('[user-data.rename]', renameError)
    }

    try {
      await copyDirectoryContents(legacyUserDataDir, targetUserDataDir)
      console.log(`[user-data] 已复制旧目录：${legacyUserDataDir} -> ${targetUserDataDir}`)
      return
    } catch (copyError) {
      console.warn('[user-data.copy]', copyError)
    }
  }
}

function registerSafeIpcHandler(channel, handler) {
  ipcMain.handle(channel, async (event, payload) => {
    try {
      assertTrustedIpcSender(event)
      return await handler(event, payload)
    } catch (error) {
      console.error(`[${channel}]`, error)
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
    appInfo: getAppInfo()
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

app.whenReady().then(async () => {
  try {
    await migrateLegacyUserDataDirIfNeeded()
    await getCorpusStorage().prepare()
  } catch (error) {
    console.error('[corpus-library.prepare]', error)
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
  autoUpdateController?.dispose?.()
})
