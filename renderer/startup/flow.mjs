export function runInitialRendererSetup({
  runSyncPhase,
  decorateStaticButtons,
  updateAnalysisActionButtons,
  setPreviewCollapsed,
  taskCenter,
  updateAnalysisQueueControls,
  setOpenCorpusMenuOpen,
  bindDropImportHandlers,
  revealNativeToolbarOverflowForSmoke,
  initUISettings,
  loadRecentOpenEntries,
  renderWorkspaceOverview,
  renderSelectedCorporaTable,
  updateLoadSelectedCorporaButton,
  renderRecentOpenList,
  syncSharedSearchInputs,
  syncSearchOptionInputs,
  syncChiSquareInputsFromState,
  renderCompareSection,
  renderWordCloud,
  renderNgramTable,
  renderChiSquareResult,
  applyAppInfoToShell,
  applyAutoUpdateButtonState,
  syncWelcomePreferenceCheckboxes,
  refreshDiagnosticsStatusText,
  refreshAnalysisCacheState,
  shouldShowFirstRunTutorial,
  showWelcomeOverlay,
  setWelcomeProgress,
  recordRendererInitialized
}) {
  runSyncPhase('sync.decorate-static-buttons', () => {
    decorateStaticButtons()
  })
  runSyncPhase('sync.update-analysis-actions', () => {
    updateAnalysisActionButtons()
  })
  runSyncPhase('sync.prepare-preview', () => {
    setPreviewCollapsed(true)
  })
  runSyncPhase('sync.render-task-center', () => {
    taskCenter.render()
  })
  runSyncPhase('sync.update-analysis-queue-controls', () => {
    updateAnalysisQueueControls()
  })
  runSyncPhase('sync.close-open-corpus-menu', () => {
    setOpenCorpusMenuOpen(false)
  })
  runSyncPhase('sync.bind-drop-import', () => {
    bindDropImportHandlers()
  })
  runSyncPhase('sync.reveal-native-toolbar-overflow-smoke', () => {
    void revealNativeToolbarOverflowForSmoke()
  })

  const initialUISettings = runSyncPhase('sync.init-ui-settings', () => initUISettings())
  const recentOpenEntries = runSyncPhase('sync.load-recent-open-entries', () => loadRecentOpenEntries())

  runSyncPhase('sync.render-workspace-overview', () => {
    renderWorkspaceOverview()
  })
  runSyncPhase('sync.render-selected-corpora', () => {
    renderSelectedCorporaTable()
    updateLoadSelectedCorporaButton()
  })
  runSyncPhase('sync.render-recent-open', () => {
    renderRecentOpenList()
  })
  runSyncPhase('sync.sync-search-controls', () => {
    syncSharedSearchInputs()
    syncSearchOptionInputs()
  })
  runSyncPhase('sync.sync-chi-square-inputs', () => {
    syncChiSquareInputsFromState()
  })
  runSyncPhase('sync.render-initial-analysis-sections', () => {
    renderCompareSection()
    renderWordCloud()
    renderNgramTable()
    renderChiSquareResult()
  })
  runSyncPhase('sync.apply-app-shell-info', () => {
    applyAppInfoToShell()
    applyAutoUpdateButtonState(null)
    syncWelcomePreferenceCheckboxes()
  })
  runSyncPhase('sync.refresh-diagnostic-panels', () => {
    void refreshDiagnosticsStatusText()
    void refreshAnalysisCacheState({ silent: true })
  })

  const showFirstRunTutorial = Boolean(shouldShowFirstRunTutorial())
  if (initialUISettings.showWelcomeScreen !== false || showFirstRunTutorial) {
    runSyncPhase('sync.show-welcome-overlay', () => {
      showWelcomeOverlay({
        force: showFirstRunTutorial,
        tutorialMode: showFirstRunTutorial
      })
      setWelcomeProgress(
        12,
        '正在载入界面设置...',
        showFirstRunTutorial ? '正在准备首次使用教程' : '正在准备欢迎界面'
      )
    })
  }

  runSyncPhase('sync.record-renderer-initialized', () => {
    recordRendererInitialized(initialUISettings)
  })

  return {
    initialUISettings,
    recentOpenEntries,
    showFirstRunTutorial
  }
}

export async function runDeferredRendererStartup({
  runPhase,
  setWelcomeProgress,
  ensureAppInfoLoaded,
  consumePendingSystemOpenFiles,
  initializeAutoUpdate,
  runCrashRecoveryWizard,
  maybeRestoreWorkspaceOnStartup,
  markWorkspaceSnapshotReady,
  scheduleWorkspaceSnapshotSave,
  waitForNextFrame,
  markWelcomeReady
}) {
  await runPhase('async.ensure-app-info-loaded', async () => {
    setWelcomeProgress(32, '正在同步版本信息...', '正在读取当前版本')
    await ensureAppInfoLoaded()
  })

  await runPhase('async.consume-pending-system-open-files', async () => {
    await consumePendingSystemOpenFiles()
  })

  await runPhase('async.initialize-auto-update', async () => {
    setWelcomeProgress(58, '正在初始化自动更新...', '正在连接桌面更新能力')
    await initializeAutoUpdate()
  })

  await runPhase('async.run-crash-recovery-wizard', async () => {
    setWelcomeProgress(68, '正在检查异常恢复状态...', '正在准备恢复向导')
    await runCrashRecoveryWizard()
  })

  await runPhase('async.restore-workspace-on-startup', async () => {
    await maybeRestoreWorkspaceOnStartup()
  })

  await runPhase('async.mark-workspace-snapshot-ready', async () => {
    markWorkspaceSnapshotReady()
    scheduleWorkspaceSnapshotSave({ immediate: true })
  })

  await runPhase('async.wait-next-frame', async () => {
    await waitForNextFrame()
  })

  await runPhase('async.mark-welcome-ready', async () => {
    setWelcomeProgress(90, '正在整理工作区与工具栏...', '正在准备分析工作台')
    markWelcomeReady()
  })
}
