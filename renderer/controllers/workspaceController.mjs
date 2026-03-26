import {
  buildRecentOpenEntryFromResult,
  normalizeRecentOpenEntry,
  renderRecentOpenList as renderRecentOpenListView
} from '../recentOpen.mjs'
import { getRestorableTabFromSnapshot } from '../sessionState.mjs'

export function createWorkspaceController({
  electronAPI,
  persistedState,
  dom,
  recentOpenLimit,
  defaultWindowSize,
  normalizeSearchOptions,
  hasMeaningfulWorkspaceSnapshot,
  getWorkspaceSnapshotSummary,
  getTabLabel,
  getCurrentUISettings,
  beginBusyState,
  showMissingBridge,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  recordDiagnostic,
  refreshDiagnosticsStatusText,
  getDiagnosticRendererState,
  openGitHubFeedbackIssue,
  getErrorMessage,
  loadCorpusResult,
  setOpenCorpusMenuOpen,
  setPreviewCollapsed,
  applySelectControlValue,
  normalizeWindowSizeInput,
  resolvePageSize,
  syncChiSquareInputsFromState,
  renderChiSquareResult,
  syncSearchOptionInputs,
  syncStopwordFilterControls,
  setSharedSearchQuery,
  runNgramAnalysis,
  renderNgramTable,
  switchTab,
  updateCurrentCorpusInfo,
  renderCompareSection,
  renderWordCloud,
  requestWorkspaceRestoreDecision,
  getWorkspaceSnapshotState,
  applyRestoredWorkspaceState,
  workspaceDocumentService
}) {
  let workspaceSnapshotTimer = null
  let workspaceSnapshotReady = false
  let workspaceRestoreInProgress = false
  let startupRestoreHandledByCrashWizard = false
  let recentOpenEntries = []

  function syncWindowDocumentEditedState(snapshot = buildWorkspaceSnapshot()) {
    if (!workspaceDocumentService) return false
    const { edited } = workspaceDocumentService.syncEditedFromSnapshot(snapshot, {
      workspaceReady: workspaceSnapshotReady,
      workspaceRestoreInProgress
    })
    return edited
  }

  function getRecentOpenEntries() {
    return recentOpenEntries
  }

  function loadRecentOpenEntries() {
    recentOpenEntries = persistedState.loadRecentOpenEntries()
    return recentOpenEntries
  }

  function setRecentOpenEntries(entries = []) {
    recentOpenEntries = Array.isArray(entries) ? entries : []
    return recentOpenEntries
  }

  function persistRecentOpenEntries() {
    recentOpenEntries = persistedState.saveRecentOpenEntries(recentOpenEntries)
    return recentOpenEntries
  }

  function renderRecentOpenList() {
    renderRecentOpenListView(
      {
        section: dom.recentOpenSection,
        list: dom.recentOpenList,
        clearButton: dom.clearRecentOpenButton
      },
      recentOpenEntries
    )
  }

  function addRecentOpenEntry(entry) {
    const normalizedEntry = normalizeRecentOpenEntry(entry)
    if (!normalizedEntry) return
    recentOpenEntries = [
      normalizedEntry,
      ...recentOpenEntries.filter(item => item.key !== normalizedEntry.key)
    ].slice(0, recentOpenLimit)
    persistRecentOpenEntries()
    renderRecentOpenList()
  }

  function clearRecentOpenEntries() {
    recentOpenEntries = []
    persistRecentOpenEntries()
    renderRecentOpenList()
  }

  function loadStoredWorkspaceSnapshot() {
    return persistedState.loadWorkspaceSnapshot()
  }

  function buildWorkspaceSnapshot() {
    if (!workspaceDocumentService) {
      return {
        version: 1,
        savedAt: new Date().toISOString()
      }
    }
    return workspaceDocumentService.buildWorkspaceSnapshot(
      getWorkspaceSnapshotState()
    )
  }

  function persistWorkspaceSnapshot() {
    if (workspaceRestoreInProgress || !workspaceSnapshotReady) return
    try {
      const snapshot = buildWorkspaceSnapshot()
      persistedState.saveWorkspaceSnapshot(snapshot)
      workspaceDocumentService?.markSnapshotPersisted(snapshot)
      syncWindowDocumentEditedState(snapshot)
    } catch (error) {
      console.warn('[workspace.snapshot.save]', error)
    }
  }

  function scheduleWorkspaceSnapshotSave({ immediate = false } = {}) {
    if (workspaceRestoreInProgress || !workspaceSnapshotReady) return
    syncWindowDocumentEditedState()
    if (workspaceSnapshotTimer) clearTimeout(workspaceSnapshotTimer)
    if (immediate) {
      workspaceSnapshotTimer = null
      persistWorkspaceSnapshot()
      return
    }
    workspaceSnapshotTimer = setTimeout(() => {
      workspaceSnapshotTimer = null
      persistWorkspaceSnapshot()
    }, 120)
  }

  async function restoreWorkspaceFromSnapshot(snapshot = loadStoredWorkspaceSnapshot()) {
    if (!snapshot || getCurrentUISettings().restoreWorkspace === false) return

    workspaceRestoreInProgress = true
    const endBusyState = beginBusyState('正在恢复上次工作区...')

    try {
      applyRestoredWorkspaceState({
        currentLibraryFolderId: snapshot.currentLibraryFolderId,
        previewCollapsed: snapshot.previewCollapsed !== false
      })
      setPreviewCollapsed(snapshot.previewCollapsed !== false)

      let restoredSavedWorkspace = false
      if (snapshot.workspace?.corpusIds?.length > 0 && electronAPI?.openSavedCorpora) {
        const result = await electronAPI.openSavedCorpora(snapshot.workspace.corpusIds)
        if (result?.success) {
          await loadCorpusResult(result, { trackRecent: false })
          restoredSavedWorkspace = true
        } else {
          void recordDiagnostic('warn', 'workspace.restore', '未能恢复上次已保存语料工作区。', {
            message: result?.message || '未知原因',
            corpusIds: snapshot.workspace.corpusIds
          })
        }
      }

      applySelectControlValue(dom.pageSizeSelect, snapshot.stats?.pageSize, '10')
      applySelectControlValue(dom.comparePageSizeSelect, snapshot.compare?.pageSize, '10')
      applySelectControlValue(dom.ngramPageSizeSelect, snapshot.ngram?.pageSize, '10')
      applySelectControlValue(dom.ngramSizeSelect, snapshot.ngram?.size, '2')
      applySelectControlValue(dom.kwicPageSizeSelect, snapshot.kwic?.pageSize, '10')
      applySelectControlValue(dom.collocatePageSizeSelect, snapshot.collocate?.pageSize, '10')
      applySelectControlValue(dom.kwicSortSelect, snapshot.kwic?.sortMode, 'original')
      applySelectControlValue(dom.kwicScopeSelect, snapshot.kwic?.scope, 'current')
      applySelectControlValue(dom.collocateMinFreqSelect, snapshot.collocate?.minFreq, '1')

      if (dom.leftWindowSelect) {
        dom.leftWindowSelect.value = snapshot.kwic?.leftWindow
        normalizeWindowSizeInput(dom.leftWindowSelect)
      }
      if (dom.rightWindowSelect) {
        dom.rightWindowSelect.value = snapshot.kwic?.rightWindow
        normalizeWindowSizeInput(dom.rightWindowSelect)
      }
      if (dom.collocateLeftWindowSelect) {
        dom.collocateLeftWindowSelect.value = snapshot.collocate?.leftWindow
        normalizeWindowSizeInput(dom.collocateLeftWindowSelect)
      }
      if (dom.collocateRightWindowSelect) {
        dom.collocateRightWindowSelect.value = snapshot.collocate?.rightWindow
        normalizeWindowSizeInput(dom.collocateRightWindowSelect)
      }

      const restoredSearchOptions = normalizeSearchOptions(snapshot.search?.options)
      applyRestoredWorkspaceState({
        searchOptions: restoredSearchOptions,
        searchQuery: snapshot.search?.query || '',
        stopwordFilter: snapshot.search?.stopwordFilter || {},
        statsPageSize: resolvePageSize(dom.pageSizeSelect?.value || '10', getWorkspaceSnapshotState().visibleFrequencyRowCount || 0),
        comparePageSize: resolvePageSize(dom.comparePageSizeSelect?.value || '10', getWorkspaceSnapshotState().visibleCompareRowCount || 0),
        ngramSize: Number(dom.ngramSizeSelect?.value || snapshot.ngram?.size || '2') || 2,
        ngramPageSize: resolvePageSize(dom.ngramPageSizeSelect?.value || '10', getWorkspaceSnapshotState().ngramRowCount || 0),
        kwicPageSize: resolvePageSize(dom.kwicPageSizeSelect?.value || '10', getWorkspaceSnapshotState().kwicResultCount || 0),
        collocatePageSize: resolvePageSize(dom.collocatePageSizeSelect?.value || '10', getWorkspaceSnapshotState().collocateRowCount || 0),
        kwicSortMode: dom.kwicSortSelect?.value || 'original',
        kwicScope: dom.kwicScopeSelect?.value || 'current',
        kwicLeftWindow: Number(dom.leftWindowSelect?.value || String(defaultWindowSize)) || defaultWindowSize,
        kwicRightWindow: Number(dom.rightWindowSelect?.value || String(defaultWindowSize)) || defaultWindowSize,
        collocateLeftWindow: Number(dom.collocateLeftWindowSelect?.value || String(defaultWindowSize)) || defaultWindowSize,
        collocateRightWindow: Number(dom.collocateRightWindowSelect?.value || String(defaultWindowSize)) || defaultWindowSize,
        collocateMinFreq: Number(dom.collocateMinFreqSelect?.value || '1') || 1,
        chiSquareInputValues: {
          a: String(snapshot.chiSquare?.a || ''),
          b: String(snapshot.chiSquare?.b || ''),
          c: String(snapshot.chiSquare?.c || ''),
          d: String(snapshot.chiSquare?.d || ''),
          yates: snapshot.chiSquare?.yates === true
        }
      })
      syncChiSquareInputsFromState()
      renderChiSquareResult()
      syncSearchOptionInputs()
      syncStopwordFilterControls()
      setSharedSearchQuery(snapshot.search?.query || '', { rerender: false })

      if (getWorkspaceSnapshotState().tokenCount > 0) {
        await runNgramAnalysis({ silent: true })
      } else {
        renderNgramTable()
      }

      const restoredTab = getRestorableTabFromSnapshot(snapshot)
      switchTab(restoredTab)
      updateCurrentCorpusInfo()
      renderCompareSection()
      renderWordCloud()
      void recordDiagnostic(
        'info',
        'workspace.restore',
        restoredSavedWorkspace ? '已恢复上次工作区。' : '已恢复上次工作区偏好设置。',
        {
          restoredSavedWorkspace,
          currentTab: restoredTab,
          corpusCount: snapshot.workspace?.corpusIds?.length || 0
        }
      )
      workspaceDocumentService?.markSnapshotPersisted(buildWorkspaceSnapshot())
    } finally {
      workspaceRestoreInProgress = false
      endBusyState()
    }
  }

  async function openRecentOpenEntry(entry) {
    const normalizedEntry = normalizeRecentOpenEntry(entry)
    if (!normalizedEntry) return

    let result = null
    if (normalizedEntry.type === 'quick') {
      if (!electronAPI?.openQuickCorpusAtPath) {
        await showMissingBridge('openQuickCorpusAtPath')
        return
      }
      result = await electronAPI.openQuickCorpusAtPath(normalizedEntry.filePath)
    } else if (normalizedEntry.type === 'saved-multi') {
      if (!electronAPI?.openSavedCorpora) {
        await showMissingBridge('openSavedCorpora')
        return
      }
      result = await electronAPI.openSavedCorpora(normalizedEntry.corpusIds)
    } else {
      if (!electronAPI?.openSavedCorpus) {
        await showMissingBridge('openSavedCorpus')
        return
      }
      result = await electronAPI.openSavedCorpus(normalizedEntry.corpusId)
    }

    if (!result?.success) {
      recentOpenEntries = recentOpenEntries.filter(item => item.key !== normalizedEntry.key)
      persistRecentOpenEntries()
      renderRecentOpenList()
      await showAlert({
        title: '打开最近语料失败',
        message: result?.message || '该最近打开项目已不可用，已从列表中移除。'
      })
      return
    }

    setOpenCorpusMenuOpen(false)
    await loadCorpusResult(result)
  }

  async function runCrashRecoveryWizard() {
    if (!electronAPI?.consumeCrashRecoveryState) return
    const result = await electronAPI.consumeCrashRecoveryState()
    if (!result?.success || !result.recoveryState) return

    const recoveryState = result.recoveryState
    const source = String(recoveryState?.source || 'unknown')
    const errorMessage = String(recoveryState?.error?.message || '未知错误')
    const recordedAt = String(recoveryState?.recordedAt || '')
    await showAlert({
      title: '检测到上次异常退出',
      message: [
        `异常来源：${source}`,
        `异常信息：${errorMessage}`,
        recordedAt ? `记录时间：${recordedAt}` : '',
        '',
        '你可以恢复上次会话，或导出诊断并反馈到 GitHub。'
      ].filter(Boolean).join('\n')
    })

    const workspaceSnapshot = loadStoredWorkspaceSnapshot()
    if (getCurrentUISettings().restoreWorkspace !== false && hasMeaningfulWorkspaceSnapshot(workspaceSnapshot)) {
      const shouldRestore = await requestWorkspaceRestoreDecision(workspaceSnapshot)
      startupRestoreHandledByCrashWizard = true
      if (shouldRestore) {
        await restoreWorkspaceFromSnapshot(workspaceSnapshot)
      } else {
        void recordDiagnostic('info', 'workspace.restore', '崩溃恢复向导中用户选择暂不恢复上次工作区。')
      }
    }

    const shouldExportDiagnostics = await showConfirm({
      title: '导出诊断报告',
      message: '是否现在导出一份诊断报告，便于定位问题？',
      confirmText: '导出诊断',
      cancelText: '跳过'
    })
    if (shouldExportDiagnostics) {
      if (!electronAPI?.exportDiagnosticReport) {
        await showMissingBridge('exportDiagnosticReport')
      } else {
        const exportResult = await electronAPI.exportDiagnosticReport(getDiagnosticRendererState())
        if (exportResult?.success) {
          await refreshDiagnosticsStatusText()
          showToast(`诊断报告已导出到：${exportResult.filePath}`, {
            title: '崩溃恢复',
            type: 'success'
          })
          void notifySystem({
            title: '诊断报告已导出',
            body: exportResult.filePath,
            tag: 'diagnostics-export',
            category: 'diagnostics-export',
            action: {
              actionId: 'reveal-path',
              payload: { path: exportResult.filePath }
            }
          })
        } else if (!exportResult?.canceled) {
          await showAlert({
            title: '导出诊断报告失败',
            message: exportResult?.message || '诊断报告导出失败，请稍后重试。'
          })
        }
      }
    }

    const shouldOpenGitHubIssue = await showConfirm({
      title: '反馈到 GitHub',
      message: '是否现在打开 GitHub Issues 反馈页面？系统会自动带上当前会话摘要。',
      confirmText: '打开反馈页面',
      cancelText: '稍后'
    })
    if (shouldOpenGitHubIssue) {
      await openGitHubFeedbackIssue({
        issueTitle: `[Bug][CrashRecovery] ${source}`.slice(0, 120),
        source: 'crash-recovery-wizard'
      })
    }
  }

  function markWorkspaceSnapshotReady() {
    workspaceSnapshotReady = true
  }

  function wasStartupRestoreHandledByCrashWizard() {
    return startupRestoreHandledByCrashWizard
  }

  return {
    addRecentOpenEntry,
    clearRecentOpenEntries,
    getRecentOpenEntries,
    loadRecentOpenEntries,
    loadStoredWorkspaceSnapshot,
    markWorkspaceSnapshotReady,
    openRecentOpenEntry,
    renderRecentOpenList,
    restoreWorkspaceFromSnapshot,
    runCrashRecoveryWizard,
    scheduleWorkspaceSnapshotSave,
    setRecentOpenEntries,
    wasStartupRestoreHandledByCrashWizard
  }
}
