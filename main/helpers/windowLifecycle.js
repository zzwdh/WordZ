function createMainBrowserWindow({
  BrowserWindow,
  appendEarlyCrashLog,
  indexPath,
  preloadPath,
  appEntryUrl,
  startupMode,
  probeMode,
  startupProbe,
  fullProbe,
  compatProfile,
  compatProfileSource,
  rendererSandboxDisabled,
  preloadEnabled = true,
  indexExists,
  preloadExists,
  hardenWindow
}) {
  appendEarlyCrashLog('window.create.begin', 'creating browser window', {
    pid: process.pid,
    indexPath,
    preloadPath,
    appEntryUrl,
    startupMode,
    probeMode,
    startupProbe,
    fullProbe,
    compatProfile,
    compatProfileSource,
    rendererSandboxDisabled,
    preloadEnabled,
    indexExists,
    preloadExists
  })

  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1100,
    minHeight: 760,
    show: true,
    backgroundColor: '#f4efe7',
    webPreferences: {
      preload: preloadEnabled ? preloadPath : undefined,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: !rendererSandboxDisabled,
      webSecurity: true,
      allowRunningInsecureContent: false
    }
  })

  hardenWindow(win)
  return win
}

function getConsoleMessageSeverity(level) {
  switch (String(level || '').toLowerCase()) {
    case 'debug':
      return 0
    case 'info':
      return 1
    case 'warning':
      return 2
    case 'error':
      return 3
    default:
      return -1
  }
}

function attachMainWindowLifecycleHandlers({
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
  handleRenderProcessGone,
  isWindowsRenderDiagnosticEnabled,
  windowsRenderDiagnosticModeSequence,
  windowDiagnosticState
}) {
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
      resetSystemOpenBridgeReady()
    }
  })

  win.on('unresponsive', () => {
    const error = new Error('窗口无响应')
    captureMainError('window.unresponsive', error)
    void getDiagnosticsController()?.markCrashRecoveryState?.('window.unresponsive', error)
  })

  win.webContents.on('render-process-gone', (_event, details) => {
    const error = new Error(`渲染进程已退出：${details?.reason || 'unknown'}`)
    const renderGoneDetails = {
      ...(details && typeof details === 'object' ? details : {}),
      startupMode: windowDiagnosticState.currentWindowStartupMode,
      nextCrashCount: windowDiagnosticState.renderCrashCount + 1
    }

    appendEarlyCrashLog('window.render-process-gone', error, renderGoneDetails)
    captureMainError('window.render-process-gone', error, renderGoneDetails)
    void getDiagnosticsController()?.markCrashRecoveryState?.('window.render-process-gone', error, renderGoneDetails)

    if (details?.reason === 'clean-exit') return

    windowDiagnosticState.renderCrashCount += 1

    if (typeof handleRenderProcessGone === 'function') {
      const handled = handleRenderProcessGone({
        win,
        error,
        details,
        windowDiagnosticState
      })
      if (handled) return
    }

    if (
      isWindowsRenderDiagnosticEnabled &&
      windowDiagnosticState.windowsRenderDiagnosticModeIndex < windowsRenderDiagnosticModeSequence.length - 1
    ) {
      windowDiagnosticState.windowsRenderDiagnosticModeIndex += 1
      windowDiagnosticState.currentWindowStartupMode =
        windowsRenderDiagnosticModeSequence[windowDiagnosticState.windowsRenderDiagnosticModeIndex]

      appendEarlyCrashLog('window.render-probe.next-mode', 'switching windows render diagnostic mode', {
        reason: details?.reason || '',
        exitCode: Number(details?.exitCode),
        renderCrashCount: windowDiagnosticState.renderCrashCount,
        startupMode: windowDiagnosticState.currentWindowStartupMode,
        startupModeIndex: windowDiagnosticState.windowsRenderDiagnosticModeIndex
      })

      void recoverFromRendererCrash({
        win,
        reason: 'render-process-gone',
        error,
        details,
        startupMode: windowDiagnosticState.currentWindowStartupMode,
        renderCrashCount: windowDiagnosticState.renderCrashCount,
        windowsRenderDiagnosticModeIndex: windowDiagnosticState.windowsRenderDiagnosticModeIndex
      })
      return
    }

    if (!isWindowsRenderDiagnosticEnabled && windowDiagnosticState.renderCrashCount === 1) {
      void recoverFromRendererCrash({
        win,
        reason: 'render-process-gone',
        error,
        details,
        startupMode: windowDiagnosticState.currentWindowStartupMode,
        renderCrashCount: windowDiagnosticState.renderCrashCount,
        windowsRenderDiagnosticModeIndex: windowDiagnosticState.windowsRenderDiagnosticModeIndex
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
  win.webContents.on('console-message', details => {
    const normalizedMessage = String(details?.message || '')
    const shouldCaptureStartupDebugMessage =
      normalizedMessage.includes('[startup.') ||
      normalizedMessage.includes('[renderer.startup')

    if (getConsoleMessageSeverity(details?.level) < 2 && !shouldCaptureStartupDebugMessage) return
    if (consoleErrorLogCount >= 30) return
    consoleErrorLogCount += 1

    appendEarlyCrashLog('window.console-message', normalizedMessage, {
      level: String(details?.level || ''),
      line: Number(details?.lineNumber),
      sourceId: String(details?.sourceId || ''),
      url: win.webContents.getURL()
    })
  })
}

module.exports = {
  attachMainWindowLifecycleHandlers,
  createMainBrowserWindow
}
