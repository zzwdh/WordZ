const {
  normalizeReleaseNotes,
  resolveAutoUpdateConfig
} = require('./autoUpdate/config')

function createAutoUpdateController({
  app,
  packageManifest,
  env = process.env,
  platform = process.platform,
  getWindows = () => [],
  logger = console
}) {
  const config = resolveAutoUpdateConfig({
    packageManifest,
    env,
    isPackaged: Boolean(app?.isPackaged),
    platform
  })

  let updater = null
  let startupCheckTimer = null
  let status = {
    enabled: config.enabled,
    configured: config.configured,
    provider: config.provider,
    providerLabel: config.providerLabel,
    providerTarget: config.targetLabel,
    channel: config.channel,
    releaseChannel: config.releaseChannel,
    releaseChannelLabel: config.releaseChannelLabel,
    state: config.enabled ? 'idle' : 'disabled',
    message: config.enabled ? '自动更新已就绪。' : config.disableReason,
    currentVersion: typeof app?.getVersion === 'function' ? app.getVersion() : String(packageManifest?.version || ''),
    availableVersion: '',
    downloadedVersion: '',
    progressPercent: 0,
    releaseNotes: [],
    checkedAt: '',
    updateDownloaded: false
  }

  function getStatusSnapshot() {
    return { ...status, releaseNotes: [...status.releaseNotes] }
  }

  function broadcastStatus() {
    const snapshot = getStatusSnapshot()
    for (const win of getWindows()) {
      try {
        if (!win || win.isDestroyed?.()) continue
        win.webContents.send('auto-update-status', snapshot)
      } catch (error) {
        logger.warn?.('[auto-update.broadcast]', error)
      }
    }
  }

  function updateStatus(patch) {
    status = {
      ...status,
      ...patch,
      releaseNotes: Array.isArray(patch.releaseNotes) ? [...patch.releaseNotes] : status.releaseNotes
    }
    broadcastStatus()
  }

  function ensureUpdater() {
    if (updater || !config.enabled) return updater

    let UpdaterClass = null
    try {
      const updaterModule = require('electron-updater')
      if (platform === 'win32') {
        UpdaterClass = updaterModule.NsisUpdater
      } else if (platform === 'darwin') {
        UpdaterClass = updaterModule.MacUpdater
      }
    } catch (error) {
      logger.error?.('[auto-update.require]', error)
      updateStatus({
        enabled: false,
        state: 'disabled',
        message: '自动更新组件加载失败。'
      })
      return null
    }

    if (!UpdaterClass) {
      updateStatus({
        enabled: false,
        state: 'disabled',
        message: '当前平台暂未启用自动更新。'
      })
      return null
    }

    const updaterOptions =
      config.provider === 'github'
        ? {
            provider: 'github',
            owner: config.github.owner,
            repo: config.github.repo,
            private: config.github.private
          }
        : {
            provider: 'generic',
            url: config.url,
            channel: config.channel
          }

    updater = new UpdaterClass(updaterOptions)

    updater.autoDownload = config.autoDownload
    updater.autoInstallOnAppQuit = true
    updater.allowPrerelease = config.allowPrerelease
    updater.channel = config.channel
    updater.fullChangelog = false
    updater.logger = logger

    updater.on('checking-for-update', () => {
      updateStatus({
        state: 'checking',
        message: '正在检查更新...',
        progressPercent: 0,
        checkedAt: new Date().toISOString(),
        availableVersion: '',
        downloadedVersion: '',
        updateDownloaded: false,
        releaseNotes: []
      })
    })

    updater.on('update-available', updateInfo => {
      updateStatus({
        state: config.autoDownload ? 'downloading' : 'available',
        message: config.autoDownload
          ? `发现新版本 ${updateInfo?.version || ''}，正在后台下载。`
          : `发现新版本 ${updateInfo?.version || ''}。`,
        availableVersion: String(updateInfo?.version || ''),
        progressPercent: 0,
        releaseNotes: normalizeReleaseNotes(updateInfo?.releaseNotes)
      })
    })

    updater.on('update-not-available', () => {
      updateStatus({
        state: 'up-to-date',
        message: '当前已是最新版本。',
        availableVersion: '',
        downloadedVersion: '',
        progressPercent: 0,
        checkedAt: new Date().toISOString(),
        updateDownloaded: false,
        releaseNotes: []
      })
    })

    updater.on('download-progress', progress => {
      updateStatus({
        state: 'downloading',
        message: `正在下载更新 ${Math.round(Number(progress?.percent) || 0)}%。`,
        progressPercent: Math.min(Math.max(Number(progress?.percent) || 0, 0), 100)
      })
    })

    updater.on('update-downloaded', updateInfo => {
      updateStatus({
        state: 'downloaded',
        message: `新版本 ${updateInfo?.version || ''} 已下载完成，重启后即可安装。`,
        downloadedVersion: String(updateInfo?.version || ''),
        availableVersion: String(updateInfo?.version || status.availableVersion || ''),
        progressPercent: 100,
        checkedAt: new Date().toISOString(),
        updateDownloaded: true,
        releaseNotes: normalizeReleaseNotes(updateInfo?.releaseNotes)
      })
    })

    updater.on('error', error => {
      updateStatus({
        state: 'error',
        message: error?.message || '自动更新失败。',
        progressPercent: 0
      })
    })

    return updater
  }

  async function checkForUpdates() {
    if (!config.enabled) {
      return {
        success: false,
        disabled: true,
        message: config.disableReason || '自动更新未启用。',
        state: status.state
      }
    }

    const appUpdater = ensureUpdater()
    if (!appUpdater) {
      return {
        success: false,
        disabled: true,
        message: status.message,
        state: status.state
      }
    }

    if (status.state === 'checking' || status.state === 'downloading') {
      return {
        success: true,
        busy: true,
        message: status.message,
        state: status.state
      }
    }

    try {
      await appUpdater.checkForUpdates()
      return {
        success: true,
        message: status.message,
        state: status.state
      }
    } catch (error) {
      const message = error?.message || '自动更新失败。'
      updateStatus({
        state: 'error',
        message,
        progressPercent: 0
      })
      return {
        success: false,
        message,
        state: 'error'
      }
    }
  }

  function quitAndInstall() {
    if (status.state !== 'downloaded' || !updater) {
      return {
        success: false,
        message: '当前没有已下载完成的更新。'
      }
    }

    setTimeout(() => {
      updater.quitAndInstall(false, true)
    }, 120)

    return {
      success: true
    }
  }

  function initialize() {
    broadcastStatus()
    if (!config.enabled) return
    ensureUpdater()
    if (!config.checkOnLaunch) return

    startupCheckTimer = setTimeout(() => {
      checkForUpdates().catch(error => {
        logger.warn?.('[auto-update.startup-check]', error)
      })
    }, config.checkDelayMs)
  }

  function dispose() {
    if (startupCheckTimer) {
      clearTimeout(startupCheckTimer)
      startupCheckTimer = null
    }
  }

  return {
    initialize,
    dispose,
    checkForUpdates,
    quitAndInstall,
    getStatusSnapshot,
    broadcastStatus
  }
}

module.exports = {
  normalizeReleaseNotes,
  resolveAutoUpdateConfig,
  createAutoUpdateController
}
