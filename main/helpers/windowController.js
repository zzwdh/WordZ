const { buildWindowLoadErrorHtml } = require('./startupPage')
const { createWindowDocumentStateController } = require('./windowDocumentState')
const {
  attachMainWindowLifecycleHandlers,
  createMainBrowserWindow
} = require('./windowLifecycle')

function createWindowController({
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
  getDiagnosticsController,
  getAutoUpdateController,
  resetSystemOpenBridgeReady,
  indexHtmlPath,
  preloadScriptPath,
  appEntryUrl,
  protocolAppEntryUrl,
  fileAppEntryUrl,
  enableCustomProtocol,
  disableRendererSandbox
}) {
  const mainWindowLoadStateMap = new WeakMap()
  const windowDocumentControllerMap = new WeakMap()

  function getPrimaryWindow() {
    return BrowserWindow.getAllWindows().find(win => win && !win.isDestroyed?.()) || null
  }

  function getWindowDocumentController(win) {
    if (!win || win.isDestroyed?.()) return null
    const existingController = windowDocumentControllerMap.get(win)
    if (existingController) return existingController

    const nextController = createWindowDocumentStateController({
      win,
      platform: process.platform,
      appName: app.getName?.() || 'WordZ'
    })
    windowDocumentControllerMap.set(win, nextController)
    return nextController
  }

  function setWindowDocumentState(win, payload = {}) {
    const targetWindow = win && !win.isDestroyed?.() ? win : getPrimaryWindow()
    if (!targetWindow || targetWindow.isDestroyed?.()) {
      return {
        success: false,
        message: '当前没有可用主窗口。'
      }
    }

    const controller = getWindowDocumentController(targetWindow)
    if (!controller) {
      return {
        success: false,
        message: '当前窗口文档状态不可用。'
      }
    }

    return controller.update(payload)
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

  async function loadRendererCrashFallback(win, error, details = null) {
    if (!win || win.isDestroyed?.()) return false
    const detailLines = [
      String(error?.message || error || '渲染进程发生异常'),
      details?.reason ? `reason=${details.reason}` : '',
      Number.isFinite(Number(details?.exitCode)) ? `exitCode=${details.exitCode}` : ''
    ].filter(Boolean)
    const fallbackError = new Error(detailLines.join(' | '))
    try {
      await win.loadURL(
        `data:text/html;charset=UTF-8,${encodeURIComponent(buildWindowLoadErrorHtml(fallbackError))}`
      )
      if (!win.isVisible()) win.show()
      return true
    } catch (fallbackErrorInner) {
      captureMainError('window.render-crash-fallback', fallbackErrorInner, details || null)
      return false
    }
  }

  async function loadMainWindow(win, { reason = 'initial-load', error = null, startupMode = 'full' } = {}) {
    const normalizedStartupMode = String(startupMode || 'full').trim() || 'full'
    const effectiveEntryUrl = appEntryUrl
    const loadAttempts = [
      ...(enableCustomProtocol
        ? [{
            id: 'protocol-url',
            value: protocolAppEntryUrl,
            load: () => win.loadURL(protocolAppEntryUrl)
          }]
        : []),
      {
        id: 'index-load-file',
        value: indexHtmlPath,
        load: () => win.loadFile(indexHtmlPath)
      },
      {
        id: 'index-file-url',
        value: fileAppEntryUrl,
        load: () => win.loadURL(fileAppEntryUrl)
      }
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
            indexPath: indexHtmlPath,
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
              indexPath: indexHtmlPath,
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
            indexPath: indexHtmlPath,
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
        indexPath: indexHtmlPath,
        appEntryUrl: effectiveEntryUrl,
        startupMode: normalizedStartupMode,
        attemptedUrls
      })
      captureMainError('window.load-file', normalizedError, {
        reason,
        indexPath: indexHtmlPath,
        attemptedUrls
      })
      void getDiagnosticsController()?.markCrashRecoveryState?.('window.load-file', normalizedError, {
        reason,
        indexPath: indexHtmlPath,
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

  function resolveInitialWindowDiagnosticState({
    startupMode = 'full',
    renderCrashCount = 0
  } = {}) {
    return {
      renderCrashCount: Math.max(0, Number(renderCrashCount) || 0),
      currentWindowStartupMode: String(startupMode || 'full').trim() || 'full'
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

  function createWindow({
    startupMode = 'full',
    renderCrashCount = 0
  } = {}) {
    resetSystemOpenBridgeReady()
    const windowDiagnosticState = resolveInitialWindowDiagnosticState({
      startupMode,
      renderCrashCount
    })
    const win = createMainBrowserWindow({
      BrowserWindow,
      appendEarlyCrashLog,
      indexPath: indexHtmlPath,
      preloadPath: preloadScriptPath,
      appEntryUrl,
      startupMode: windowDiagnosticState.currentWindowStartupMode,
      rendererSandboxDisabled: disableRendererSandbox,
      preloadEnabled: true,
      indexExists: fsSync.existsSync(indexHtmlPath),
      preloadExists: fsSync.existsSync(preloadScriptPath),
      hardenWindow
    })
    getWindowDocumentController(win)
    attachMainWindowLifecycleHandlers({
      win,
      BrowserWindow,
      appendEarlyCrashLog,
      captureMainError,
      getDiagnosticsController,
      getPrimaryWindow,
      resetSystemOpenBridgeReady,
      loadMainWindow,
      loadRendererCrashFallback,
      recoverFromRendererCrash,
      windowDiagnosticState
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
      void getDiagnosticsController()?.markCrashRecoveryState?.('window.did-fail-load', error, {
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
      startupMode: windowDiagnosticState.currentWindowStartupMode
    })
    win.webContents.on('did-finish-load', () => {
      const loadedUrl = String(win.webContents.getURL() || '')
      if (isTrustedAppEntryUrl(loadedUrl)) {
        markMainWindowLoadSuccess(win, loadedUrl)
      }
      appendEarlyCrashLog('window.did-finish-load', 'renderer finished load', {
        pid: process.pid,
        url: loadedUrl,
        startupMode: windowDiagnosticState.currentWindowStartupMode
      })
      getAutoUpdateController()?.broadcastStatus?.()
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
    renderCrashCount = 0
  } = {}) {
    appendEarlyCrashLog('window.recover.begin', 'recreating browser window after renderer crash', {
      reason,
      startupMode,
      renderCrashCount,
      exitCode: Number(details?.exitCode),
      crashReason: String(details?.reason || '')
    })

    const replacementWindow = createWindowSafely(
      `recover:${reason}`,
      {
        startupMode,
        renderCrashCount,
        exitCode: Number(details?.exitCode),
        crashReason: String(details?.reason || '')
      },
      {
        startupMode,
        renderCrashCount
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
      void getDiagnosticsController()?.markCrashRecoveryState?.('window.create', error, {
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

  return {
    createWindowSafely,
    ensurePrimaryWindow,
    getPrimaryWindow,
    scheduleStartupWindowWatchdog,
    setWindowDocumentState
  }
}

module.exports = {
  createWindowController
}
