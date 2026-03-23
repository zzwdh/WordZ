function setupSingleInstanceHandling({
  app,
  disableSingleInstance = false,
  appendEarlyCrashLog,
  handleLaunchActionArgs,
  extractLaunchAction,
  dispatchAppMenuAction,
  handleSystemOpenFilePaths,
  ensurePrimaryWindow
}) {
  if (!disableSingleInstance) {
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
      return
    }

    app.on('second-instance', (_event, argv) => {
      appendEarlyCrashLog('single-instance.second-instance', 'received', {
        pid: process.pid,
        argvCount: Array.isArray(argv) ? argv.length : 0
      })
      handleLaunchActionArgs({
        argv,
        extractLaunchAction,
        dispatchAppMenuAction
      })
      handleSystemOpenFilePaths(argv)
      ensurePrimaryWindow('second-instance')
    })
    return
  }

  appendEarlyCrashLog('single-instance.disabled', 'single-instance lock disabled by env', {
    pid: process.pid,
    disableSingleInstance: true
  })
}

function setupOpenFileHandler({ app, handleSystemOpenFilePaths }) {
  app.on('open-file', (event, filePath) => {
    event.preventDefault()
    handleSystemOpenFilePaths([filePath])
  })
}

function setupProcessErrorHandling({
  processObject = process,
  appendEarlyCrashLog,
  captureMainError,
  getDiagnosticsController
}) {
  processObject.on('uncaughtException', error => {
    appendEarlyCrashLog('uncaughtException', error)
    captureMainError('main.uncaughtException', error)
    void getDiagnosticsController()?.markCrashRecoveryState?.('main.uncaughtException', error)
    console.error('[uncaughtException]', error)
  })

  processObject.on('unhandledRejection', reason => {
    const normalizedError = reason instanceof Error ? reason : new Error(String(reason))
    appendEarlyCrashLog('unhandledRejection', normalizedError, {
      reason: reason instanceof Error ? undefined : String(reason)
    })
    captureMainError('main.unhandledRejection', normalizedError, {
      reason: reason instanceof Error ? undefined : String(reason)
    })
    void getDiagnosticsController()?.markCrashRecoveryState?.('main.unhandledRejection', normalizedError, {
      reason: reason instanceof Error ? undefined : String(reason)
    })
    console.error('[unhandledRejection]', reason)
  })
}

function setupCommonAppLifecycleHandlers({
  app,
  BrowserWindow,
  appendEarlyCrashLog,
  logMainDiagnostic,
  getWindowAttentionController,
  getWindowProgressController,
  getAutoUpdateController,
  ensurePrimaryWindow
}) {
  app.on('activate', () => {
    appendEarlyCrashLog('app.activate', 'app activate event', {
      pid: process.pid,
      windowCount: BrowserWindow.getAllWindows().length
    })
    if (BrowserWindow.getAllWindows().length === 0) {
      ensurePrimaryWindow('app.activate')
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
    getWindowAttentionController()?.clearAll?.()
    getWindowProgressController()?.clearAll?.()
    getAutoUpdateController()?.dispose?.()
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
}

module.exports = {
  setupCommonAppLifecycleHandlers,
  setupOpenFileHandler,
  setupProcessErrorHandling,
  setupSingleInstanceHandling
}
