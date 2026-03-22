const { app, BrowserWindow, ipcMain, dialog, session, shell, Notification, nativeImage, Menu, protocol } = require('electron')
const path = require('path')
const { pathToFileURL } = require('url')
const os = require('os')
const fsSync = require('fs')
const fs = require('fs/promises')
const packageManifest = require('./package.json')
const { createAutoUpdateController } = require('./autoUpdate')
const { createDiagnosticsController } = require('./diagnostics')
const { setupCustomAppProtocol } = require('./main/helpers/appProtocol')
const { getAppInfo } = require('./main/helpers/appInfo')
const { getPlatformShellPaths } = require('./main/helpers/platformShell')
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
const {
  attachMainWindowLifecycleHandlers,
  createMainBrowserWindow
} = require('./main/helpers/windowLifecycle')
const {
  createWindowsCompatController,
  normalizeWindowsCompatProfile
} = require('./main/helpers/windowsCompat')
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
let windowsCompatController = null
const {
  rendererShellSourcePath: RENDERER_SHELL_SOURCE_PATH,
  windowsIndexHtmlPath: WINDOWS_INDEX_HTML_PATH,
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
const WINDOWS_COMPAT_ACTION_BASE_URL = 'https://wordz.invalid/windows-compat'
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
const ENV_WINDOWS_COMPAT_PROFILE = String(process.env.WORDZ_WINDOWS_COMPAT_PROFILE || '').trim()
const WINDOWS_COMPAT_PROFILE_ARG_PREFIX = '--wordz-windows-compat-profile='
const WINDOWS_COMPAT_PROFILE_PERSIST_ARG_PREFIX = '--wordz-windows-compat-profile-persist='
const ENABLE_CUSTOM_PROTOCOL = process.platform !== 'win32'
const APP_ENTRY_URL = ENABLE_CUSTOM_PROTOCOL ? PROTOCOL_APP_ENTRY_URL : FILE_APP_ENTRY_URL
const DISABLE_RENDERER_SANDBOX = normalizeBooleanInput(process.env.WORDZ_DISABLE_RENDERER_SANDBOX)
const WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE = Object.freeze(['full', 'renderer-no-style', 'minimal'])
const WINDOWS_RENDER_DIAGNOSTIC_MODE_SET = new Set([
  ...WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE,
  'styles'
])
const WINDOWS_COMPAT_ACTION_QUERY_KEY = 'wordzCompatAction'
const IS_SMOKE_ENV = Boolean(SMOKE_USER_DATA_DIR)
const IS_PACKAGED_SMOKE_ENV = IS_SMOKE_ENV && PACKAGED_SMOKE_AUTORUN && Boolean(PACKAGED_SMOKE_RESULT_PATH)
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
const protocolAssetCache = new Map()
const MAX_PROTOCOL_CACHE_ENTRIES = 120
const mainWindowLoadStateMap = new WeakMap()
const windowsCompatWindowStateMap = new WeakMap()

function getWindowsCompatWindowState(win) {
  if (!win) return null
  return windowsCompatWindowStateMap.get(win) || null
}

function setWindowsCompatWindowState(win, nextState = {}) {
  if (!win) return null
  const previousState = getWindowsCompatWindowState(win) || {}
  const mergedState = {
    ...previousState,
    ...(nextState && typeof nextState === 'object' ? nextState : {})
  }
  windowsCompatWindowStateMap.set(win, mergedState)
  return mergedState
}

function readWindowsCompatProfileArg(argv = process.argv) {
  if (!Array.isArray(argv)) return ''
  const match = argv.find(arg => String(arg || '').startsWith(WINDOWS_COMPAT_PROFILE_ARG_PREFIX))
  if (!match) return ''
  return String(match.slice(WINDOWS_COMPAT_PROFILE_ARG_PREFIX.length) || '').trim()
}

function readWindowsCompatProfilePersistArg(argv = process.argv) {
  if (!Array.isArray(argv)) return false
  const match = argv.find(arg => String(arg || '').startsWith(WINDOWS_COMPAT_PROFILE_PERSIST_ARG_PREFIX))
  if (!match) return false
  return normalizeBooleanInput(match.slice(WINDOWS_COMPAT_PROFILE_PERSIST_ARG_PREFIX.length))
}

if (SMOKE_USER_DATA_DIR) {
  app.setPath('userData', SMOKE_USER_DATA_DIR)
  app.setPath('sessionData', path.join(SMOKE_USER_DATA_DIR, 'session-data'))
}

windowsCompatController = createWindowsCompatController({
  app,
  fs,
  fsSync,
  path,
  logger: console,
  appendEarlyCrashLog,
  disableRendererSandboxEnv: DISABLE_RENDERER_SANDBOX,
  envProfile: ENV_WINDOWS_COMPAT_PROFILE,
  launchArgProfile: readWindowsCompatProfileArg(process.argv),
  launchArgPersistEligible: readWindowsCompatProfilePersistArg(process.argv)
})

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

const initialWindowsCompatState = windowsCompatController?.getSnapshot?.() || null
const WINDOWS_COMPAT_BOOT_PROFILE = normalizeWindowsCompatProfile(initialWindowsCompatState?.compatProfile || 'standard')
const WINDOWS_COMPAT_BOOT_RCI_DISABLED = Boolean(initialWindowsCompatState?.rendererCodeIntegrityDisabled)
if (initialWindowsCompatState?.supported) {
  appendEarlyCrashLog('windows.compat.profile', 'windows compatibility profile resolved', {
    compatProfile: initialWindowsCompatState.compatProfile,
    compatProfileSource: initialWindowsCompatState.compatProfileSource,
    stateFilePath: initialWindowsCompatState.stateFilePath,
    rendererSandboxDisabled: initialWindowsCompatState.rendererSandboxDisabled,
    rendererCodeIntegrityDisabled: initialWindowsCompatState.rendererCodeIntegrityDisabled,
    useSafeFallback: initialWindowsCompatState.useSafeFallback
  })
}

if (process.platform === 'win32' || FORCE_SOFTWARE_RENDERING) {
  // Prioritize startup stability on Windows: avoid GPU/driver related white-screen issues.
  app.disableHardwareAcceleration()
  app.commandLine.appendSwitch('disable-gpu')
}

if (initialWindowsCompatState?.supported && initialWindowsCompatState.rendererCodeIntegrityDisabled) {
  app.commandLine.appendSwitch('disable-features', 'RendererCodeIntegrity')
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
let rendererShellMarkupCache = null

function extractRendererShellMarkup(htmlText = '') {
  const normalizedHtmlText = String(htmlText || '')
  if (!normalizedHtmlText) {
    throw new Error('主界面模板为空')
  }

  const bodyStartIndex = normalizedHtmlText.indexOf('<body>')
  if (bodyStartIndex < 0) {
    throw new Error('主界面模板缺少 <body> 标记')
  }

  const scriptTagIndex = normalizedHtmlText.lastIndexOf('<script src="./renderer.js"></script>')
  const bodyEndIndex = scriptTagIndex >= 0
    ? scriptTagIndex
    : normalizedHtmlText.lastIndexOf('</body>')
  if (bodyEndIndex <= bodyStartIndex) {
    throw new Error('主界面模板提取失败：未找到正文结束位置')
  }

  const markup = normalizedHtmlText
    .slice(bodyStartIndex + '<body>'.length, bodyEndIndex)
    .trim()
  if (!markup) {
    throw new Error('主界面模板正文为空')
  }
  return markup
}

async function getRendererShellMarkup() {
  if (rendererShellMarkupCache) return rendererShellMarkupCache
  const htmlText = await fs.readFile(RENDERER_SHELL_SOURCE_PATH, 'utf8')
  rendererShellMarkupCache = extractRendererShellMarkup(htmlText)
  return rendererShellMarkupCache
}
const {
  showOpenDialog: showOpenDialogForApp,
  showSaveDialog: showSaveDialogForApp
} = createDialogController({
  dialog,
  openQueue: SMOKE_OPEN_DIALOG_QUEUE,
  saveQueue: SMOKE_SAVE_DIALOG_QUEUE
})

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
  return setupCustomAppProtocol({
    getIsReady: () => appProtocolReady,
    setIsReady: nextValue => {
      appProtocolReady = Boolean(nextValue)
    },
    enableCustomProtocol: ENABLE_CUSTOM_PROTOCOL,
    protocol,
    responseCtor: globalThis.Response,
    scheme: APP_PROTOCOL_SCHEME,
    host: APP_PROTOCOL_HOST,
    appEntryUrl: APP_ENTRY_URL,
    appendEarlyCrashLog,
    resolveProtocolAssetPath,
    appendProtocolRequestLog,
    readProtocolAssetContent,
    buildProtocolHeaders,
    warmupProtocolAssetCache
  })
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

function parseWindowsCompatAction(targetUrl) {
  const normalizedTarget = String(targetUrl || '').trim()
  if (!normalizedTarget) return ''
  try {
    const parsedUrl = new URL(normalizedTarget)
    const compatAction = String(parsedUrl.searchParams.get(WINDOWS_COMPAT_ACTION_QUERY_KEY) || '').trim().toLowerCase()
    if (
      compatAction === 'retry-current' ||
      compatAction === 'try-standard' ||
      compatAction === 'reset' ||
      compatAction === 'probe-preload-data' ||
      compatAction === 'probe-styles-with-preload' ||
      compatAction === 'probe-full-safe-style' ||
      compatAction === 'probe-full-delay-renderer' ||
      compatAction === 'probe-full-no-startup' ||
      compatAction === 'probe-full-sync-only' ||
      compatAction === 'probe-minimal-with-preload' ||
      compatAction === 'probe-renderer-with-preload' ||
      compatAction === 'probe-minimal-no-preload' ||
      compatAction === 'probe-renderer-no-preload'
    ) {
      return compatAction
    }
  } catch {
    // ignore invalid action URLs
  }
  return ''
}

function doesWindowsCompatProfileRequireRciDisable(profile) {
  return normalizeWindowsCompatProfile(profile) === 'no-sandbox-no-rci'
}

function shouldRelaunchForWindowsCompatProfile(targetProfile) {
  if (process.platform !== 'win32') return false
  if (normalizeWindowsCompatProfile(targetProfile) === 'safe-fallback') return false
  return doesWindowsCompatProfileRequireRciDisable(targetProfile) !== WINDOWS_COMPAT_BOOT_RCI_DISABLED
}

function buildWindowsCompatLaunchArgs(profile, { persistEligible = false } = {}) {
  const normalizedProfile = normalizeWindowsCompatProfile(profile)
  const nextArgs = process.argv.slice(1).filter(arg => {
    const normalizedArg = String(arg || '')
    return !normalizedArg.startsWith(WINDOWS_COMPAT_PROFILE_ARG_PREFIX) &&
      !normalizedArg.startsWith(WINDOWS_COMPAT_PROFILE_PERSIST_ARG_PREFIX)
  })
  nextArgs.push(`${WINDOWS_COMPAT_PROFILE_ARG_PREFIX}${normalizedProfile}`)
  nextArgs.push(`${WINDOWS_COMPAT_PROFILE_PERSIST_ARG_PREFIX}${persistEligible ? '1' : '0'}`)
  return nextArgs
}

function relaunchWithWindowsCompatProfile(profile, { persistEligible = false, reason = '' } = {}) {
  if (process.platform !== 'win32') return false
  const normalizedProfile = normalizeWindowsCompatProfile(profile)
  const nextArgs = buildWindowsCompatLaunchArgs(normalizedProfile, { persistEligible })
  appendEarlyCrashLog('windows.compat.relaunch', 'relaunching app for windows compatibility profile', {
    compatProfile: normalizedProfile,
    compatProfileSource: 'session-override',
    persistEligible: Boolean(persistEligible),
    reason
  })
  app.relaunch({
    args: nextArgs
  })
  app.exit(0)
  return true
}

function normalizeWindowsRenderDiagnosticMode(mode) {
  const normalizedMode = String(mode || '').trim().toLowerCase()
  if (WINDOWS_RENDER_DIAGNOSTIC_MODE_SET.has(normalizedMode)) {
    return normalizedMode
  }
  return 'full'
}

function normalizeWindowsFullProbeMode(mode) {
  const normalizedMode = String(mode || '').trim().toLowerCase()
  if (normalizedMode === 'safe-style' || normalizedMode === 'delay-renderer-start') {
    return normalizedMode
  }
  return ''
}

function buildWindowsDiagnosticEntryUrl(mode, startupProbe = '', fullProbe = '') {
  const normalizedMode = normalizeWindowsRenderDiagnosticMode(mode)
  const normalizedStartupProbe = String(startupProbe || '').trim().toLowerCase()
  const normalizedFullProbe = normalizeWindowsFullProbeMode(fullProbe)
  const entryUrl = new URL(FILE_APP_ENTRY_URL)
  if (normalizedMode === 'full') {
    entryUrl.searchParams.delete('diag')
  } else {
    entryUrl.searchParams.set('diag', normalizedMode)
  }
  if (normalizedStartupProbe === 'skip-all' || normalizedStartupProbe === 'skip-deferred') {
    entryUrl.searchParams.set('startupProbe', normalizedStartupProbe)
  } else {
    entryUrl.searchParams.delete('startupProbe')
  }
  if (normalizedMode === 'full' && normalizedFullProbe) {
    entryUrl.searchParams.set('fullProbe', normalizedFullProbe)
  } else {
    entryUrl.searchParams.delete('fullProbe')
  }
  entryUrl.searchParams.delete('uiStyle')
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

function buildWindowsCompatActionUrl(action) {
  const targetUrl = process.platform === 'win32'
    ? new URL(WINDOWS_COMPAT_ACTION_BASE_URL)
    : new URL(FILE_APP_ENTRY_URL)
  targetUrl.searchParams.set(WINDOWS_COMPAT_ACTION_QUERY_KEY, action)
  return targetUrl.toString()
}

function buildWindowLoadErrorHtml(error, { windowsCompat = null } = {}) {
  const detail = String(error?.message || error || 'Unknown error').slice(0, 4000)
  const compatProfile = windowsCompat?.compatProfile
    ? normalizeWindowsCompatProfile(windowsCompat.compatProfile)
    : ''
  const crashReason = String(windowsCompat?.lastCrash?.reason || '').trim()
  const crashExitCode = Number(windowsCompat?.lastCrash?.exitCode)
  const rendererCodeIntegrityText = windowsCompat?.rendererCodeIntegrityDisabled ? '已关闭' : '未关闭'
  const windowsCompatInfoHtml = compatProfile
    ? [
        '<div class="compat">',
        '<h2>Windows 兼容状态</h2>',
        `<p><strong>当前兼容档位：</strong>${compatProfile}</p>`,
        crashReason ? `<p><strong>最近崩溃原因：</strong>${crashReason}</p>` : '',
        Number.isFinite(crashExitCode) ? `<p><strong>最近崩溃退出码：</strong>${crashExitCode}</p>` : '',
        `<p><strong>RendererCodeIntegrity 兼容关闭：</strong>${rendererCodeIntegrityText}</p>`,
        '<div class="actions">',
        `<button type="button" data-wordz-compat-action="retry-current">重试当前兼容模式</button>`,
        `<button type="button" data-wordz-compat-action="try-standard">尝试标准模式</button>`,
        `<button type="button" data-wordz-compat-action="reset">重置 Windows 兼容模式</button>`,
        `<button type="button" data-wordz-compat-action="probe-preload-data">测试仅 preload</button>`,
        `<button type="button" data-wordz-compat-action="probe-styles-with-preload">测试样式 + preload</button>`,
        `<button type="button" data-wordz-compat-action="probe-full-safe-style">测试完整界面 + 安全样式</button>`,
        `<button type="button" data-wordz-compat-action="probe-full-delay-renderer">测试完整界面 + 延迟渲染启动</button>`,
        `<button type="button" data-wordz-compat-action="probe-full-no-startup">测试完整界面 + 跳过启动流程</button>`,
        `<button type="button" data-wordz-compat-action="probe-full-sync-only">测试完整界面 + 仅同步启动</button>`,
        `<button type="button" data-wordz-compat-action="probe-minimal-with-preload">测试壳页 + preload</button>`,
        `<button type="button" data-wordz-compat-action="probe-renderer-with-preload">测试渲染层 + preload</button>`,
        `<button type="button" data-wordz-compat-action="probe-minimal-no-preload">测试无 preload 壳页</button>`,
        `<button type="button" data-wordz-compat-action="probe-renderer-no-preload">测试无 preload 渲染层</button>`,
        '</div>',
        '</div>'
      ].filter(Boolean).join('')
    : ''
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
    h2 { margin: 18px 0 10px; font-size: 16px; }
    p { margin: 0 0 8px; line-height: 1.7; }
    pre { margin: 12px 0 0; background: #f2ebe1; border-radius: 12px; padding: 12px; white-space: pre-wrap; word-break: break-word; }
    .compat { margin-top: 18px; padding-top: 16px; border-top: 1px solid rgba(88, 75, 55, 0.12); }
    .actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 12px; }
    button { appearance: none; border: 1px solid rgba(69, 84, 104, 0.18); background: #fff; color: #182131; border-radius: 10px; padding: 9px 12px; cursor: pointer; font: inherit; }
    button:hover { background: #f5ede4; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>WordZ 启动失败</h1>
      <p>主界面加载失败，请重启应用后重试。</p>
      <p>如果问题持续，请在“帮助中心/反馈”中导出诊断并提交 Issue。</p>
      ${windowsCompatInfoHtml}
      <pre>${detail}</pre>
    </div>
  </div>
  <script>
    (function () {
      const actionMap = {
        'retry-current': ${JSON.stringify(buildWindowsCompatActionUrl('retry-current'))},
        'try-standard': ${JSON.stringify(buildWindowsCompatActionUrl('try-standard'))},
        'reset': ${JSON.stringify(buildWindowsCompatActionUrl('reset'))},
        'probe-preload-data': ${JSON.stringify(buildWindowsCompatActionUrl('probe-preload-data'))},
        'probe-styles-with-preload': ${JSON.stringify(buildWindowsCompatActionUrl('probe-styles-with-preload'))},
        'probe-full-safe-style': ${JSON.stringify(buildWindowsCompatActionUrl('probe-full-safe-style'))},
        'probe-full-delay-renderer': ${JSON.stringify(buildWindowsCompatActionUrl('probe-full-delay-renderer'))},
        'probe-full-no-startup': ${JSON.stringify(buildWindowsCompatActionUrl('probe-full-no-startup'))},
        'probe-full-sync-only': ${JSON.stringify(buildWindowsCompatActionUrl('probe-full-sync-only'))},
        'probe-minimal-with-preload': ${JSON.stringify(buildWindowsCompatActionUrl('probe-minimal-with-preload'))},
        'probe-renderer-with-preload': ${JSON.stringify(buildWindowsCompatActionUrl('probe-renderer-with-preload'))},
        'probe-minimal-no-preload': ${JSON.stringify(buildWindowsCompatActionUrl('probe-minimal-no-preload'))},
        'probe-renderer-no-preload': ${JSON.stringify(buildWindowsCompatActionUrl('probe-renderer-no-preload'))}
      }
      document.addEventListener('click', function (event) {
        const button = event.target.closest('[data-wordz-compat-action]')
        if (!button) return
        const action = String(button.getAttribute('data-wordz-compat-action') || '')
        const targetUrl = actionMap[action]
        if (!targetUrl) return
        window.location.href = targetUrl
      })
    })()
  </script>
</body>
</html>`
}

async function loadRendererCrashFallback(win, error, details = null, options = {}) {
  if (!win || win.isDestroyed?.()) return false
  const detailLines = [
    String(error?.message || error || '渲染进程发生异常'),
    details?.reason ? `reason=${details.reason}` : '',
    Number.isFinite(Number(details?.exitCode)) ? `exitCode=${details.exitCode}` : ''
  ].filter(Boolean)
  const fallbackError = new Error(detailLines.join(' | '))
  const fallbackOptions = {
    windowsCompat: windowsCompatController?.getSnapshot?.() || null,
    ...options
  }
  try {
    await win.loadURL(
      `data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(fallbackError, fallbackOptions))}`
    )
    if (!win.isVisible()) win.show()
    return true
  } catch (fallbackErrorInner) {
    captureMainError('window.render-crash-fallback', fallbackErrorInner, details || null)
    return false
  }
}

async function loadMainWindow(win, { reason = 'initial-load', error = null, startupMode = 'full', startupProbe = '', fullProbe = '' } = {}) {
  const normalizedStartupMode = process.platform === 'win32'
    ? normalizeWindowsRenderDiagnosticMode(startupMode)
    : 'full'
  const normalizedStartupProbe = String(startupProbe || '').trim().toLowerCase()
  const normalizedFullProbe = normalizeWindowsFullProbeMode(fullProbe)
  const windowsModeEntryUrl = process.platform === 'win32'
    ? buildWindowsDiagnosticEntryUrl(normalizedStartupMode, normalizedStartupProbe, normalizedFullProbe)
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
          startupProbe: normalizedStartupProbe,
          fullProbe: normalizedFullProbe,
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
            startupProbe: normalizedStartupProbe,
            fullProbe: normalizedFullProbe,
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
          startupProbe: normalizedStartupProbe,
          fullProbe: normalizedFullProbe,
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
      startupProbe: normalizedStartupProbe,
      fullProbe: normalizedFullProbe,
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
      await win.loadURL(
        `data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(fallbackSourceError, {
          windowsCompat: windowsCompatController?.getSnapshot?.() || null
        }))}`
      )
    } catch (fallbackError) {
      captureMainError('window.load-fallback', fallbackError, { reason })
    }
    return false
  } finally {
    setMainWindowLoadAttemptRunning(win, false)
  }
}

function resolveInitialWindowDiagnosticState({
  startupMode = null,
  renderCrashCount = 0,
  windowsRenderDiagnosticModeIndex = null
} = {}) {
  const isWindowsRenderDiagnosticEnabled = process.platform === 'win32'
  const defaultStartupMode = 'full'
  const normalizedStartupMode = isWindowsRenderDiagnosticEnabled
    ? normalizeWindowsRenderDiagnosticMode(startupMode || defaultStartupMode)
    : 'full'
  const fallbackModeIndex = isWindowsRenderDiagnosticEnabled
    ? Math.max(0, WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE.indexOf(normalizedStartupMode))
    : 0
  const normalizedModeIndex = Number.isInteger(windowsRenderDiagnosticModeIndex)
    ? Math.max(0, Math.min(WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE.length - 1, windowsRenderDiagnosticModeIndex))
    : fallbackModeIndex

  return {
    isWindowsRenderDiagnosticEnabled,
    renderCrashCount: Math.max(0, Number(renderCrashCount) || 0),
    windowsRenderDiagnosticModeIndex: normalizedModeIndex,
    currentWindowStartupMode: normalizedStartupMode
  }
}

function destroyWindowQuietly(win, details = null) {
  if (!win || win.isDestroyed?.()) return
  try {
    win.destroy()
  } catch (destroyError) {
    captureMainError('window.destroy', destroyError, details || null)
  }
}

function buildWindowsProbeHtml({
  title = 'WordZ Windows Probe',
  description = '',
  details = '',
  type = 'probe'
} = {}) {
  const safeTitle = String(title || 'WordZ Windows Probe')
  const safeDescription = String(description || '')
  const safeDetails = String(details || '')
  const safeType = String(type || 'probe')
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${safeTitle}</title>
  <style>
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", Arial, sans-serif; background: #121826; color: #ecf3ff; }
    .wrap { max-width: 720px; margin: 10vh auto 0; padding: 24px; }
    .card { background: rgba(15, 23, 42, 0.94); border: 1px solid rgba(148, 163, 184, 0.24); border-radius: 18px; box-shadow: 0 24px 60px rgba(0, 0, 0, 0.35); padding: 22px; }
    .chip { display: inline-flex; align-items: center; padding: 5px 10px; border-radius: 999px; background: rgba(96, 165, 250, 0.18); border: 1px solid rgba(96, 165, 250, 0.34); font-size: 12px; margin-bottom: 14px; }
    h1 { margin: 0 0 12px; font-size: 22px; }
    p { margin: 0 0 10px; line-height: 1.7; }
    pre { margin: 12px 0 0; background: rgba(15, 23, 42, 0.64); border-radius: 12px; padding: 12px; white-space: pre-wrap; word-break: break-word; border: 1px solid rgba(148, 163, 184, 0.18); }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="chip">Windows Probe · ${safeType}</div>
      <h1>${safeTitle}</h1>
      <p>${safeDescription}</p>
      <pre>${safeDetails}</pre>
    </div>
  </div>
</body>
</html>`
}

async function loadWindowsProbePage(win, probeMode) {
  if (!win || win.isDestroyed?.()) return false
  const normalizedProbeMode = String(probeMode || '').trim()
  const probeDescriptions = {
    'preload-data': {
      title: 'WordZ Probe: 仅 preload',
      description: '这个窗口只测试 preload 是否能在一个静态 data URL 页面上稳定执行。',
      details: '如果这个窗口仍然闪退，问题大概率在 preload 或更底层的 Chromium/系统兼容链。'
    }
  }
  const probeInfo = probeDescriptions[normalizedProbeMode] || {
    title: 'WordZ Probe',
    description: '正在执行 Windows 兼容探针。',
    details: normalizedProbeMode || 'unknown'
  }
  appendEarlyCrashLog('windows.compat.probe.begin', 'opening windows compatibility probe window', {
    probeMode: normalizedProbeMode
  })
  await win.loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowsProbeHtml({
    ...probeInfo,
    type: normalizedProbeMode
  }))}`)
  return true
}

async function triggerWindowsCompatAction({
  win,
  action,
  profile,
  persistEligible = false,
  resetPersisted = false,
  resetReason = '',
  manualAttempt = false
} = {}) {
  if (process.platform !== 'win32' || !windowsCompatController?.isSupported?.()) return false

  const normalizedAction = String(action || '').trim()
  const normalizedProfile = normalizeWindowsCompatProfile(profile)
  const actionDetails = {
    action: normalizedAction,
    compatProfile: normalizedProfile,
    persistEligible: Boolean(persistEligible),
    resetPersisted: Boolean(resetPersisted),
    resetReason: String(resetReason || '').trim(),
    manualAttempt: Boolean(manualAttempt)
  }

  appendEarlyCrashLog('windows.compat.action', 'processing windows compatibility action', actionDetails)

  if (resetPersisted && !manualAttempt) {
    await windowsCompatController.clearPersistedState(resetReason || 'manual-reset')
  }

  if (manualAttempt && !shouldRelaunchForWindowsCompatProfile(normalizedProfile)) {
    const replacementWindow = createWindowSafely(
      `windows-compat:${normalizedAction || 'manual'}:manual-attempt`,
      actionDetails,
      {
        startupMode: 'full',
        renderCrashCount: 0,
        windowsRenderDiagnosticModeIndex: 0,
        trackWindowsCompat: true,
        windowsCompatProfileOverride: normalizedProfile,
        windowsCompatSourceOverride: 'manual-attempt',
        windowsCompatPersistEligibleOverride: Boolean(persistEligible),
        manualRecoveryAttempt: true
      }
    )

    if (replacementWindow && !replacementWindow.isDestroyed?.()) {
      focusWindow(replacementWindow)
      destroyWindowQuietly(win, {
        reason: 'windows-compat-action-manual-attempt',
        ...actionDetails
      })
      return true
    }
  }

  if (shouldRelaunchForWindowsCompatProfile(normalizedProfile)) {
    windowsCompatController.clearSessionOverride?.()
    destroyWindowQuietly(win, {
      reason: 'windows-compat-action-relaunch',
      ...actionDetails
    })
    return relaunchWithWindowsCompatProfile(normalizedProfile, {
      persistEligible,
      reason: normalizedAction || 'manual'
    })
  }

  await windowsCompatController.setSessionOverrideProfile(normalizedProfile, {
    source: 'session-override',
    persistEligible,
    resetPersisted: false
  })

  const replacementWindow = createWindowSafely(
    `windows-compat:${normalizedAction || 'manual'}`,
    actionDetails,
    {
      startupMode: 'full',
      renderCrashCount: 0,
      windowsRenderDiagnosticModeIndex: 0
    }
  )

  if (replacementWindow && !replacementWindow.isDestroyed?.()) {
    focusWindow(replacementWindow)
    destroyWindowQuietly(win, {
      reason: 'windows-compat-action',
      ...actionDetails
    })
  }

  if (!replacementWindow && win && !win.isDestroyed?.()) {
    await loadRendererCrashFallback(
      win,
      new Error('Windows 兼容模式切换失败'),
      {
        reason: normalizedAction || 'manual',
        exitCode: 0
      },
      {
        windowsCompat: windowsCompatController?.getSnapshot?.() || null
      }
    )
  }

  return Boolean(replacementWindow)
}

function handleWindowsCompatNavigationAction(win, targetUrl) {
  const compatAction = parseWindowsCompatAction(targetUrl)
  if (!compatAction || process.platform !== 'win32' || !windowsCompatController?.isSupported?.()) {
    return false
  }

  const snapshot = windowsCompatController.getSnapshot?.() || null
  if (
    compatAction === 'probe-preload-data' ||
    compatAction === 'probe-styles-with-preload' ||
    compatAction === 'probe-full-safe-style' ||
    compatAction === 'probe-full-delay-renderer' ||
    compatAction === 'probe-full-no-startup' ||
    compatAction === 'probe-full-sync-only' ||
    compatAction === 'probe-minimal-with-preload' ||
    compatAction === 'probe-renderer-with-preload' ||
    compatAction === 'probe-minimal-no-preload' ||
    compatAction === 'probe-renderer-no-preload'
  ) {
    const probeWindowOptions = compatAction === 'probe-preload-data'
      ? {
          probeMode: 'preload-data',
          preloadEnabledOverride: true,
          startupMode: 'full',
          startupProbe: '',
          fullProbe: '',
          trackWindowsCompat: false
        }
      : compatAction === 'probe-styles-with-preload'
        ? {
            probeMode: 'index-styles-with-preload',
            preloadEnabledOverride: true,
            startupMode: 'styles',
            startupProbe: '',
            fullProbe: '',
            trackWindowsCompat: false
          }
      : compatAction === 'probe-full-safe-style'
        ? {
            probeMode: 'index-full-safe-style',
            preloadEnabledOverride: true,
            startupMode: 'full',
            startupProbe: '',
            fullProbe: 'safe-style',
            trackWindowsCompat: false
          }
      : compatAction === 'probe-full-delay-renderer'
        ? {
            probeMode: 'index-full-delay-renderer',
            preloadEnabledOverride: true,
            startupMode: 'full',
            startupProbe: '',
            fullProbe: 'delay-renderer-start',
            trackWindowsCompat: false
          }
      : compatAction === 'probe-full-no-startup'
        ? {
            probeMode: 'index-full-no-startup',
            preloadEnabledOverride: true,
            startupMode: 'full',
            startupProbe: 'skip-all',
            fullProbe: '',
            trackWindowsCompat: false
          }
      : compatAction === 'probe-full-sync-only'
        ? {
            probeMode: 'index-full-sync-only',
            preloadEnabledOverride: true,
            startupMode: 'full',
            startupProbe: 'skip-deferred',
            fullProbe: '',
            trackWindowsCompat: false
          }
      : compatAction === 'probe-minimal-with-preload'
        ? {
            probeMode: 'index-minimal-with-preload',
            preloadEnabledOverride: true,
            startupMode: 'minimal',
            startupProbe: '',
            fullProbe: '',
            trackWindowsCompat: false
          }
        : compatAction === 'probe-renderer-with-preload'
          ? {
              probeMode: 'index-renderer-with-preload',
              preloadEnabledOverride: true,
              startupMode: 'renderer-no-style',
              startupProbe: '',
              fullProbe: '',
              trackWindowsCompat: false
            }
      : compatAction === 'probe-minimal-no-preload'
        ? {
            probeMode: 'index-minimal-no-preload',
            preloadEnabledOverride: false,
            startupMode: 'minimal',
            startupProbe: '',
            fullProbe: '',
            trackWindowsCompat: false
          }
        : {
            probeMode: 'index-renderer-no-preload',
            preloadEnabledOverride: false,
            startupMode: 'renderer-no-style',
            startupProbe: '',
            fullProbe: '',
            trackWindowsCompat: false
          }

    const probeWindow = createWindowSafely(`windows-probe:${compatAction}`, {
      compatProfile: snapshot?.compatProfile || 'standard'
    }, probeWindowOptions)
    if (probeWindow && !probeWindow.isDestroyed?.()) {
      focusWindow(probeWindow)
    }
    return true
  }

  if (compatAction === 'reset') {
    void triggerWindowsCompatAction({
      win,
      action: compatAction,
      profile: 'standard',
      persistEligible: true,
      resetPersisted: false,
      resetReason: 'manual-reset',
      manualAttempt: true
    })
    return true
  }

  if (compatAction === 'try-standard') {
    void triggerWindowsCompatAction({
      win,
      action: compatAction,
      profile: 'standard',
      persistEligible: false,
      manualAttempt: true
    })
    return true
  }

  void triggerWindowsCompatAction({
    win,
    action: compatAction,
    profile: snapshot?.retryTargetProfile || snapshot?.compatProfile || 'standard',
    persistEligible: false,
    manualAttempt: true
  })
  return true
}

function createWindow({
  startupMode = null,
  renderCrashCount = 0,
  windowsRenderDiagnosticModeIndex = null,
  probeMode = '',
  startupProbe = '',
  fullProbe = '',
  preloadEnabledOverride = null,
  trackWindowsCompat = true,
  windowsCompatProfileOverride = '',
  windowsCompatSourceOverride = '',
  windowsCompatPersistEligibleOverride = null,
  manualRecoveryAttempt = false
} = {}) {
  systemOpenBridgeReady = false
  const windowDiagnosticState = resolveInitialWindowDiagnosticState({
    startupMode,
    renderCrashCount,
    windowsRenderDiagnosticModeIndex
  })
  const { isWindowsRenderDiagnosticEnabled } = windowDiagnosticState
  const normalizedProbeMode = String(probeMode || '').trim()
  const normalizedStartupProbe = String(startupProbe || '').trim().toLowerCase()
  const normalizedFullProbe = normalizeWindowsFullProbeMode(fullProbe)
  const hasWindowsCompatProfileOverride = String(windowsCompatProfileOverride || '').trim() !== ''
  const normalizedWindowsCompatProfileOverride = hasWindowsCompatProfileOverride
    ? normalizeWindowsCompatProfile(windowsCompatProfileOverride)
    : ''
  const normalizedWindowsCompatSourceOverride = String(windowsCompatSourceOverride || '').trim() || 'session-override'
  const normalizedWindowsCompatPersistEligibleOverride =
    typeof windowsCompatPersistEligibleOverride === 'boolean'
      ? windowsCompatPersistEligibleOverride
      : false
  const isManualRecoveryAttempt = Boolean(manualRecoveryAttempt)
  const isProbeWindow = Boolean(normalizedProbeMode)
  const compatSnapshot = windowsCompatController?.getSnapshot?.() || null
  const windowsCompatLaunchConfig = trackWindowsCompat
    ? (
        hasWindowsCompatProfileOverride
          ? windowsCompatController?.beginProfileLaunchContext?.(
              normalizedWindowsCompatProfileOverride,
              {
                source: normalizedWindowsCompatSourceOverride,
                persistEligible: normalizedWindowsCompatPersistEligibleOverride,
                extraDetails: {
                  startupMode: windowDiagnosticState.currentWindowStartupMode,
                  renderCrashCount: windowDiagnosticState.renderCrashCount,
                  windowsRenderDiagnosticModeIndex: windowDiagnosticState.windowsRenderDiagnosticModeIndex,
                  probeMode: normalizedProbeMode,
                  startupProbe: normalizedStartupProbe,
                  fullProbe: normalizedFullProbe,
                  manualRecoveryAttempt: isManualRecoveryAttempt
                }
              }
            )
          : windowsCompatController?.beginWindowLaunchContext?.({
              startupMode: windowDiagnosticState.currentWindowStartupMode,
              renderCrashCount: windowDiagnosticState.renderCrashCount,
              windowsRenderDiagnosticModeIndex: windowDiagnosticState.windowsRenderDiagnosticModeIndex,
              probeMode: normalizedProbeMode,
              startupProbe: normalizedStartupProbe,
              fullProbe: normalizedFullProbe
            })
      )
    : null
  const effectiveWindowsCompatLaunchConfig = windowsCompatLaunchConfig || {
    profile: compatSnapshot?.compatProfile || 'standard',
    source: compatSnapshot?.compatProfileSource || 'default',
    rendererSandboxDisabled: compatSnapshot?.rendererSandboxDisabled ?? DISABLE_RENDERER_SANDBOX,
    disablePreload: false,
    useSafeFallback: false
  }
  const preloadEnabled = typeof preloadEnabledOverride === 'boolean'
    ? preloadEnabledOverride
    : !effectiveWindowsCompatLaunchConfig.disablePreload
  const win = createMainBrowserWindow({
    BrowserWindow,
    appendEarlyCrashLog,
    indexPath: INDEX_HTML_PATH,
    preloadPath: PRELOAD_SCRIPT_PATH,
    appEntryUrl: APP_ENTRY_URL,
    startupMode: windowDiagnosticState.currentWindowStartupMode,
    probeMode: normalizedProbeMode,
    startupProbe: normalizedStartupProbe,
    fullProbe: normalizedFullProbe,
    compatProfile: effectiveWindowsCompatLaunchConfig.profile,
    compatProfileSource: effectiveWindowsCompatLaunchConfig.source,
    rendererSandboxDisabled: effectiveWindowsCompatLaunchConfig.rendererSandboxDisabled,
    preloadEnabled,
    indexExists: fsSync.existsSync(INDEX_HTML_PATH),
    preloadExists: fsSync.existsSync(PRELOAD_SCRIPT_PATH),
    hardenWindow
  })
  setWindowsCompatWindowState(win, {
    trackWindowsCompat: Boolean(trackWindowsCompat),
    manualRecoveryAttempt: isManualRecoveryAttempt,
    stableReported: false,
    compatProfile: effectiveWindowsCompatLaunchConfig.profile,
    compatProfileSource: effectiveWindowsCompatLaunchConfig.source
  })
  win.webContents.on('will-navigate', (event, targetUrl) => {
    if (!handleWindowsCompatNavigationAction(win, targetUrl)) return
    event.preventDefault()
  })
  attachMainWindowLifecycleHandlers({
    win,
    BrowserWindow,
    appendEarlyCrashLog,
    captureMainError,
    getDiagnosticsController: () => diagnosticsController,
    getPrimaryWindow,
    resetSystemOpenBridgeReady: () => {
      systemOpenBridgeReady = false
    },
    loadMainWindow,
    loadRendererCrashFallback,
    recoverFromRendererCrash,
    isWindowsRenderDiagnosticEnabled,
    windowsRenderDiagnosticModeSequence: WINDOWS_RENDER_DIAGNOSTIC_MODE_SEQUENCE,
    windowDiagnosticState,
    handleRenderProcessGone: isProbeWindow
      ? ({ win: targetWindow, error, details }) => {
          appendEarlyCrashLog('windows.compat.probe.crash', 'windows probe renderer crashed', {
            probeMode: normalizedProbeMode,
            reason: String(details?.reason || ''),
            exitCode: Number(details?.exitCode)
          })
          void loadRendererCrashFallback(targetWindow, error, details, {
            windowsCompat: windowsCompatController?.getSnapshot?.() || null
          })
          return true
        }
      : ({ win: targetWindow, error, details }) => {
          if (process.platform !== 'win32' || !windowsCompatController?.isSupported?.()) return false

          void (async () => {
            const crashReason = String(details?.reason || 'render-process-gone')
            const exitCode = Number(details?.exitCode)
            const compatWindowState = getWindowsCompatWindowState(targetWindow)
            const manualRecoveryAttemptActive = Boolean(compatWindowState?.manualRecoveryAttempt)
            const runtimeCrashAfterStable = Boolean(compatWindowState?.stableReported)

            if (manualRecoveryAttemptActive) {
              appendEarlyCrashLog('windows.compat.manual-attempt.crash', 'manual windows compatibility attempt crashed', {
                compatProfile: effectiveWindowsCompatLaunchConfig.profile,
                compatProfileSource: effectiveWindowsCompatLaunchConfig.source,
                reason: crashReason,
                exitCode
              })

              const fallbackWindow = createWindowSafely(
                'windows-compat:manual-attempt-fallback',
                {
                  compatProfile: effectiveWindowsCompatLaunchConfig.profile,
                  crashReason,
                  exitCode
                },
                {
                  startupMode: 'full',
                  renderCrashCount: 0,
                  windowsRenderDiagnosticModeIndex: 0,
                  trackWindowsCompat: true
                }
              )

              if (fallbackWindow && !fallbackWindow.isDestroyed?.()) {
                focusWindow(fallbackWindow)
                destroyWindowQuietly(targetWindow, {
                  reason: 'windows-compat-manual-attempt-crash',
                  compatProfile: effectiveWindowsCompatLaunchConfig.profile,
                  crashReason,
                  exitCode
                })
                return
              }

              await loadRendererCrashFallback(targetWindow, error, details, {
                windowsCompat: windowsCompatController?.getSnapshot?.() || null
              })
              return
            }

            if (runtimeCrashAfterStable) {
              const fallbackSnapshot = await windowsCompatController.enterSafeFallback({
                profile: effectiveWindowsCompatLaunchConfig.profile,
                reason: crashReason,
                exitCode
              })

              const fallbackWindow = createWindowSafely(
                'windows-compat:runtime-crash-fallback',
                {
                  compatProfile: 'safe-fallback',
                  crashReason,
                  exitCode
                },
                {
                  startupMode: 'full',
                  renderCrashCount: 0,
                  windowsRenderDiagnosticModeIndex: 0,
                  trackWindowsCompat: true,
                  windowsCompatProfileOverride: 'safe-fallback',
                  windowsCompatSourceOverride: 'persisted',
                  windowsCompatPersistEligibleOverride: true
                }
              )

              if (fallbackWindow && !fallbackWindow.isDestroyed?.()) {
                focusWindow(fallbackWindow)
                destroyWindowQuietly(targetWindow, {
                  reason: 'windows-compat-runtime-crash-fallback',
                  compatProfile: effectiveWindowsCompatLaunchConfig.profile,
                  crashReason,
                  exitCode
                })
                return
              }

              await loadRendererCrashFallback(targetWindow, error, details, {
                windowsCompat: fallbackSnapshot || windowsCompatController?.getSnapshot?.() || null
              })
              return
            }

            const resolution = await windowsCompatController.recordCrashAndResolveNextProfile({
              reason: crashReason,
              exitCode
            })
            const currentProfile = normalizeWindowsCompatProfile(
              resolution?.currentProfile || effectiveWindowsCompatLaunchConfig.profile
            )
            const nextProfile = normalizeWindowsCompatProfile(resolution?.nextProfile || 'safe-fallback')

            appendEarlyCrashLog('windows.compat.promotion', 'windows compatibility profile promoted after crash', {
              compatProfile: currentProfile,
              compatProfilePromotedFrom: currentProfile,
              compatProfileSource: resolution?.source || effectiveWindowsCompatLaunchConfig.source,
              nextCompatProfile: nextProfile,
              reason: crashReason,
              exitCode
            })

            if (resolution?.source === 'env-override') {
              await loadRendererCrashFallback(targetWindow, error, details, {
                windowsCompat: windowsCompatController?.getSnapshot?.() || null
              })
              return
            }

            if (nextProfile === 'safe-fallback') {
              if (currentProfile === 'safe-fallback') {
                appendEarlyCrashLog(
                  'windows.compat.safe-fallback.crash',
                  'safe fallback renderer crashed; no further automatic recovery will be attempted',
                  {
                    compatProfile: currentProfile,
                    compatProfileSource: resolution?.source || effectiveWindowsCompatLaunchConfig.source,
                    reason: crashReason,
                    exitCode
                  }
                )
                destroyWindowQuietly(targetWindow, {
                  reason: 'windows-compat-safe-fallback-crash',
                  compatProfile: currentProfile,
                  crashReason,
                  exitCode
                })
                showStartupErrorBox(error, 'windows.compat.safe-fallback')
                return
              }

              appendEarlyCrashLog(
                'windows.compat.safe-fallback.enter',
                'switching to terminal safe fallback recovery page',
                {
                  compatProfile: currentProfile,
                  nextCompatProfile: nextProfile,
                  compatProfileSource: resolution?.source || effectiveWindowsCompatLaunchConfig.source,
                  reason: crashReason,
                  exitCode
                }
              )

              const replacementWindow = createWindowSafely(
                'windows-compat:safe-fallback',
                {
                  compatProfile: nextProfile,
                  crashReason,
                  exitCode
                },
                {
                  startupMode: 'full',
                  renderCrashCount: 0,
                  windowsRenderDiagnosticModeIndex: 0,
                  trackWindowsCompat: true
                }
              )

              if (replacementWindow && !replacementWindow.isDestroyed?.()) {
                focusWindow(replacementWindow)
                destroyWindowQuietly(targetWindow, {
                  reason: 'windows-compat-safe-fallback',
                  compatProfile: nextProfile,
                  crashReason,
                  exitCode
                })
                return
              }

              await loadRendererCrashFallback(targetWindow, error, details, {
                windowsCompat: windowsCompatController?.getSnapshot?.() || null
              })
              return
            }

            if (shouldRelaunchForWindowsCompatProfile(nextProfile)) {
              destroyWindowQuietly(targetWindow, {
                reason: 'windows-compat-relaunch',
                compatProfile: nextProfile,
                crashReason,
                exitCode
              })
              relaunchWithWindowsCompatProfile(nextProfile, {
                persistEligible: true,
                reason: `render-process-gone:${crashReason}`
              })
              return
            }

            recoverFromRendererCrash({
              win: targetWindow,
              reason: 'windows-compat-profile-promotion',
              error,
              details,
              startupMode: 'full',
              renderCrashCount: 0,
              windowsRenderDiagnosticModeIndex: 0
            })
          })()

          return true
        }
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
        .loadURL(`data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(error, {
          windowsCompat: windowsCompatController?.getSnapshot?.() || null
        }))}`)
        .catch(fallbackError => {
          captureMainError('window.load-fallback', fallbackError, {
            reason: 'did-fail-load'
          })
        })
    }
  })
  if (normalizedProbeMode === 'preload-data') {
    void loadWindowsProbePage(win, normalizedProbeMode).catch(error => {
      captureMainError('windows.compat.probe.load', error, {
        probeMode: normalizedProbeMode,
        startupProbe: normalizedStartupProbe,
        fullProbe: normalizedFullProbe
      })
    })
  } else if (effectiveWindowsCompatLaunchConfig.useSafeFallback) {
    const compatSnapshot = windowsCompatController?.getSnapshot?.() || null
    void loadRendererCrashFallback(
      win,
      new Error('Windows 兼容模式已切换到安全恢复页。'),
      {
        reason: compatSnapshot?.lastCrash?.reason || 'safe-fallback',
        exitCode: Number(compatSnapshot?.lastCrash?.exitCode)
      },
      {
        windowsCompat: compatSnapshot
      }
    )
  } else {
    void loadMainWindow(win, {
      startupMode: windowDiagnosticState.currentWindowStartupMode,
      startupProbe: normalizedStartupProbe,
      fullProbe: normalizedFullProbe
    })
  }
  win.webContents.on('did-finish-load', () => {
    const loadedUrl = String(win.webContents.getURL() || '')
    if (isTrustedAppEntryUrl(loadedUrl)) {
      markMainWindowLoadSuccess(win, loadedUrl)
    }
    appendEarlyCrashLog('window.did-finish-load', 'renderer finished load', {
      pid: process.pid,
      url: loadedUrl,
      startupMode: windowDiagnosticState.currentWindowStartupMode,
      compatProfile: effectiveWindowsCompatLaunchConfig.profile,
      compatProfileSource: effectiveWindowsCompatLaunchConfig.source,
      probeMode: normalizedProbeMode,
      startupProbe: normalizedStartupProbe,
      fullProbe: normalizedFullProbe
    })
    autoUpdateController?.broadcastStatus?.()
    logMainDiagnostic('info', 'window', '主窗口已完成加载。')
  })
  return win
}

function recoverFromRendererCrash({
  win,
  reason = 'render-process-gone',
  error = null,
  details = null,
  startupMode = 'full',
  renderCrashCount = 0,
  windowsRenderDiagnosticModeIndex = 0
} = {}) {
  appendEarlyCrashLog('window.recover.begin', 'recreating browser window after renderer crash', {
    reason,
    startupMode,
    renderCrashCount,
    windowsRenderDiagnosticModeIndex,
    exitCode: Number(details?.exitCode),
    crashReason: String(details?.reason || '')
  })

  const replacementWindow = createWindowSafely(
    `recover:${reason}`,
    {
      startupMode,
      renderCrashCount,
      windowsRenderDiagnosticModeIndex,
      exitCode: Number(details?.exitCode),
      crashReason: String(details?.reason || '')
    },
    {
      startupMode,
      renderCrashCount,
      windowsRenderDiagnosticModeIndex
    }
  )

  if (replacementWindow && !replacementWindow.isDestroyed?.()) {
    focusWindow(replacementWindow)
    destroyWindowQuietly(win, {
      reason,
      startupMode
    })
  }

  if (!replacementWindow && win && !win.isDestroyed?.()) {
    void loadRendererCrashFallback(win, error, details)
  }

  return replacementWindow
}

function createWindowSafely(reason = 'unknown', details = null, windowOptions = {}) {
  try {
    return createWindow(windowOptions)
  } catch (error) {
    appendEarlyCrashLog('window.create', error, {
      reason,
      details,
      windowOptions
    })
    captureMainError('window.create', error, {
      reason,
      details,
      windowOptions
    })
    void diagnosticsController?.markCrashRecoveryState?.('window.create', error, {
      reason,
      details,
      windowOptions
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
  getExcelJS: getExcelJSModule,
  app,
  packageManifest,
  getAppInfo,
  getRendererShellMarkup,
  reportRendererReady: async (event, payload = {}) => {
    if (process.platform !== 'win32' || !windowsCompatController?.isSupported?.()) {
      return {
        success: true,
        supported: false,
        snapshot: windowsCompatController?.getSnapshot?.() || null
      }
    }

    const senderWindow = BrowserWindow.fromWebContents(event.sender)
    if (senderWindow) {
      setWindowsCompatWindowState(senderWindow, {
        stableReported: true,
        manualRecoveryAttempt: false
      })
    }

    const stage = normalizeTextInput(payload?.stage, {
      fallback: 'renderer-ready',
      maxLength: 64
    })
    const snapshot = await windowsCompatController.reportRendererStable({
      stage
    })

    appendEarlyCrashLog('windows.compat.renderer-ready.ack', 'renderer startup stability acknowledged', {
      compatProfile: snapshot?.compatProfile || '',
      compatProfileSource: snapshot?.compatProfileSource || '',
      stage,
      manualRecoveryAttemptCleared: true
    })

    return {
      success: true,
      supported: true,
      snapshot: snapshot || null
    }
  },
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
  markSystemOpenBridgeReady: () => {
    systemOpenBridgeReady = true
    flushPendingAppMenuActions()
    flushPendingSystemNotificationActions()
  },
  consumePendingSystemOpenFilePaths,
  getAutoUpdateController: () => autoUpdateController,
  getDiagnosticsController: () => diagnosticsController,
  getWindowsCompatController: () => windowsCompatController,
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
  void windowsCompatController?.markNormalExit?.()
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
