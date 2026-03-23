const { app, BrowserWindow, ipcMain, dialog, session, shell, Notification, nativeImage, Menu, protocol } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const os = require('os')
const fsSync = require('fs')
const fs = require('fs/promises')
const packageManifest = require('./package.json')
const { createAutoUpdateController } = require('./autoUpdate')
const { createDiagnosticsController } = require('./diagnostics')
const { getAppInfo } = require('./main/helpers/appInfo')
const { initializeAppReadyState } = require('./main/helpers/appReady')
const {
  setupCommonAppLifecycleHandlers,
  setupOpenFileHandler,
  setupProcessErrorHandling,
  setupSingleInstanceHandling
} = require('./main/helpers/appLifecycle')
const { createAppSecurityController } = require('./main/helpers/appSecurity')
const { getPlatformShellPaths } = require('./main/helpers/platformShell')
const { createWindowBridgeController } = require('./main/helpers/windowBridge')
const { createWindowController } = require('./main/helpers/windowController')
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
const {
  setupApplicationMenu,
  setupPlatformFileIntegration,
  handleLaunchActionArgs
} = require('./main/helpers/platformMenu')
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

const EARLY_CRASH_LOG_PATH = path.join(os.tmpdir(), 'wordz-startup-crash.log')

function appendEarlyCrashLog(scope, error, details = null) {
  const time = new Date().toISOString()
  const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error || '')
  const stack = error instanceof Error ? error.stack || '' : ''
  const detailText = details ? `\n${JSON.stringify(details, null, 2)}` : ''
  const line = `[${time}] [${scope}] ${message}\n${stack}${detailText}\n\n`
  try {
    fsSync.appendFileSync(EARLY_CRASH_LOG_PATH, line, 'utf8')
  } catch {
    // ignore early-crash log failures
  }
}

function showStartupErrorBox(error, scope = 'startup') {
  const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error || 'Unknown error')
  const detail = `位置：${scope}\n日志：${EARLY_CRASH_LOG_PATH}`
  try {
    dialog.showErrorBox('WordZ 启动失败', `${message}\n\n${detail}`)
  } catch {
    // ignore dialog failures during early startup
  }
}

let corpusStorageClassCache = null
let corpusFileReaderModuleCache = null
let excelJSModuleCache = null

function getCorpusStorageClass() {
  if (corpusStorageClassCache) return corpusStorageClassCache
  const moduleExports = require('./corpusStorage')
  if (typeof moduleExports?.CorpusStorage !== 'function') {
    throw new Error('语料库存储模块初始化失败：未找到 CorpusStorage')
  }
  corpusStorageClassCache = moduleExports.CorpusStorage
  return corpusStorageClassCache
}

function getCorpusFileReaderModule() {
  if (corpusFileReaderModuleCache) return corpusFileReaderModuleCache
  const moduleExports = require('./corpusFileReader')
  if (typeof moduleExports?.readCorpusFile !== 'function') {
    throw new Error('语料读取模块初始化失败：未找到 readCorpusFile')
  }
  if (typeof moduleExports?.inspectCorpusFilePreflight !== 'function') {
    throw new Error('语料读取模块初始化失败：未找到 inspectCorpusFilePreflight')
  }
  corpusFileReaderModuleCache = moduleExports
  return corpusFileReaderModuleCache
}

function getExcelJSModule() {
  if (excelJSModuleCache) return excelJSModuleCache
  const moduleExports = require('exceljs')
  if (typeof moduleExports?.Workbook !== 'function') {
    throw new Error('Excel 导出模块初始化失败：未找到 Workbook')
  }
  excelJSModuleCache = moduleExports
  return excelJSModuleCache
}

async function readCorpusFileSafely(filePath) {
  const moduleExports = getCorpusFileReaderModule()
  return moduleExports.readCorpusFile(filePath)
}

async function inspectCorpusFilePreflightSafely(filePath, options) {
  const moduleExports = getCorpusFileReaderModule()
  return moduleExports.inspectCorpusFilePreflight(filePath, options)
}

let corpusStorage = null
let autoUpdateController = null
let diagnosticsController = null
let systemNotificationController = null
let windowAttentionController = null
let windowProgressController = null
let analysisCacheController = null
const {
  indexHtmlPath: INDEX_HTML_PATH,
  protocolStartupAssets: PROTOCOL_STARTUP_ASSETS
} = getPlatformShellPaths({
  path,
  baseDir: __dirname,
  platform: process.platform
})
const PRELOAD_SCRIPT_PATH = path.join(__dirname, 'preload.js')
const APP_PROTOCOL_SCHEME = 'wordz'
const APP_PROTOCOL_HOST = 'app'
const FILE_APP_ENTRY_URL = pathToFileURL(INDEX_HTML_PATH).toString()
const PROTOCOL_APP_ENTRY_URL = `${APP_PROTOCOL_SCHEME}://${APP_PROTOCOL_HOST}/index.html`
const TRUSTED_DATA_URL_PREFIX = 'data:text/html;charset=UTF-8,'
const LEGACY_USER_DATA_DIR_NAMES = ['语料助手', 'corpus-lite', 'WordZou']
const APP_USER_MODEL_ID = packageManifest?.build?.appId || 'com.zzwdh.wordz'
const SMOKE_USER_DATA_DIR = normalizeOptionalPathEnv('CORPUS_LITE_SMOKE_USER_DATA_DIR')
const SMOKE_OPEN_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_OPEN_DIALOG_QUEUE')
const SMOKE_SAVE_DIALOG_QUEUE = readJsonArrayEnv('CORPUS_LITE_SMOKE_SAVE_DIALOG_QUEUE')
const PACKAGED_SMOKE_RESULT_PATH = normalizeOptionalPathEnv('CORPUS_LITE_PACKAGED_SMOKE_RESULT_PATH')
const PACKAGED_SMOKE_AUTORUN = normalizeBooleanInput(process.env.CORPUS_LITE_PACKAGED_SMOKE_AUTORUN)
const DISABLE_SINGLE_INSTANCE = normalizeBooleanInput(process.env.CORPUS_LITE_DISABLE_SINGLE_INSTANCE)
const FORCE_SOFTWARE_RENDERING = normalizeBooleanInput(
  process.env.WORDZ_FORCE_SOFTWARE_RENDERING ?? process.env.CORPUS_LITE_FORCE_SOFTWARE_RENDERING
)
const ENABLE_CUSTOM_PROTOCOL = process.platform !== 'win32'
const APP_ENTRY_URL = ENABLE_CUSTOM_PROTOCOL ? PROTOCOL_APP_ENTRY_URL : FILE_APP_ENTRY_URL
const DISABLE_RENDERER_SANDBOX = normalizeBooleanInput(process.env.WORDZ_DISABLE_RENDERER_SANDBOX)
const IS_SMOKE_ENV = Boolean(SMOKE_USER_DATA_DIR)
const IS_PACKAGED_SMOKE_ENV = IS_SMOKE_ENV && PACKAGED_SMOKE_AUTORUN && Boolean(PACKAGED_SMOKE_RESULT_PATH)
const SMOKE_EVENT_LIMIT = 60
const smokeObserverState = {
  notifications: [],
  notificationActions: [],
  windowAttention: [],
  windowProgress: []
}

if (SMOKE_USER_DATA_DIR) {
  app.setPath('userData', SMOKE_USER_DATA_DIR)
  app.setPath('sessionData', path.join(SMOKE_USER_DATA_DIR, 'session-data'))
}

const appSecurityController = createAppSecurityController({
  app,
  session,
  protocol,
  fs,
  fsSync,
  path,
  baseDir: __dirname,
  indexHtmlPath: INDEX_HTML_PATH,
  appProtocolScheme: APP_PROTOCOL_SCHEME,
  appProtocolHost: APP_PROTOCOL_HOST,
  fileAppEntryUrl: FILE_APP_ENTRY_URL,
  protocolAppEntryUrl: PROTOCOL_APP_ENTRY_URL,
  appEntryUrl: APP_ENTRY_URL,
  trustedDataUrlPrefix: TRUSTED_DATA_URL_PREFIX,
  protocolStartupAssets: PROTOCOL_STARTUP_ASSETS,
  enableCustomProtocol: ENABLE_CUSTOM_PROTOCOL,
  responseCtor: globalThis.Response,
  appendEarlyCrashLog
})

const {
  assertTrustedIpcSender,
  configureSessionSecurity,
  isTrustedAppEntryUrl,
  isTrustedNavigationTarget,
  registerProtocolScheme,
  setupAppProtocol
} = appSecurityController

registerProtocolScheme()

appendEarlyCrashLog('bootstrap', 'WordZ main process launched', {
  pid: process.pid,
  platform: process.platform,
  arch: process.arch,
  version: packageManifest?.version || ''
})

if (process.platform === 'win32' || FORCE_SOFTWARE_RENDERING) {
  // Prioritize startup stability on Windows: avoid GPU/driver related white-screen issues.
  app.disableHardwareAcceleration()
  app.commandLine.appendSwitch('disable-gpu')
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
const {
  showOpenDialog: showOpenDialogForApp,
  showSaveDialog: showSaveDialogForApp
} = createDialogController({
  dialog,
  openQueue: SMOKE_OPEN_DIALOG_QUEUE,
  saveQueue: SMOKE_SAVE_DIALOG_QUEUE
})

function captureMainError(scope, error, details = null) {
  diagnosticsController?.captureError?.(scope, error, details)
}

function logMainDiagnostic(level, scope, message, details = null) {
  diagnosticsController?.log?.(level, scope, message, details)
}

let windowBridgeController = null
const windowController = createWindowController({
  app,
  BrowserWindow,
  fsSync,
  appendEarlyCrashLog,
  captureMainError,
  logMainDiagnostic,
  focusWindow,
  showStartupErrorBox,
  isTrustedAppEntryUrl,
  isTrustedNavigationTarget,
  getDiagnosticsController: () => diagnosticsController,
  getAutoUpdateController: () => autoUpdateController,
  resetSystemOpenBridgeReady: () => windowBridgeController?.resetSystemOpenBridgeReady?.(),
  indexHtmlPath: INDEX_HTML_PATH,
  preloadScriptPath: PRELOAD_SCRIPT_PATH,
  appEntryUrl: APP_ENTRY_URL,
  protocolAppEntryUrl: PROTOCOL_APP_ENTRY_URL,
  fileAppEntryUrl: FILE_APP_ENTRY_URL,
  enableCustomProtocol: ENABLE_CUSTOM_PROTOCOL,
  disableRendererSandbox: DISABLE_RENDERER_SANDBOX
})

const {
  createWindowSafely,
  ensurePrimaryWindow,
  getPrimaryWindow,
  scheduleStartupWindowWatchdog
} = windowController

windowBridgeController = createWindowBridgeController({
  app,
  focusWindow,
  extractLaunchFilePaths,
  normalizeSupportedCorpusFilePath,
  captureMainError,
  getPrimaryWindow,
  createWindowSafely,
  ensurePrimaryWindow
})

const {
  consumePendingSystemOpenFilePaths,
  dispatchAppMenuAction,
  dispatchSystemNotificationAction,
  handleSystemOpenFilePaths,
  markSystemOpenBridgeReady,
  resetSystemOpenBridgeReady
} = windowBridgeController

function getCorpusStorage() {
  if (!corpusStorage) {
    const CorpusStorageClass = getCorpusStorageClass()
    corpusStorage = new CorpusStorageClass(path.join(app.getPath('userData'), 'corpus-library'))
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
  getExcelJS: getExcelJSModule,
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
  getPackagedSmokeConfig: () => ({
    enabled: IS_PACKAGED_SMOKE_ENV,
    autoRun: IS_PACKAGED_SMOKE_ENV
  }),
  writePackagedSmokeResult: async (payload = {}) => {
    if (!IS_PACKAGED_SMOKE_ENV || !PACKAGED_SMOKE_RESULT_PATH) {
      return {
        success: false,
        message: '当前未启用 packaged smoke 结果回写。'
      }
    }

    const normalizedPayload = {
      timestamp: new Date().toISOString(),
      ...payload
    }

    await fs.mkdir(path.dirname(PACKAGED_SMOKE_RESULT_PATH), { recursive: true })
    await fs.writeFile(PACKAGED_SMOKE_RESULT_PATH, JSON.stringify(normalizedPayload, null, 2), 'utf8')
    appendEarlyCrashLog('packaged-smoke.result', 'packaged smoke result recorded', {
      resultPath: PACKAGED_SMOKE_RESULT_PATH,
      status: normalizedPayload.status || '',
      stage: normalizedPayload.stage || ''
    })
    return {
      success: true,
      resultPath: PACKAGED_SMOKE_RESULT_PATH
    }
  },
  getSmokeObserverState: () => ({
    notifications: [...smokeObserverState.notifications],
    notificationActions: [...smokeObserverState.notificationActions],
    windowAttention: [...smokeObserverState.windowAttention],
    windowProgress: [...smokeObserverState.windowProgress]
  }),
  markSystemOpenBridgeReady,
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
  readCorpusFile: readCorpusFileSafely,
  inspectCorpusFilePreflight: inspectCorpusFilePreflightSafely,
  addRecentDocumentIfSupported,
  getCorpusStorage,
  normalizeFilePathInput,
  normalizeIdentifier,
  normalizeTextInput,
  pathExists,
  showItemInSystemFileManager
})

setupSingleInstanceHandling({
  app,
  disableSingleInstance: DISABLE_SINGLE_INSTANCE,
  appendEarlyCrashLog,
  handleLaunchActionArgs,
  extractLaunchAction,
  dispatchAppMenuAction,
  handleSystemOpenFilePaths,
  ensurePrimaryWindow
})

setupOpenFileHandler({
  app,
  handleSystemOpenFilePaths
})

setupProcessErrorHandling({
  appendEarlyCrashLog,
  captureMainError,
  getDiagnosticsController: () => diagnosticsController
})

setupCommonAppLifecycleHandlers({
  app,
  BrowserWindow,
  appendEarlyCrashLog,
  logMainDiagnostic,
  getWindowAttentionController: () => windowAttentionController,
  getWindowProgressController: () => windowProgressController,
  getAutoUpdateController: () => autoUpdateController,
  ensurePrimaryWindow
})

app.whenReady().then(async () => {
  try {
    ({
      diagnosticsController,
      analysisCacheController,
      windowProgressController,
      windowAttentionController,
      systemNotificationController,
      autoUpdateController
    } = await initializeAppReadyState({
      app,
      BrowserWindow,
      Menu,
      NotificationClass: Notification,
      nativeImage,
      packageManifest,
      fs,
      path,
      processExecPath: process.execPath,
      processPlatform: process.platform,
      processArgv: process.argv,
      appUserModelId: APP_USER_MODEL_ID,
      smokeUserDataDir: SMOKE_USER_DATA_DIR,
      legacyUserDataDirNames: LEGACY_USER_DATA_DIR_NAMES,
      appendEarlyCrashLog,
      logMainDiagnostic,
      captureMainError,
      pushSmokeObserverEvent,
      setupAppProtocol,
      createDiagnosticsController,
      createAnalysisCacheController,
      createWindowProgressController,
      createWindowAttentionController,
      createSystemNotificationController,
      scheduleStartupWindowWatchdog,
      migrateLegacyUserDataDirIfNeeded,
      getCorpusStorage,
      configureSessionSecurity,
      setupApplicationMenu,
      setupPlatformFileIntegration,
      createAutoUpdateController,
      handleLaunchActionArgs,
      extractLaunchAction,
      dispatchAppMenuAction,
      handleSystemOpenFilePaths,
      getPrimaryWindow,
      ensurePrimaryWindow,
      dispatchSystemNotificationAction
    }))
  } catch (error) {
    appendEarlyCrashLog('app.whenReady', error)
    captureMainError('app.whenReady', error)
    void diagnosticsController?.markCrashRecoveryState?.('app.whenReady', error)
    showStartupErrorBox(error, 'app.whenReady')
    ensurePrimaryWindow('app.whenReady-recovery')
  }
})
