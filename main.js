const { app, BrowserWindow, ipcMain, dialog, session, shell, Notification, nativeImage, Menu, protocol } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const os = require('os')
const fsSync = require('fs')
const fs = require('fs/promises')
const ExcelJS = require('exceljs')
const packageManifest = require('./package.json')
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
const INDEX_HTML_PATH = path.join(__dirname, 'index.html')
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
const DISABLE_SINGLE_INSTANCE = normalizeBooleanInput(process.env.CORPUS_LITE_DISABLE_SINGLE_INSTANCE)
const FORCE_SOFTWARE_RENDERING = normalizeBooleanInput(
  process.env.WORDZ_FORCE_SOFTWARE_RENDERING ?? process.env.CORPUS_LITE_FORCE_SOFTWARE_RENDERING
)
const ENABLE_CUSTOM_PROTOCOL = process.platform !== 'win32'
const APP_ENTRY_URL = ENABLE_CUSTOM_PROTOCOL ? PROTOCOL_APP_ENTRY_URL : FILE_APP_ENTRY_URL
const DISABLE_RENDERER_SANDBOX = normalizeBooleanInput(process.env.WORDZ_DISABLE_RENDERER_SANDBOX)
const WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE = Object.freeze([
  'full',
  'renderer-no-style',
  'minimal'
])
const IS_SMOKE_ENV = Boolean(SMOKE_USER_DATA_DIR)
const SMOKE_EVENT_LIMIT = 60
const smokeObserverState = {
  notifications: [],
  notificationActions: [],
  windowAttention: [],
  windowProgress: []
}
const MIME_TYPE_BY_EXTENSION = Object.freeze({
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.bmp': 'image/bmp',
  '.txt': 'text/plain; charset=utf-8',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json; charset=utf-8'
})
let appProtocolReady = false
let appProtocolRequestLogCount = 0
const PROTOCOL_CACHEABLE_EXTENSIONS = new Set([
  '.html',
  '.css',
  '.js',
  '.mjs',
  '.json',
  '.svg',
  '.txt'
])
const PROTOCOL_STARTUP_ASSETS = Object.freeze([
  INDEX_HTML_PATH,
  path.join(__dirname, 'styles.css'),
  path.join(__dirname, 'renderer.js')
])
const protocolAssetCache = new Map()
const MAX_PROTOCOL_CACHE_ENTRIES = 120
const mainWindowLoadStateMap = new WeakMap()

if (ENABLE_CUSTOM_PROTOCOL) {
  try {
    protocol.registerSchemesAsPrivileged([
      {
        scheme: APP_PROTOCOL_SCHEME,
        privileges: {
          standard: true,
          secure: true,
          supportFetchAPI: true,
          corsEnabled: true,
          stream: true
        }
      }
    ])
  } catch (error) {
    appendEarlyCrashLog('protocol.scheme.register-error', error, {
      scheme: APP_PROTOCOL_SCHEME
    })
  }
} else {
  appendEarlyCrashLog('protocol.scheme.disabled', 'custom protocol disabled for this platform', {
    platform: process.platform,
    appEntryUrl: APP_ENTRY_URL
  })
}

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

function normalizePathForTrustComparison(filePath) {
  const normalizedPath = path.normalize(String(filePath || ''))
  return process.platform === 'win32' ? normalizedPath.toLowerCase() : normalizedPath
}

function toFilePathFromUrl(rawUrl) {
  const urlText = String(rawUrl || '').trim()
  if (!urlText) return ''
  try {
    const parsedUrl = new URL(urlText)
    if (parsedUrl.protocol !== 'file:') return ''
    let filePath = decodeURIComponent(parsedUrl.pathname || '')
    if (process.platform === 'win32') {
      filePath = filePath.replace(/^\/([A-Za-z]:)/, '$1')
    }
    return path.normalize(filePath)
  } catch {
    return ''
  }
}

function isPathInsideDirectory(rootPath, targetPath) {
  const normalizedRoot = normalizePathForTrustComparison(path.resolve(String(rootPath || '')))
  const normalizedTarget = normalizePathForTrustComparison(path.resolve(String(targetPath || '')))
  if (!normalizedRoot || !normalizedTarget) return false
  if (normalizedTarget === normalizedRoot) return true
  return normalizedTarget.startsWith(`${normalizedRoot}${path.sep}`)
}

function getMimeTypeForFilePath(filePath) {
  const extension = path.extname(String(filePath || '')).toLowerCase()
  return MIME_TYPE_BY_EXTENSION[extension] || 'application/octet-stream'
}

function appendProtocolRequestLog(scope, requestUrl, targetPath, details = null) {
  if (appProtocolRequestLogCount >= 40) return
  appProtocolRequestLogCount += 1
  appendEarlyCrashLog(scope, 'protocol request', {
    requestUrl: String(requestUrl || ''),
    targetPath: String(targetPath || ''),
    ...(details && typeof details === 'object' ? details : {})
  })
}

function resolveProtocolAssetPath(requestUrl) {
  try {
    const parsedUrl = new URL(String(requestUrl || ''))
    if (parsedUrl.protocol !== `${APP_PROTOCOL_SCHEME}:`) return ''
    if (parsedUrl.hostname !== APP_PROTOCOL_HOST) return ''

    let pathname = parsedUrl.pathname || '/'
    try {
      pathname = decodeURIComponent(pathname)
    } catch {
      pathname = parsedUrl.pathname || '/'
    }

    const normalizedPosixPath = path.posix.normalize(pathname)
    const relativePosixPath = normalizedPosixPath.replace(/^\/+/, '')
    const safeRelativePath = !relativePosixPath || relativePosixPath === '.'
      ? 'index.html'
      : relativePosixPath
    if (safeRelativePath.startsWith('..')) return ''

    const resolvedPath = path.resolve(__dirname, ...safeRelativePath.split('/'))
    if (!isPathInsideDirectory(__dirname, resolvedPath)) return ''
    return resolvedPath
  } catch {
    return ''
  }
}

function isProtocolCacheableAsset(targetPath) {
  const extension = path.extname(String(targetPath || '')).toLowerCase()
  return PROTOCOL_CACHEABLE_EXTENSIONS.has(extension)
}

function trimProtocolAssetCacheIfNeeded() {
  while (protocolAssetCache.size > MAX_PROTOCOL_CACHE_ENTRIES) {
    const oldestCacheKey = protocolAssetCache.keys().next().value
    if (!oldestCacheKey) break
    protocolAssetCache.delete(oldestCacheKey)
  }
}

async function readProtocolAssetContent(targetPath) {
  const normalizedPath = path.resolve(String(targetPath || ''))
  const cachedContent = protocolAssetCache.get(normalizedPath)
  if (cachedContent) {
    protocolAssetCache.delete(normalizedPath)
    protocolAssetCache.set(normalizedPath, cachedContent)
    return cachedContent
  }

  const content = await fs.readFile(normalizedPath)
  if (isProtocolCacheableAsset(normalizedPath)) {
    protocolAssetCache.set(normalizedPath, content)
    trimProtocolAssetCacheIfNeeded()
  }
  return content
}

async function warmupProtocolAssetCache() {
  const warmupResult = {
    total: 0,
    cached: 0
  }
  for (const targetPath of PROTOCOL_STARTUP_ASSETS) {
    warmupResult.total += 1
    try {
      if (!fsSync.existsSync(targetPath)) continue
      await readProtocolAssetContent(targetPath)
      warmupResult.cached += 1
    } catch (error) {
      appendEarlyCrashLog('protocol.cache.warmup.error', error, {
        targetPath
      })
    }
  }
  appendEarlyCrashLog('protocol.cache.warmup.done', 'startup asset cache warmed', warmupResult)
}

function buildProtocolHeaders(targetPath) {
  return {
    'content-type': getMimeTypeForFilePath(targetPath),
    'cache-control': 'no-store',
    'access-control-allow-origin': '*',
    'cross-origin-resource-policy': 'same-origin'
  }
}

function getMainWindowLoadState(win) {
  if (!win) return { isAttemptRunning: false }
  const existingState = mainWindowLoadStateMap.get(win)
  if (existingState) return existingState
  const nextState = {
    isAttemptRunning: false,
    hasSuccessfulMainLoad: false,
    lastSuccessfulUrl: ''
  }
  mainWindowLoadStateMap.set(win, nextState)
  return nextState
}

function setMainWindowLoadAttemptRunning(win, isAttemptRunning) {
  const state = getMainWindowLoadState(win)
  state.isAttemptRunning = Boolean(isAttemptRunning)
}

function isMainWindowLoadAttemptRunning(win) {
  return Boolean(getMainWindowLoadState(win).isAttemptRunning)
}

function markMainWindowLoadSuccess(win, loadedUrl = '') {
  const state = getMainWindowLoadState(win)
  state.hasSuccessfulMainLoad = true
  state.lastSuccessfulUrl = String(loadedUrl || '').trim()
}

function hasMainWindowSuccessfulLoad(win) {
  return Boolean(getMainWindowLoadState(win).hasSuccessfulMainLoad)
}

function delay(ms) {
  return new Promise(resolve => {
    const timer = setTimeout(resolve, Math.max(0, Number(ms) || 0))
    if (typeof timer.unref === 'function') {
      timer.unref()
    }
  })
}

function isKnownNonFatalWindowsLoadFailure(error) {
  if (process.platform !== 'win32') return false
  const message = String(error?.message || error || '')
  return message.includes('ERR_FAILED (-2)')
}

function getWindowCurrentUrl(win) {
  try {
    return String(win?.webContents?.getURL?.() || '').trim()
  } catch {
    return ''
  }
}

async function canTreatAttemptErrorAsSoftSuccess(win, attemptError) {
  if (!win || win.isDestroyed?.()) return false
  if (!isKnownNonFatalWindowsLoadFailure(attemptError)) return false

  const immediateUrl = getWindowCurrentUrl(win)
  if (isTrustedAppEntryUrl(immediateUrl)) return true

  await delay(120)
  const delayedUrl = getWindowCurrentUrl(win)
  return isTrustedAppEntryUrl(delayedUrl)
}

async function setupAppProtocol() {
  if (appProtocolReady) return true

  if (!ENABLE_CUSTOM_PROTOCOL) {
    appendEarlyCrashLog('protocol.setup.skipped', 'custom app protocol is disabled', {
      platform: process.platform,
      appEntryUrl: APP_ENTRY_URL
    })
    return true
  }

  try {
    if (typeof protocol.unregisterProtocol === 'function') {
      try {
        await new Promise(resolve => {
          protocol.unregisterProtocol(APP_PROTOCOL_SCHEME, () => resolve())
        })
      } catch {
        // ignore stale handler cleanup errors
      }
    } else if (typeof protocol.unhandle === 'function') {
      try {
        protocol.unhandle(APP_PROTOCOL_SCHEME)
      } catch {
        // ignore stale handler cleanup errors
      }
    }

    if (typeof protocol.handle !== 'function') {
      appendEarlyCrashLog('protocol.handle.unavailable', 'protocol.handle is not available', {
        scheme: APP_PROTOCOL_SCHEME
      })
      return false
    }
    if (typeof globalThis.Response !== 'function') {
      appendEarlyCrashLog('protocol.response.unavailable', 'global Response API is unavailable', {
        scheme: APP_PROTOCOL_SCHEME
      })
      return false
    }

    protocol.handle(APP_PROTOCOL_SCHEME, async request => {
      const requestUrl = String(request?.url || '')
      const targetPath = resolveProtocolAssetPath(requestUrl)
      appendProtocolRequestLog('protocol.handle.request', requestUrl, targetPath)
      if (!targetPath) {
        return new Response('Forbidden', {
          status: 403,
          headers: { 'content-type': 'text/plain; charset=utf-8' }
        })
      }

      try {
        const content = await readProtocolAssetContent(targetPath)
        return new Response(content, {
          status: 200,
          headers: buildProtocolHeaders(targetPath)
        })
      } catch (error) {
        appendEarlyCrashLog('protocol.request.error', error, {
          requestUrl,
          targetPath
        })
        return new Response('Not Found', {
          status: 404,
          headers: { 'content-type': 'text/plain; charset=utf-8' }
        })
      }
    })
    await warmupProtocolAssetCache()

    appProtocolReady = true
    appendEarlyCrashLog('protocol.handle.ready', 'app protocol registered', {
      scheme: APP_PROTOCOL_SCHEME,
      host: APP_PROTOCOL_HOST,
      appEntryUrl: APP_ENTRY_URL
    })
    return true
  } catch (error) {
    appendEarlyCrashLog('protocol.setup.error', error, {
      scheme: APP_PROTOCOL_SCHEME,
      host: APP_PROTOCOL_HOST
    })
    return false
  }
}

function isTrustedAppEntryUrl(rawUrl) {
  const urlText = String(rawUrl || '').trim()
  if (!urlText) return false
  if (urlText === APP_ENTRY_URL) return true
  if (ENABLE_CUSTOM_PROTOCOL && urlText === PROTOCOL_APP_ENTRY_URL) return true
  try {
    const parsedUrl = new URL(urlText)
    if (
      ENABLE_CUSTOM_PROTOCOL &&
      parsedUrl.protocol === `${APP_PROTOCOL_SCHEME}:` &&
      parsedUrl.hostname === APP_PROTOCOL_HOST
    ) {
      return true
    }
  } catch {
    // ignore parse failures and continue to file-path trust checks
  }
  if (urlText === FILE_APP_ENTRY_URL) return true
  const filePath = toFilePathFromUrl(urlText)
  if (!filePath) return false
  return normalizePathForTrustComparison(filePath) === normalizePathForTrustComparison(INDEX_HTML_PATH)
}

function isTrustedNavigationTarget(targetUrl) {
  const normalizedTarget = String(targetUrl || '').trim()
  if (!normalizedTarget) return false
  if (normalizedTarget.startsWith(TRUSTED_DATA_URL_PREFIX)) return true
  return isTrustedAppEntryUrl(normalizedTarget)
}

function normalizeWindowsRenderDiagnosticMode(mode) {
  const normalizedMode = String(mode || '').trim().toLowerCase()
  if (WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE.includes(normalizedMode)) {
    return normalizedMode
  }
  return 'full'
}

function buildWindowsDiagnosticEntryUrl(mode) {
  const normalizedMode = normalizeWindowsRenderDiagnosticMode(mode)
  const entryUrl = new URL(FILE_APP_ENTRY_URL)
  if (normalizedMode === 'full') {
    entryUrl.searchParams.delete('diag')
  } else {
    entryUrl.searchParams.set('diag', normalizedMode)
  }
  return entryUrl.toString()
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
      const createdWindow = createWindowSafely('system-notification-action')
      if (createdWindow && !createdWindow.isDestroyed?.()) {
        createdWindow.webContents.once('did-finish-load', () => {
          flushPendingSystemNotificationActions(createdWindow)
        })
      }
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
      ensurePrimaryWindow('system-open-file-path')
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
    ensurePrimaryWindow('system-open-empty')
    return
  }

  let hasDispatched = false
  for (const filePath of normalizedPaths) {
    if (dispatchSystemOpenFilePath(filePath)) {
      hasDispatched = true
    }
  }

  if (!hasDispatched && app.isReady() && !getPrimaryWindow()) {
    ensurePrimaryWindow('system-open-paths-undispatched')
  }
}

if (!DISABLE_SINGLE_INSTANCE) {
  const hasSingleInstanceLock = app.requestSingleInstanceLock()
  appendEarlyCrashLog('single-instance.lock', hasSingleInstanceLock ? 'acquired' : 'failed', {
    pid: process.pid,
    disableSingleInstance: false
  })
  if (!hasSingleInstanceLock) {
    appendEarlyCrashLog('single-instance.quit', 'lock not acquired, quitting current instance', {
      pid: process.pid
    })
    app.quit()
  } else {
    app.on('second-instance', (_event, argv) => {
      appendEarlyCrashLog('single-instance.second-instance', 'received', {
        pid: process.pid,
        argvCount: Array.isArray(argv) ? argv.length : 0
      })
      handleLaunchActionArgs(argv)
      handleSystemOpenFilePaths(argv)
      ensurePrimaryWindow('second-instance')
    })
  }
} else {
  appendEarlyCrashLog('single-instance.disabled', 'single-instance lock disabled by env', {
    pid: process.pid,
    disableSingleInstance: true
  })
}

app.on('open-file', (event, filePath) => {
  event.preventDefault()
  handleSystemOpenFilePaths([filePath])
})

function isTrustedIpcSender(event) {
  const senderUrl = event?.senderFrame?.url || event?.sender?.getURL?.() || ''
  return isTrustedAppEntryUrl(senderUrl)
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
    if (!isTrustedNavigationTarget(targetUrl)) {
      event.preventDefault()
    }
  })

  webContents.on('will-attach-webview', event => {
    event.preventDefault()
  })
}

function buildWindowLoadErrorHtml(error) {
  const detail = String(error?.message || error || 'Unknown error').slice(0, 4000)
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>WordZ</title>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", Arial, sans-serif; background: #f4efe7; color: #182131; }
    .wrap { max-width: 760px; margin: 10vh auto 0; padding: 24px; }
    .card { background: #fffaf3; border: 1px solid rgba(88, 75, 55, 0.18); border-radius: 16px; box-shadow: 0 18px 44px rgba(20, 24, 38, 0.1); padding: 20px; }
    h1 { margin: 0 0 10px; font-size: 22px; }
    p { margin: 0 0 8px; line-height: 1.7; }
    pre { margin: 12px 0 0; background: #f2ebe1; border-radius: 12px; padding: 12px; white-space: pre-wrap; word-break: break-word; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>WordZ 启动失败</h1>
      <p>主界面加载失败，请重启应用后重试。</p>
      <p>如果问题持续，请在“帮助中心/反馈”中导出诊断并提交 Issue。</p>
      <pre>${detail}</pre>
    </div>
  </div>
</body>
</html>`
}

async function loadRendererCrashFallback(win, error, details = null) {
  if (!win || win.isDestroyed?.()) return false
  const detailLines = [
    String(error?.message || error || '渲染进程发生异常'),
    details?.reason ? `reason=${details.reason}` : '',
    Number.isFinite(Number(details?.exitCode)) ? `exitCode=${details.exitCode}` : ''
  ].filter(Boolean)
  const fallbackError = new Error(detailLines.join(' | '))
  try {
    await win.loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(fallbackError))}`)
    if (!win.isVisible()) win.show()
    return true
  } catch (fallbackErrorInner) {
    captureMainError('window.render-crash-fallback', fallbackErrorInner, details || null)
    return false
  }
}

async function loadMainWindow(win, { reason = 'initial-load', error = null, startupMode = 'full' } = {}) {
  const normalizedStartupMode = process.platform === 'win32'
    ? normalizeWindowsRenderDiagnosticMode(startupMode)
    : 'full'
  const windowsModeEntryUrl = process.platform === 'win32'
    ? buildWindowsDiagnosticEntryUrl(normalizedStartupMode)
    : ''
  const effectiveEntryUrl = process.platform === 'win32' ? windowsModeEntryUrl : APP_ENTRY_URL

  const protocolLoadAttempt = {
    id: 'protocol-url',
    value: PROTOCOL_APP_ENTRY_URL,
    load: () => win.loadURL(PROTOCOL_APP_ENTRY_URL)
  }
  const fileLoadAttempt = {
    id: 'index-load-file',
    value: INDEX_HTML_PATH,
    load: () => win.loadFile(INDEX_HTML_PATH)
  }
  const fileUrlLoadAttempt = {
    id: 'index-file-url',
    value: FILE_APP_ENTRY_URL,
    load: () => win.loadURL(FILE_APP_ENTRY_URL)
  }
  const windowsDiagnosticLoadAttempt = {
    id: `win-entry-url-${normalizedStartupMode}`,
    value: windowsModeEntryUrl,
    load: () => win.loadURL(windowsModeEntryUrl)
  }
  const loadAttempts = process.platform === 'win32'
    ? (
        normalizedStartupMode === 'full'
          ? [
              windowsDiagnosticLoadAttempt,
              fileUrlLoadAttempt,
              fileLoadAttempt,
              ...(ENABLE_CUSTOM_PROTOCOL ? [protocolLoadAttempt] : [])
            ]
          : [windowsDiagnosticLoadAttempt]
      )
    : [
        ...(ENABLE_CUSTOM_PROTOCOL ? [protocolLoadAttempt] : []),
        fileLoadAttempt,
        fileUrlLoadAttempt
      ]
  const attemptedUrls = []
  let lastError = null

  setMainWindowLoadAttemptRunning(win, true)
  try {
    for (const attempt of loadAttempts) {
      attemptedUrls.push(`${attempt.id}:${attempt.value}`)
      try {
        await attempt.load()
        appendEarlyCrashLog('window.load-file.success', 'main window loaded', {
          reason,
          indexPath: INDEX_HTML_PATH,
          appEntryUrl: effectiveEntryUrl,
          startupMode: normalizedStartupMode,
          loadMode: attempt.id,
          attemptedUrls
        })
        markMainWindowLoadSuccess(win, String(win.webContents.getURL?.() || attempt.value))
        return true
      } catch (attemptError) {
        const normalizedAttemptError = attemptError instanceof Error
          ? attemptError
          : new Error(String(attemptError))
        const currentUrl = getWindowCurrentUrl(win)
        const softRecovered = await canTreatAttemptErrorAsSoftSuccess(win, normalizedAttemptError)
        if (softRecovered) {
          const recoveredUrl = getWindowCurrentUrl(win) || currentUrl || attempt.value
          appendEarlyCrashLog('window.load-file.attempt-soft-success', 'ignored non-fatal load promise rejection', {
            reason,
            indexPath: INDEX_HTML_PATH,
            appEntryUrl: effectiveEntryUrl,
            startupMode: normalizedStartupMode,
            loadMode: attempt.id,
            attemptedUrls,
            currentUrl,
            recoveredUrl,
            originalError: normalizedAttemptError.message
          })
          markMainWindowLoadSuccess(win, recoveredUrl)
          return true
        }
        lastError = normalizedAttemptError
        appendEarlyCrashLog('window.load-file.attempt-error', normalizedAttemptError, {
          reason,
          indexPath: INDEX_HTML_PATH,
          appEntryUrl: effectiveEntryUrl,
          startupMode: normalizedStartupMode,
          loadMode: attempt.id,
          attemptedUrls,
          currentUrl
        })
      }
    }

    const normalizedError = lastError || new Error('主页面加载失败（未知错误）')
    appendEarlyCrashLog('window.load-file.error', normalizedError, {
      reason,
      indexPath: INDEX_HTML_PATH,
      appEntryUrl: effectiveEntryUrl,
      startupMode: normalizedStartupMode,
      attemptedUrls
    })
    captureMainError('window.load-file', normalizedError, {
      reason,
      indexPath: INDEX_HTML_PATH,
      attemptedUrls
    })
    void diagnosticsController?.markCrashRecoveryState?.('window.load-file', normalizedError, {
      reason,
      indexPath: INDEX_HTML_PATH,
      attemptedUrls
    })

    const fallbackSourceError = error instanceof Error ? error : normalizedError
    try {
      await win.loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(fallbackSourceError))}`)
    } catch (fallbackError) {
      captureMainError('window.load-fallback', fallbackError, { reason })
    }
    return false
  } finally {
    setMainWindowLoadAttemptRunning(win, false)
  }
}

function createWindow() {
  systemOpenBridgeReady = false
  let renderCrashCount = 0
  const isWindowsRenderDiagnosticEnabled = process.platform === 'win32'
  let windowsRenderDiagnosticModeIndex = 0
  let currentWindowStartupMode = isWindowsRenderDiagnosticEnabled
    ? WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE[0]
    : 'full'
  appendEarlyCrashLog('window.create.begin', 'creating browser window', {
    pid: process.pid,
    indexPath: INDEX_HTML_PATH,
    preloadPath: PRELOAD_SCRIPT_PATH,
    appEntryUrl: APP_ENTRY_URL,
    startupMode: currentWindowStartupMode,
    rendererSandboxDisabled: DISABLE_RENDERER_SANDBOX,
    indexExists: fsSync.existsSync(INDEX_HTML_PATH),
    preloadExists: fsSync.existsSync(PRELOAD_SCRIPT_PATH)
  })
  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1100,
    minHeight: 760,
    show: true,
    backgroundColor: '#f4efe7',
    webPreferences: {
      preload: PRELOAD_SCRIPT_PATH,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: !DISABLE_RENDERER_SANDBOX,
      webSecurity: true,
      allowRunningInsecureContent: false
    }
  })

  hardenWindow(win)
  win.once('ready-to-show', () => {
    appendEarlyCrashLog('window.ready-to-show', 'window ready to show', {
      pid: process.pid
    })
  })
  win.on('show', () => {
    appendEarlyCrashLog('window.show', 'window shown', {
      pid: process.pid
    })
  })
  win.on('closed', () => {
    appendEarlyCrashLog('window.closed', 'window closed', {
      pid: process.pid,
      remainingWindows: BrowserWindow.getAllWindows().length
    })
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
    const renderGoneDetails = {
      ...(details && typeof details === 'object' ? details : {}),
      startupMode: currentWindowStartupMode,
      nextCrashCount: renderCrashCount + 1
    }
    appendEarlyCrashLog('window.render-process-gone', error, renderGoneDetails)
    captureMainError('window.render-process-gone', error, renderGoneDetails)
    void diagnosticsController?.markCrashRecoveryState?.('window.render-process-gone', error, renderGoneDetails)
    if (details?.reason === 'clean-exit') return
    renderCrashCount += 1
    if (
      isWindowsRenderDiagnosticEnabled &&
      windowsRenderDiagnosticModeIndex < WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE.length - 1
    ) {
      windowsRenderDiagnosticModeIndex += 1
      currentWindowStartupMode = WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE[windowsRenderDiagnosticModeIndex]
      appendEarlyCrashLog('window.render-probe.next-mode', 'switching windows render diagnostic mode', {
        reason: details?.reason || '',
        exitCode: Number(details?.exitCode),
        renderCrashCount,
        startupMode: currentWindowStartupMode,
        startupModeIndex: windowsRenderDiagnosticModeIndex
      })
      void loadMainWindow(win, {
        reason: 'render-process-gone',
        error,
        startupMode: currentWindowStartupMode
      })
      return
    }
    if (!isWindowsRenderDiagnosticEnabled && renderCrashCount === 1) {
      void loadMainWindow(win, {
        reason: 'render-process-gone',
        error,
        startupMode: currentWindowStartupMode
      })
      return
    }
    void loadRendererCrashFallback(win, error, details)
  })
  win.webContents.on('preload-error', (_event, preloadPath, preloadError) => {
    const error = preloadError instanceof Error ? preloadError : new Error(String(preloadError || 'Unknown preload error'))
    appendEarlyCrashLog('window.preload-error', error, {
      preloadPath
    })
    captureMainError('window.preload-error', error, {
      preloadPath
    })
  })
  win.webContents.on('dom-ready', () => {
    appendEarlyCrashLog('window.dom-ready', 'renderer dom-ready', {
      pid: process.pid
    })
  })
  win.webContents.on('did-start-loading', () => {
    appendEarlyCrashLog('window.did-start-loading', 'renderer started loading', {
      pid: process.pid,
      url: win.webContents.getURL()
    })
  })
  win.webContents.on('did-stop-loading', () => {
    appendEarlyCrashLog('window.did-stop-loading', 'renderer stopped loading', {
      pid: process.pid,
      url: win.webContents.getURL()
    })
  })
  let consoleErrorLogCount = 0
  win.webContents.on('console-message', (_event, level, message, line, sourceId) => {
    const normalizedMessage = String(message || '')
    const shouldCaptureStartupDebugMessage =
      normalizedMessage.includes('[startup.') ||
      normalizedMessage.includes('[renderer.startup')
    if (level < 2 && !shouldCaptureStartupDebugMessage) return
    if (consoleErrorLogCount >= 30) return
    consoleErrorLogCount += 1
    appendEarlyCrashLog('window.console-message', normalizedMessage, {
      level,
      line,
      sourceId: String(sourceId || ''),
      url: win.webContents.getURL()
    })
  })
  win.webContents.on('did-fail-load', (_event, errorCode, errorDescription, validatedURL, isMainFrame) => {
    if (!isMainFrame) return
    if (errorCode === -3) {
      appendEarlyCrashLog('window.did-fail-load.ignored', 'ignored non-fatal ERR_ABORTED', {
        errorCode,
        errorDescription,
        validatedURL,
        currentUrl: win.webContents.getURL()
      })
      return
    }
    const error = new Error(`主页面加载失败(${errorCode})：${errorDescription || 'unknown'}`)
    appendEarlyCrashLog('window.did-fail-load', error, {
      errorCode,
      errorDescription,
      validatedURL
    })
    captureMainError('window.did-fail-load', error, {
      errorCode,
      errorDescription,
      validatedURL
    })
    void diagnosticsController?.markCrashRecoveryState?.('window.did-fail-load', error, {
      errorCode,
      errorDescription,
      validatedURL
    })
    if (isMainWindowLoadAttemptRunning(win)) {
      appendEarlyCrashLog('window.did-fail-load.defer-fallback', 'defer fallback because load attempts are still running', {
        errorCode,
        errorDescription,
        validatedURL
      })
      return
    }
    const currentUrl = String(win.webContents.getURL() || '').trim()
    const normalizedValidatedUrl = String(validatedURL || '').trim()
    const mainLoadState = getMainWindowLoadState(win)
    if (hasMainWindowSuccessfulLoad(win)) {
      const lastSuccessfulUrl = String(mainLoadState.lastSuccessfulUrl || '').trim()
      const isCurrentTrustedMainUrl = isTrustedAppEntryUrl(currentUrl)
      const isStaleValidatedUrl = Boolean(
        normalizedValidatedUrl &&
        normalizedValidatedUrl !== currentUrl &&
        normalizedValidatedUrl !== lastSuccessfulUrl
      )
      if (isCurrentTrustedMainUrl || isStaleValidatedUrl) {
        appendEarlyCrashLog('window.did-fail-load.ignored', 'ignored stale did-fail-load after successful main load', {
          errorCode,
          errorDescription,
          validatedURL: normalizedValidatedUrl,
          currentUrl,
          lastSuccessfulUrl
        })
        return
      }
    }
    if (!win.isDestroyed()) {
      if (!win.isVisible()) win.show()
      void win
        .loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(error))}`)
        .catch(fallbackError => {
          captureMainError('window.load-fallback', fallbackError, {
            reason: 'did-fail-load'
          })
        })
    }
  })
  void loadMainWindow(win, {
    startupMode: currentWindowStartupMode
  })
  win.webContents.on('did-finish-load', () => {
    const loadedUrl = String(win.webContents.getURL() || '')
    if (isTrustedAppEntryUrl(loadedUrl)) {
      markMainWindowLoadSuccess(win, loadedUrl)
    }
    appendEarlyCrashLog('window.did-finish-load', 'renderer finished load', {
      pid: process.pid,
      url: loadedUrl,
      startupMode: currentWindowStartupMode
    })
    autoUpdateController?.broadcastStatus?.()
    logMainDiagnostic('info', 'window', '主窗口已完成加载。')
  })
  return win
}

function createWindowSafely(reason = 'unknown', details = null) {
  try {
    return createWindow()
  } catch (error) {
    appendEarlyCrashLog('window.create', error, {
      reason,
      details
    })
    captureMainError('window.create', error, {
      reason,
      details
    })
    void diagnosticsController?.markCrashRecoveryState?.('window.create', error, {
      reason,
      details
    })
    showStartupErrorBox(error, `window.create:${reason}`)
    return null
  }
}

function ensurePrimaryWindow(reason = 'ensure-primary-window') {
  const primaryWindow = getPrimaryWindow()
  if (primaryWindow && !primaryWindow.isDestroyed?.()) {
    focusWindow(primaryWindow)
    return primaryWindow
  }
  if (!app.isReady()) return null
  const createdWindow = createWindowSafely(reason)
  if (createdWindow && !createdWindow.isDestroyed?.()) {
    focusWindow(createdWindow)
  }
  return createdWindow
}

function scheduleStartupWindowWatchdog(timeoutMs = 6000) {
  const timer = setTimeout(() => {
    if (!app.isReady()) return
    if (BrowserWindow.getAllWindows().length > 0) return
    appendEarlyCrashLog('startup.watchdog', 'No primary window detected after startup timeout.', {
      timeoutMs
    })
    ensurePrimaryWindow('startup-watchdog')
  }, timeoutMs)
  if (typeof timer.unref === 'function') {
    timer.unref()
  }
}

function dispatchAppMenuAction(action) {
  const normalizedAction = String(action || '').trim()
  if (!normalizedAction) return

  const primaryWindow = getPrimaryWindow()
  if (!primaryWindow) {
    queueAppMenuAction(normalizedAction)
    if (!app.isReady()) return
    const createdWindow = createWindowSafely('app-menu-action')
    if (createdWindow && !createdWindow.isDestroyed?.()) {
      createdWindow.webContents.once('did-finish-load', () => {
        flushPendingAppMenuActions(createdWindow)
      })
    }
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

process.on('uncaughtException', error => {
  appendEarlyCrashLog('uncaughtException', error)
  captureMainError('main.uncaughtException', error)
  void diagnosticsController?.markCrashRecoveryState?.('main.uncaughtException', error)
  console.error('[uncaughtException]', error)
})

process.on('unhandledRejection', reason => {
  const normalizedError = reason instanceof Error ? reason : new Error(String(reason))
  appendEarlyCrashLog('unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  captureMainError('main.unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  void diagnosticsController?.markCrashRecoveryState?.('main.unhandledRejection', normalizedError, {
    reason: reason instanceof Error ? undefined : String(reason)
  })
  console.error('[unhandledRejection]', reason)
})

app.whenReady().then(async () => {
  try {
    appendEarlyCrashLog('app.whenReady.start', 'app ready sequence started', {
      pid: process.pid
    })
    await setupAppProtocol()
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
    scheduleStartupWindowWatchdog()

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
      ensurePrimaryWindow('app.whenReady.init')
    }
    autoUpdateController.initialize()
    logMainDiagnostic('info', 'app', '主窗口与自动更新已初始化。')
    appendEarlyCrashLog('app.whenReady.done', 'app ready sequence completed', {
      pid: process.pid,
      windowCount: BrowserWindow.getAllWindows().length
    })

    app.on('activate', () => {
      appendEarlyCrashLog('app.activate', 'app activate event', {
        pid: process.pid,
        windowCount: BrowserWindow.getAllWindows().length
      })
      if (BrowserWindow.getAllWindows().length === 0) {
        ensurePrimaryWindow('app.activate')
      }
    })
  } catch (error) {
    appendEarlyCrashLog('app.whenReady', error)
    captureMainError('app.whenReady', error)
    void diagnosticsController?.markCrashRecoveryState?.('app.whenReady', error)
    showStartupErrorBox(error, 'app.whenReady')
    ensurePrimaryWindow('app.whenReady-recovery')
  }
})

app.on('window-all-closed', () => {
  appendEarlyCrashLog('app.window-all-closed', 'all windows closed', {
    pid: process.pid,
    platform: process.platform
  })
  if (process.platform !== 'darwin') {
    appendEarlyCrashLog('app.quit.request', 'quit requested from window-all-closed', {
      pid: process.pid
    })
    app.quit()
  }
})

app.on('before-quit', () => {
  appendEarlyCrashLog('app.before-quit', 'before-quit received', {
    pid: process.pid
  })
  logMainDiagnostic('info', 'app', '应用即将退出。')
  windowAttentionController?.clearAll?.()
  windowProgressController?.clearAll?.()
  autoUpdateController?.dispose?.()
})

app.on('will-quit', () => {
  appendEarlyCrashLog('app.will-quit', 'will-quit received', {
    pid: process.pid
  })
})

app.on('quit', (_event, exitCode) => {
  appendEarlyCrashLog('app.quit', 'quit received', {
    pid: process.pid,
    exitCode
  })
})
