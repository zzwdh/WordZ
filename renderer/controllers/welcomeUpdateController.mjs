export function createWelcomeUpdateController({
  dom,
  electronAPI,
  getCurrentUISettings,
  getCurrentAppInfo,
  getWorkspaceSnapshotSummary,
  getTabLabel,
  hasMeaningfulWorkspaceSnapshot,
  showAlert,
  showConfirm,
  showToast,
  notifySystem,
  setWindowAttentionState,
  setButtonLabel
}) {
  let currentAutoUpdateState = null
  let announcedAvailableVersion = ''
  let promptedDownloadedVersion = ''
  let welcomeOverlayVisible = false
  let welcomeReady = false
  let welcomeTutorialVisible = false
  let manualTutorialOpen = false
  let pendingWorkspaceRestoreSnapshot = null
  let startupRestoreDecisionResolver = null

  function setWelcomeRestorePromptSnapshot(snapshot) {
    pendingWorkspaceRestoreSnapshot = snapshot || null
    if (dom.welcomeRestorePrompt) {
      dom.welcomeRestorePrompt.classList.toggle('hidden', !snapshot)
    }
    if (dom.welcomeRestoreSummary) {
      dom.welcomeRestoreSummary.textContent = snapshot
        ? getWorkspaceSnapshotSummary(snapshot, { getTabLabel })
        : ''
    }
  }

  function resolveStartupRestoreDecision(shouldRestore) {
    const resolver = startupRestoreDecisionResolver
    startupRestoreDecisionResolver = null
    setWelcomeRestorePromptSnapshot(null)
    if (typeof resolver === 'function') resolver(Boolean(shouldRestore))
  }

  async function requestWorkspaceRestoreDecision(snapshot) {
    if (!snapshot || !hasMeaningfulWorkspaceSnapshot(snapshot)) return false
    const title = '检测到上次会话'
    const message = `${getWorkspaceSnapshotSummary(snapshot, { getTabLabel })}\n\n是否恢复上次工作区？`

    if (getCurrentUISettings().showWelcomeScreen !== false && welcomeOverlayVisible && dom.welcomeRestorePrompt) {
      setWelcomeProgress(74, '检测到上次工作区，请选择是否恢复。', title)
      setWelcomeRestorePromptSnapshot(snapshot)
      return new Promise(resolve => {
        startupRestoreDecisionResolver = resolve
      })
    }

    return showConfirm({
      title,
      message,
      confirmText: '恢复上次会话',
      cancelText: '从空白开始'
    })
  }

  function syncWelcomePreferenceCheckboxes() {
    const enabled = getCurrentUISettings().showWelcomeScreen !== false
    if (dom.showWelcomeScreenToggle) dom.showWelcomeScreenToggle.checked = enabled
    if (dom.welcomeDisableCheckbox) dom.welcomeDisableCheckbox.checked = !enabled
  }

  function syncWelcomeStartButton() {
    if (!dom.closeWelcomeButton) return
    dom.closeWelcomeButton.disabled = !welcomeReady
    setButtonLabel(
      dom.closeWelcomeButton,
      welcomeReady ? (manualTutorialOpen ? '返回工作台' : '开始使用') : '正在准备...'
    )
  }

  function setWelcomeTutorialVisible(visible, { manual = false } = {}) {
    welcomeTutorialVisible = Boolean(visible)
    manualTutorialOpen = welcomeTutorialVisible && manual
    if (dom.welcomeTutorialBlock) {
      dom.welcomeTutorialBlock.classList.toggle('hidden', !welcomeTutorialVisible)
    }
  }

  function setWelcomeProgress(progress, text, title = text) {
    const safeProgress = Math.max(0, Math.min(100, Number(progress) || 0))
    if (dom.welcomeProgressFill) dom.welcomeProgressFill.style.width = `${safeProgress}%`
    if (dom.welcomeProgressPercent) dom.welcomeProgressPercent.textContent = `${Math.round(safeProgress)}%`
    if (dom.welcomeProgressText) dom.welcomeProgressText.textContent = text
    if (dom.welcomeProgressTitle) dom.welcomeProgressTitle.textContent = title
  }

  function showWelcomeOverlay({ force = false, tutorialMode = false, manualTutorial = false } = {}) {
    if (!dom.welcomeOverlay || (!force && getCurrentUISettings().showWelcomeScreen === false)) return
    welcomeOverlayVisible = true
    welcomeReady = manualTutorial ? true : false
    setWelcomeTutorialVisible(tutorialMode, { manual: manualTutorial })
    setWelcomeRestorePromptSnapshot(null)
    dom.welcomeOverlay.classList.remove('hidden')
    document.body.classList.add('welcome-open')
    if (manualTutorial) {
      const appName = String(getCurrentAppInfo()?.name || 'WordZ')
      setWelcomeProgress(100, `教程已准备好，点击“返回工作台”继续使用 ${appName}。`, '首次使用教程')
    }
    syncWelcomePreferenceCheckboxes()
    syncWelcomeStartButton()
  }

  function hideWelcomeOverlay({ immediate = false } = {}) {
    void immediate
    if (!dom.welcomeOverlay || !welcomeOverlayVisible) return
    dom.welcomeOverlay.classList.add('hidden')
    document.body.classList.remove('welcome-open')
    welcomeOverlayVisible = false
    setWelcomeTutorialVisible(false)
    setWelcomeRestorePromptSnapshot(null)
  }

  function markWelcomeReady() {
    welcomeReady = true
    const appName = String(getCurrentAppInfo()?.name || 'WordZ')
    setWelcomeProgress(100, `准备完成，点击“开始使用”进入 ${appName}。`, '工作台已准备就绪')
    syncWelcomeStartButton()
  }

  function getAutoUpdateButtonLabel(updateState) {
    if (!updateState) return '更新'
    if (updateState.state === 'disabled') return '更新已关闭'
    if (updateState.state === 'checking') return '检查中...'
    if (updateState.state === 'downloading') {
      const progressPercent = Math.round(Number(updateState.progressPercent) || 0)
      return progressPercent > 0 ? `下载 ${progressPercent}%` : '下载中...'
    }
    if (updateState.state === 'downloaded') return '安装更新'
    if (updateState.state === 'up-to-date') return '已是最新'
    return '更新'
  }

  function applyAutoUpdateButtonState(updateState = null) {
    if (!dom.checkUpdateButton) return
    currentAutoUpdateState = updateState
    setButtonLabel(dom.checkUpdateButton, getAutoUpdateButtonLabel(updateState))
    dom.checkUpdateButton.disabled = updateState?.state === 'checking' || updateState?.state === 'downloading'
  }

  async function promptInstallDownloadedUpdate(updateState = currentAutoUpdateState, { force = false } = {}) {
    if (!updateState || updateState.state !== 'downloaded') return
    const targetVersion = updateState.downloadedVersion || updateState.availableVersion || ''
    if (!force && targetVersion && promptedDownloadedVersion === targetVersion) return
    if (targetVersion) promptedDownloadedVersion = targetVersion

    const releaseNotes = Array.isArray(updateState.releaseNotes) ? updateState.releaseNotes : []
    const messageLines = [
      `新版本 ${targetVersion || '已下载完成'} 已准备好。`,
      '现在重启应用即可完成安装。'
    ]
    if (releaseNotes.length > 0) {
      messageLines.push('', '更新内容')
      for (const item of releaseNotes.slice(0, 5)) {
        messageLines.push(`- ${item}`)
      }
    }

    const confirmed = await showConfirm({
      title: '安装更新',
      message: messageLines.join('\n'),
      confirmText: '立即重启安装',
      cancelText: '稍后'
    })
    if (!confirmed) return

    const result = await electronAPI.installDownloadedUpdate()
    if (!result.success) {
      await showAlert({
        title: '安装更新失败',
        message: result.message || '当前无法安装更新'
      })
    }
  }

  async function handleAutoUpdateStatus(updateState, { announce = true, promptOnDownloaded = false } = {}) {
    applyAutoUpdateButtonState(updateState)
    if (!updateState) return

    if (updateState.state === 'downloaded') {
      void setWindowAttentionState({
        source: 'auto-update',
        count: 1,
        description: updateState.downloadedVersion
          ? `WordZ ${updateState.downloadedVersion} 已下载完成`
          : 'WordZ 新版本已下载完成',
        priority: 80,
        requestAttention: announce,
        category: 'update-downloaded'
      })
    } else {
      void setWindowAttentionState({
        source: 'auto-update',
        state: 'none'
      })
    }

    if (announce) {
      if (updateState.state === 'downloading' && updateState.availableVersion && announcedAvailableVersion !== updateState.availableVersion) {
        announcedAvailableVersion = updateState.availableVersion
        showToast(`发现新版本 ${updateState.availableVersion}，正在后台下载。`, {
          title: '自动更新',
          type: 'success',
          duration: 3600
        })
      }

      if (updateState.state === 'error' && updateState.enabled) {
        showToast(updateState.message || '自动更新失败。', {
          title: '更新失败',
          type: 'error',
          duration: 4200
        })
      }
    }

    if (announce && updateState.state === 'downloaded') {
      void notifySystem({
        title: '更新已下载完成',
        body: updateState.downloadedVersion
          ? `WordZ ${updateState.downloadedVersion} 已准备好，重启应用即可安装。`
          : '新版本已经下载完成，重启应用即可安装。',
        tag: 'update-downloaded',
        category: 'update-downloaded',
        action: 'prompt-install-update'
      })
    }

    if (promptOnDownloaded && updateState.state === 'downloaded') {
      await promptInstallDownloadedUpdate(updateState)
    }
  }

  async function initializeAutoUpdate() {
    if (!electronAPI?.getAutoUpdateState) {
      applyAutoUpdateButtonState(null)
      return
    }

    const stateResult = await electronAPI.getAutoUpdateState()
    if (stateResult?.success && stateResult.updateState) {
      await handleAutoUpdateStatus(stateResult.updateState, { announce: false, promptOnDownloaded: false })
    } else {
      applyAutoUpdateButtonState(null)
    }

    if (electronAPI?.onAutoUpdateStatus) {
      electronAPI.onAutoUpdateStatus(updateState => {
        void handleAutoUpdateStatus(updateState, { announce: true, promptOnDownloaded: true })
      })
    }
  }

  return {
    applyAutoUpdateButtonState,
    getCurrentAutoUpdateState: () => currentAutoUpdateState,
    hasPendingWorkspaceRestoreSnapshot: () => Boolean(pendingWorkspaceRestoreSnapshot),
    hideWelcomeOverlay,
    initializeAutoUpdate,
    isWelcomeOverlayVisible: () => welcomeOverlayVisible,
    isWelcomeReady: () => welcomeReady,
    isWelcomeTutorialVisible: () => welcomeTutorialVisible,
    markWelcomeReady,
    promptInstallDownloadedUpdate,
    requestWorkspaceRestoreDecision,
    resolveStartupRestoreDecision,
    setWelcomeProgress,
    showWelcomeOverlay,
    syncWelcomePreferenceCheckboxes
  }
}
