async function initializeAppReadyState({
  app,
  BrowserWindow,
  Menu,
  NotificationClass,
  nativeImage,
  packageManifest,
  fs,
  path,
  processExecPath,
  processPlatform,
  processArgv,
  appUserModelId,
  smokeUserDataDir,
  legacyUserDataDirNames,
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
}) {
  appendEarlyCrashLog('app.whenReady.start', 'app ready sequence started', {
    pid: process.pid
  })
  await setupAppProtocol()
  if (processPlatform === 'win32' && typeof app.setAppUserModelId === 'function') {
    app.setAppUserModelId(appUserModelId)
  }

  const diagnosticsController = createDiagnosticsController({
    app,
    packageManifest,
    logger: console
  })
  const analysisCacheController = createAnalysisCacheController({
    app,
    fs,
    logger: console
  })
  const windowProgressController = createWindowProgressController({
    platform: processPlatform,
    getWindows: () => BrowserWindow.getAllWindows(),
    logger: console,
    onApply: event => {
      pushSmokeObserverEvent('windowProgress', event)
    }
  })
  const windowAttentionController = createWindowAttentionController({
    app,
    nativeImage,
    appName: packageManifest.productName || packageManifest.name || app.getName() || 'WordZ',
    platform: processPlatform,
    getWindows: () => BrowserWindow.getAllWindows(),
    logger: console,
    onApply: event => {
      pushSmokeObserverEvent('windowAttention', event)
    }
  })
  const systemNotificationController = createSystemNotificationController({
    NotificationClass,
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
      legacyDirNames: legacyUserDataDirNames,
      smokeUserDataDir,
      logger: console
    })
    await getCorpusStorage().prepare()
    logMainDiagnostic('info', 'storage', '本地语料库已准备完成。')
  } catch (error) {
    console.error('[corpus-library.prepare]', error)
    captureMainError('storage.prepare', error)
  }

  configureSessionSecurity()
  setupApplicationMenu({
    Menu,
    app,
    platform: processPlatform,
    dispatchAppMenuAction
  })
  setupPlatformFileIntegration({
    app,
    Menu,
    platform: processPlatform,
    processExecPath,
    dispatchAppMenuAction,
    captureMainError
  })

  const autoUpdateController = createAutoUpdateController({
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

  handleLaunchActionArgs({
    argv: processArgv,
    extractLaunchAction,
    dispatchAppMenuAction
  })
  handleSystemOpenFilePaths(processArgv)
  if (!getPrimaryWindow()) {
    ensurePrimaryWindow('app.whenReady.init')
  }
  autoUpdateController.initialize()
  logMainDiagnostic('info', 'app', '主窗口与自动更新已初始化。')
  appendEarlyCrashLog('app.whenReady.done', 'app ready sequence completed', {
    pid: process.pid,
    windowCount: BrowserWindow.getAllWindows().length
  })

  return {
    analysisCacheController,
    autoUpdateController,
    diagnosticsController,
    systemNotificationController,
    windowAttentionController,
    windowProgressController
  }
}

module.exports = {
  initializeAppReadyState
}
