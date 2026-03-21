const { app, BrowserWindow, ipcMain, dialog, session, shell, Notification, nativeImage, Menu } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const fs = require('fs/promises')
const ExcelJS = require('exceljs')
const packageManifest = require('./package.json')
const { CorpusStorage } = require('./corpusStorage')
const { readCorpusFile, inspectCorpusFilePreflight } = require('./corpusFileReader')
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
  addRecentDocumentIfSupported,
  extractLaunchAction,
  extractLaunchFilePaths,
  focusWindow,
  normalizeSupportedCorpusFilePath
} = require('./main/helpers/fileOpenSupport')
const { createSystemNotificationController } = require('./main/helpers/systemNotifications')
const { createWindowAttentionController } = require('./main/helpers/windowAttention')
const { createWindowProgressController } = require('./main/helpers/windowProgress')
const { createAnalysisCacheController } = require('./main/helpers/analysisCache')
const {
  migrateLegacyUserDataDirIfNeeded,
  pathExists
} = require('./main/helpers/userDataMigration')
const { registerSystemIpcRoutes } = require('./main/ipc/systemRoutes')
const { registerLibraryIpcRoutes } = require('./main/ipc/libraryRoutes')

let corpusStorage = null
let autoUpdateController = null
let diagnosticsController = null
let systemNotificationController = null
let windowAttentionController = null
let windowProgressController = null
let analysisCacheController = null
const APP_ENTRY_URL = pathToFileURL(path.join(__dirname, 'index.html')).toString()
const LEGACY_USER_DATA_DIR_NAMES = ['语料助手', 'corpus-lite', 'WordZou']
const APP_USER_MODEL_ID = packageManifest?.build?.appId || 'com.zzwdh.wordz'
const SMOKE_USER_DATA_DIR = normalizeOptionalPathEnv('CORPUS_LITE_SMOKE_USER_DATA_DIR')
const SMOKE_OPEN_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE')
const SMOKE_SAVE_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE')
const DISABLE_SINGLE_INSTANCE = normalizeBooleanInput(process.env.CORPUS_LITE_DISABLE_SINGLE_INSTANCE)
const IS_SMOKE_ENV = Boolean(SMOKE_USER_DATA_DIR)
const SMOKE_EVENT_LIMIT = 60
const smokeObserverState = {
  notifications: [],
  notificationActions: [],
  windowAttention: [],
  windowProgress: []
}

function pushSmokeObserverEvent(type, event) {
  if (!IS_SMOKE_ENV) return
  if (!smokeObserverState[type]) return
  smokeObserverState[type].push({
    timestamp: new Date().toISOString(),
    ...event
  })
  smokeObserverState[type] = smokeObserverState[type].slice(-SMOKE_EVENT_LIMIT)
}
let systemOpenBridgeReady = false
const pendingSystemOpenFilePaths = []
const pendingAppMenuActions = []
const pendingSystemNotificationActions = []
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

function getPrimaryWindow() {
  return BrowserWindow.getAllWindows().find(win => win && !win.isDestroyed?.()) || null
}

function queueSystemOpenFilePath(filePath) {
  const normalizedPath = normalizeSupportedCorpusFilePath(filePath)
  if (!normalizedPath) return ''

  const existingIndex = pendingSystemOpenFilePaths.indexOf(normalizedPath)
  if (existingIndex >= 0) {
    pendingSystemOpenFilePaths.splice(existingIndex, 1)
  }
  pendingSystemOpenFilePaths.push(normalizedPath)
  return normalizedPath
}

function consumePendingSystemOpenFilePaths() {
  const filePaths = [...pendingSystemOpenFilePaths]
  pendingSystemOpenFilePaths.length = 0
  return filePaths
}

function queueAppMenuAction(action) {
  const normalizedAction = String(action || '').trim()
  if (!normalizedAction) return ''

  pendingAppMenuActions.push(normalizedAction)
  if (pendingAppMenuActions.length > 30) {
    pendingAppMenuActions.splice(0, pendingAppMenuActions.length - 30)
  }
  return normalizedAction
}

function consumePendingAppMenuActions() {
  const actions = [...pendingAppMenuActions]
  pendingAppMenuActions.length = 0
  return actions
}

function sendAppMenuActionToWindow(targetWindow, action) {
  const normalizedAction = String(action || '').trim()
  if (!targetWindow || targetWindow.isDestroyed?.() || !normalizedAction) return false
  focusWindow(targetWindow)
  try {
    targetWindow.webContents.send('app-menu-action', {
      action: normalizedAction
    })
    return true
  } catch (error) {
    captureMainError('menu.dispatch-action', error, { action: normalizedAction })
    return false
  }
}

function flushPendingAppMenuActions(targetWindow = getPrimaryWindow()) {
  if (!systemOpenBridgeReady || !targetWindow || targetWindow.isDestroyed?.()) return
  const actions = consumePendingAppMenuActions()
  for (const action of actions) {
    if (!sendAppMenuActionToWindow(targetWindow, action)) {
      queueAppMenuAction(action)
    }
  }
}

function normalizeSystemNotificationActionPayload(payload = {}) {
  const actionId = String(payload?.actionId || '').trim()
  if (!actionId) return null

  return {
    actionId,
    tag: String(payload?.tag || '').trim(),
    title: String(payload?.title || '').trim(),
    body: String(payload?.body || '').trim(),
    actionPayload: payload?.actionPayload ?? null
  }
}

function queueSystemNotificationAction(payload) {
  const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
  if (!normalizedPayload) return null

  pendingSystemNotificationActions.push(normalizedPayload)
  if (pendingSystemNotificationActions.length > 30) {
    pendingSystemNotificationActions.splice(0, pendingSystemNotificationActions.length - 30)
  }
  return normalizedPayload
}

function consumePendingSystemNotificationActions() {
  const actions = [...pendingSystemNotificationActions]
  pendingSystemNotificationActions.length = 0
  return actions
}

function sendSystemNotificationActionToWindow(targetWindow, payload) {
  const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
  if (!targetWindow || targetWindow.isDestroyed?.() || !normalizedPayload) return false

  focusWindow(targetWindow)
  try {
    targetWindow.webContents.send('system-notification-action', normalizedPayload)
    return true
  } catch (error) {
    captureMainError('system-notification.dispatch-action', error, normalizedPayload)
    return false
  }
}

function flushPendingSystemNotificationActions(targetWindow = getPrimaryWindow()) {
  if (!systemOpenBridgeReady || !targetWindow || targetWindow.isDestroyed?.()) return
  const actions = consumePendingSystemNotificationActions()
  for (const action of actions) {
    if (!sendSystemNotificationActionToWindow(targetWindow, action)) {
      queueSystemNotificationAction(action)
    }
  }
}

function dispatchSystemNotificationAction(payload) {
  const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
  if (!normalizedPayload) return false

  const primaryWindow = getPrimaryWindow()
  if (!primaryWindow || !systemOpenBridgeReady) {
    queueSystemNotificationAction(normalizedPayload)
    if (primaryWindow) {
      focusWindow(primaryWindow)
    } else if (app.isReady()) {
      const createdWindow = createWindow()
      createdWindow.webContents.once('did-finish-load', () => {
        flushPendingSystemNotificationActions(createdWindow)
      })
    }
    return false
  }

  if (!sendSystemNotificationActionToWindow(primaryWindow, normalizedPayload)) {
    queueSystemNotificationAction(normalizedPayload)
    return false
  }

  return true
}

function dispatchSystemOpenFilePath(filePath) {
  const normalizedPath = normalizeSupportedCorpusFilePath(filePath)
  if (!normalizedPath) return false

  const primaryWindow = getPrimaryWindow()
  if (!systemOpenBridgeReady || !primaryWindow) {
    queueSystemOpenFilePath(normalizedPath)
    if (primaryWindow) {
      focusWindow(primaryWindow)
    } else if (app.isReady()) {
      createWindow()
    }
    return false
  }

  try {
    focusWindow(primaryWindow)
    primaryWindow.webContents.send('system-open-file-request', {
      filePath: normalizedPath
    })
    return true
  } catch (error) {
    queueSystemOpenFilePath(normalizedPath)
    captureMainError('system-open.dispatch', error, { filePath: normalizedPath })
    return false
  }
}

function handleSystemOpenFilePaths(filePaths = []) {
  const normalizedPaths = extractLaunchFilePaths(filePaths)
  if (normalizedPaths.length === 0) {
    const primaryWindow = getPrimaryWindow()
    if (primaryWindow) focusWindow(primaryWindow)
    return
  }

  let hasDispatched = false
  for (const filePath of normalizedPaths) {
    if (dispatchSystemOpenFilePath(filePath)) {
      hasDispatched = true
    }
  }

  if (!hasDispatched && app.isReady() && !getPrimaryWindow()) {
    createWindow()
  }
}

if (!DISABLE_SINGLE_INSTANCE) {
  const hasSingleInstanceLock = app.requestSingleInstanceLock()
  if (!hasSingleInstanceLock) {
    app.quit()
  } else {
    app.on('second-instance', (_event, argv) => {
      handleLaunchActionArgs(argv)
      handleSystemOpenFilePaths(argv)
    })
  }
}

app.on('open-file', (event, filePath) => {
  event.preventDefault()
  handleSystemOpenFilePaths([filePath])
})

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
  systemOpenBridgeReady = false
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
  win.on('closed', () => {
    if (!getPrimaryWindow()) {
      systemOpenBridgeReady = false
    }
  })
  win.on('unresponsive', () => {
    const error = new Error('窗口无响应')
    captureMainError('window.unresponsive', error)
    void diagnosticsController?.markCrashRecoveryState?.('window.unresponsive', error)
  })
  win.webContents.on('render-process-gone', (_event, details) => {
    const error = new Error(`渲染进程已退出：${details?.reason || 'unknown'}`)
    captureMainError('window.render-process-gone', error, details)
    void diagnosticsController?.markCrashRecoveryState?.('window.render-process-gone', error, details)
  })
  win.loadFile('index.html')
  win.webContents.on('did-finish-load', () => {
    autoUpdateController?.broadcastStatus?.()
    logMainDiagnostic('info', 'window', '主窗口已完成加载。')
  })
  return win
}

function dispatchAppMenuAction(action) {
  const normalizedAction = String(action || '').trim()
  if (!normalizedAction) return

  const primaryWindow = getPrimaryWindow()
  if (!primaryWindow) {
    queueAppMenuAction(normalizedAction)
    if (!app.isReady()) return
    const createdWindow = createWindow()
    createdWindow.webContents.once('did-finish-load', () => {
      flushPendingAppMenuActions(createdWindow)
    })
    return
  }

  if (!systemOpenBridgeReady) {
    queueAppMenuAction(normalizedAction)
    focusWindow(primaryWindow)
    return
  }

  if (!sendAppMenuActionToWindow(primaryWindow, normalizedAction)) {
    queueAppMenuAction(normalizedAction)
  }
}

function buildApplicationMenuTemplate() {
  const locale = String(typeof app.getLocale === 'function' ? app.getLocale() : '').toLowerCase()
  const isZhLocale = locale.startsWith('zh')
  const fileMenuLabel = isZhLocale ? '文件' : 'File'
  const toolsMenuLabel = isZhLocale ? '工具' : 'Tools'
  const statsLabel = isZhLocale ? '开始统计' : 'Run Statistics'
  const checkUpdateLabel = isZhLocale ? '检查更新' : 'Check Updates'
  const settingsLabel = isZhLocale ? '打开设置' : 'Open Settings'
  const taskCenterLabel = isZhLocale ? '切换任务中心' : 'Toggle Task Center'
  const commandPaletteLabel = isZhLocale ? '命令面板…' : 'Command Palette…'
  const helpLabel = isZhLocale ? '打开帮助中心' : 'Open Help Center'
  const quickOpenLabel = isZhLocale ? '快速打开语料…' : 'Quick Open Corpus…'
  const importAndSaveLabel = isZhLocale ? '导入并保存语料…' : 'Import And Save Corpus…'
  const openLibraryLabel = isZhLocale ? '打开本地语料库' : 'Open Local Library'
  const fileSubmenu = [
    {
      label: quickOpenLabel,
      accelerator: 'CmdOrCtrl+O',
      click: () => {
        dispatchAppMenuAction('open-quick-corpus')
      }
    },
    {
      label: importAndSaveLabel,
      accelerator: 'CmdOrCtrl+Shift+O',
      click: () => {
        dispatchAppMenuAction('import-and-save-corpus')
      }
    },
    {
      label: openLibraryLabel,
      accelerator: 'CmdOrCtrl+L',
      click: () => {
        dispatchAppMenuAction('open-library')
      }
    },
    { type: 'separator' },
    process.platform === 'darwin' ? { role: 'close' } : { role: 'quit' }
  ]

  const toolsSubmenu = [
    {
      label: statsLabel,
      accelerator: 'CmdOrCtrl+Enter',
      click: () => {
        dispatchAppMenuAction('run-stats')
      }
    },
    { type: 'separator' },
    {
      label: checkUpdateLabel,
      accelerator: 'CmdOrCtrl+U',
      click: () => {
        dispatchAppMenuAction('check-update')
      }
    },
    {
      label: settingsLabel,
      accelerator: 'CmdOrCtrl+,',
      click: () => {
        dispatchAppMenuAction('open-settings')
      }
    },
    {
      label: commandPaletteLabel,
      accelerator: 'CmdOrCtrl+K',
      click: () => {
        dispatchAppMenuAction('open-command-palette')
      }
    },
    {
      label: taskCenterLabel,
      accelerator: 'CmdOrCtrl+J',
      click: () => {
        dispatchAppMenuAction('toggle-task-center')
      }
    },
    {
      label: helpLabel,
      click: () => {
        dispatchAppMenuAction('open-help-center')
      }
    }
  ]

  const template = [
    {
      label: fileMenuLabel,
      submenu: fileSubmenu
    },
    {
      label: toolsMenuLabel,
      submenu: toolsSubmenu
    },
    { role: 'editMenu' },
    { role: 'viewMenu' },
    { role: 'windowMenu' }
  ]

  if (process.platform === 'darwin') {
    template.unshift({
      role: 'appMenu',
      submenu: [{ role: 'about' }, { type: 'separator' }, { role: 'services' }, { type: 'separator' }, { role: 'hide' }, { role: 'hideOthers' }, { role: 'unhide' }, { type: 'separator' }, { role: 'quit' }]
    })
  } else {
    template.push({
      role: 'help',
      submenu: [{ label: '关于 WordZ', click: () => dispatchAppMenuAction('open-help-center') }]
    })
  }

  return template
}

function setupApplicationMenu() {
  const menu = Menu.buildFromTemplate(buildApplicationMenuTemplate())
  Menu.setApplicationMenu(menu)
}

function setupDockQuickMenu() {
  if (process.platform !== 'darwin') return
  if (!app.dock || typeof app.dock.setMenu !== 'function') return

  const dockMenu = Menu.buildFromTemplate([
    {
      label: '快速打开语料…',
      click: () => dispatchAppMenuAction('open-quick-corpus')
    },
    {
      label: '导入并保存语料…',
      click: () => dispatchAppMenuAction('import-and-save-corpus')
    },
    {
      label: '打开本地语料库',
      click: () => dispatchAppMenuAction('open-library')
    }
  ])
  app.dock.setMenu(dockMenu)
}

function setupWindowsJumpList() {
  if (process.platform !== 'win32') return
  if (typeof app.setJumpList !== 'function') return

  const taskIconPath = process.execPath
  const taskProgramPath = process.execPath
  const buildTaskItem = ({ title, description, action }) => ({
    type: 'task',
    title,
    description,
    program: taskProgramPath,
    args: `--wordz-action=${action}`,
    iconPath: taskIconPath,
    iconIndex: 0
  })

  try {
    app.setJumpList([
      {
        type: 'tasks',
        items: [
          buildTaskItem({
            title: '快速打开语料',
            description: '快速打开 txt / docx / pdf 语料',
            action: 'open-quick-corpus'
          }),
          buildTaskItem({
            title: '导入并保存语料',
            description: '导入语料并保存到本地语料库',
            action: 'import-and-save-corpus'
          }),
          buildTaskItem({
            title: '打开本地语料库',
            description: '进入本地语料库并管理语料',
            action: 'open-library'
          })
        ]
      },
      { type: 'recent' }
    ])
  } catch (error) {
    captureMainError('windows.jump-list', error)
  }
}

function setupPlatformFileIntegration() {
  setupDockQuickMenu()
  setupWindowsJumpList()
}

function handleLaunchActionArgs(argv = []) {
  const launchAction = extractLaunchAction(argv)
  if (!launchAction) return
  dispatchAppMenuAction(launchAction)
}

function getCorpusStorage() {
  if (!corpusStorage) {
    corpusStorage = new CorpusStorage(path.join(app.getPath('userData'), 'corpus-library'))
  }

  return corpusStorage
}

async function showItemInSystemFileManager(targetPath, { fieldName = '目标路径', missingMessage = '目标路径不存在' } = {}) {
  const resolvedPath = normalizeFilePathInput(targetPath, { fieldName })
  if (!(await pathExists(fs, resolvedPath))) {
    return {
      success: false,
      message: missingMessage
    }
  }

  shell.showItemInFolder(resolvedPath)
  return {
    success: true,
    path: resolvedPath
  }
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

registerSystemIpcRoutes({
  registerSafeIpcHandler,
  fs,
  path,
  ExcelJS,
  app,
  packageManifest,
  getAppInfo,
  showSaveDialogForApp,
  normalizeTextInput,
  normalizeTableRows,
  normalizeBooleanInput,
  normalizeExternalUrlInput,
  normalizeFilePathInput,
  pathExists,
  showItemInSystemFileManager,
  getSystemNotificationController: () => systemNotificationController,
  getWindowProgressController: () => windowProgressController,
  getWindowAttentionController: () => windowAttentionController,
  isSmokeEnv: IS_SMOKE_ENV,
  getSmokeObserverState: () => ({
    notifications: [...smokeObserverState.notifications],
    notificationActions: [...smokeObserverState.notificationActions],
    windowAttention: [...smokeObserverState.windowAttention],
    windowProgress: [...smokeObserverState.windowProgress]
  }),
  markSystemOpenBridgeReady: () => {
    systemOpenBridgeReady = true
    flushPendingAppMenuActions()
    flushPendingSystemNotificationActions()
  },
  consumePendingSystemOpenFilePaths,
  getAutoUpdateController: () => autoUpdateController,
  getDiagnosticsController: () => diagnosticsController,
  getAnalysisCacheController: () => analysisCacheController,
  shell
})

registerLibraryIpcRoutes({
  registerSafeIpcHandler,
  app,
  fs,
  path,
  showOpenDialogForApp,
  readCorpusFile,
  inspectCorpusFilePreflight,
  addRecentDocumentIfSupported,
  getCorpusStorage,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTextInput,
  pathExists,
  showItemInSystemFileManager
})

process.on('uncaughtException', error => {
  captureMainError('main.uncaughtException', error)
  void diagnosticsController?.markCrashRecoveryState?.('main.uncaughtException', error)
  console.error('[uncaughtException]', error)
})

process.on('unhandledRejection', reason => {
  const normalizedError = reason instanceof Error ? reason : new Error(String(reason))
  captureMainError('main.unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  void diagnosticsController?.markCrashRecoveryState?.('main.unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  console.error('[unhandledRejection]', reason)
})

app.whenReady().then(async () => {
  if (process.platform === 'win32' && typeof app.setAppUserModelId === 'function') {
    app.setAppUserModelId(APP_USER_MODEL_ID)
  }
  diagnosticsController = createDiagnosticsController({
    app,
    packageManifest,
    logger: console
  })
  analysisCacheController = createAnalysisCacheController({
    app,
    fs,
    logger: console
  })
  windowProgressController = createWindowProgressController({
    platform: process.platform,
    getWindows: () => BrowserWindow.getAllWindows(),
    logger: console,
    onApply: event => {
      pushSmokeObserverEvent('windowProgress', event)
    }
  })
  windowAttentionController = createWindowAttentionController({
    app,
    nativeImage,
    appName: packageManifest.productName || packageManifest.name || app.getName() || 'WordZ',
    platform: process.platform,
    getWindows: () => BrowserWindow.getAllWindows(),
    logger: console,
    onApply: event => {
      pushSmokeObserverEvent('windowAttention', event)
    }
  })
  systemNotificationController = createSystemNotificationController({
    NotificationClass: Notification,
    appName: packageManifest.productName || packageManifest.name || app.getName() || 'WordZ',
    logger: console,
    onShow: event => {
      pushSmokeObserverEvent('notifications', event)
    },
    onAction: event => {
      pushSmokeObserverEvent('notificationActions', event)
      dispatchSystemNotificationAction(event)
    }
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
  setupApplicationMenu()
  setupPlatformFileIntegration()
  autoUpdateController = createAutoUpdateController({
    app,
    packageManifest,
    getWindows: () => BrowserWindow.getAllWindows(),
    onProgressStateChange: (state, progressPercent = 0) => {
      if (!windowProgressController) return
      if (state === 'checking') {
        windowProgressController.updateSource('auto-update', {
          state: 'indeterminate',
          priority: 90
        })
        return
      }
      if (state === 'downloading') {
        const normalizedProgress = Math.min(Math.max(Number(progressPercent) || 0, 0), 100) / 100
        windowProgressController.updateSource('auto-update', {
          state: Number.isFinite(normalizedProgress) && normalizedProgress > 0 ? 'normal' : 'indeterminate',
          progress: normalizedProgress,
          priority: 90
        })
        return
      }
      windowProgressController.clearSource('auto-update')
    },
    logger: console
  })
  handleLaunchActionArgs(process.argv)
  handleSystemOpenFilePaths(process.argv)
  if (!getPrimaryWindow()) {
    createWindow()
  }
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
  windowAttentionController?.clearAll?.()
  windowProgressController?.clearAll?.()
  autoUpdateController?.dispose?.()
})
