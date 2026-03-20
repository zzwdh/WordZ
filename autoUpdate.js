function normalizeBoolean(value, fallbackValue) {
  if (value === undefined || value === null || value === '') return fallbackValue
  const normalizedValue = String(value).trim().toLowerCase()
  if (['1', 'true', 'yes', 'on'].includes(normalizedValue)) return true
  if (['0', 'false', 'no', 'off'].includes(normalizedValue)) return false
  return fallbackValue
}

function normalizeText(value, fallbackValue = '') {
  return String(value ?? fallbackValue).trim()
}

function normalizeInteger(value, fallbackValue, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return fallbackValue
  return Math.min(Math.max(Math.trunc(numericValue), min), max)
}

function normalizeUrl(value) {
  const rawValue = String(value || '').trim()
  if (!rawValue) return ''

  try {
    const parsedUrl = new URL(rawValue)
    return parsedUrl.toString().replace(/\/+$/, '')
  } catch {
    return ''
  }
}

function getReleaseChannelLabel(releaseChannel) {
  return '稳定版'
}

function normalizeReleaseNotes(releaseNotes) {
  if (!releaseNotes) return []
  if (typeof releaseNotes === 'string') {
    return releaseNotes
      .split(/\r?\n/)
      .map(item => item.replace(/^[\s*-]+/, '').trim())
      .filter(Boolean)
  }
  if (Array.isArray(releaseNotes)) {
    return releaseNotes
      .map(item => {
        if (typeof item === 'string') return item.trim()
        if (item && typeof item.note === 'string') return item.note.trim()
        return ''
      })
      .filter(Boolean)
  }
  return []
}

function parseGitHubRepository(repository) {
  const rawValue =
    typeof repository === 'string'
      ? repository
      : repository && typeof repository.url === 'string'
        ? repository.url
        : ''
  const normalizedValue = normalizeText(rawValue)
  if (!normalizedValue) {
    return {
      owner: '',
      repo: ''
    }
  }

  const cleanedValue = normalizedValue.replace(/^git\+/, '').replace(/\.git$/i, '').replace(/\/+$/, '')
  const match = cleanedValue.match(
    /^(?:https?:\/\/github\.com\/|ssh:\/\/git@github\.com\/|git@github\.com:|github:)?([^/\s]+)\/([^/\s]+)$/i
  )

  if (!match) {
    return {
      owner: '',
      repo: ''
    }
  }

  return {
    owner: normalizeText(match[1]),
    repo: normalizeText(match[2])
  }
}

function getAutoUpdateProviderLabel(provider) {
  if (provider === 'github') return 'GitHub Releases'
  if (provider === 'generic') return '通用更新源'
  return normalizeText(provider) || '未知更新源'
}

function getAutoUpdateTargetLabel({ provider, url = '', github = {} } = {}) {
  if (provider === 'generic') return normalizeText(url)
  if (provider === 'github') {
    const owner = normalizeText(github.owner)
    const repo = normalizeText(github.repo)
    return owner && repo ? `${owner}/${repo}` : ''
  }
  return ''
}

function getPackageAutoUpdateMeta(packageManifest = {}) {
  const wordzMeta = packageManifest.wordz && typeof packageManifest.wordz === 'object'
    ? packageManifest.wordz
    : {}
  const autoUpdateMeta = wordzMeta.autoUpdate && typeof wordzMeta.autoUpdate === 'object'
    ? wordzMeta.autoUpdate
    : {}
  const releaseMeta = wordzMeta.release && typeof wordzMeta.release === 'object'
    ? wordzMeta.release
    : {}
  const parsedRepository = parseGitHubRepository(packageManifest.repository)
  const githubMeta = autoUpdateMeta.github && typeof autoUpdateMeta.github === 'object'
    ? autoUpdateMeta.github
    : {}
  const releaseChannel = String(releaseMeta.channel || 'stable').trim() || 'stable'
  const autoUpdateChannel = String(autoUpdateMeta.channel || 'latest').trim() || 'latest'
  const allowPrerelease = normalizeBoolean(autoUpdateMeta.allowPrerelease, false)

  return {
    enabled: normalizeBoolean(autoUpdateMeta.enabled, true),
    provider: String(autoUpdateMeta.provider || 'generic').trim() || 'generic',
    url: normalizeUrl(autoUpdateMeta.url),
    channel: autoUpdateChannel,
    releaseChannel,
    releaseChannelLabel: getReleaseChannelLabel(releaseChannel),
    checkOnLaunch: normalizeBoolean(autoUpdateMeta.checkOnLaunch, true),
    autoDownload: normalizeBoolean(autoUpdateMeta.autoDownload, true),
    allowPrerelease,
    checkDelayMs: normalizeInteger(autoUpdateMeta.checkDelayMs, 12000, { min: 0, max: 300000 }),
    github: {
      owner: normalizeText(githubMeta.owner || parsedRepository.owner),
      repo: normalizeText(githubMeta.repo || parsedRepository.repo),
      private: normalizeBoolean(githubMeta.private, false)
    }
  }
}

function resolveAutoUpdateConfig({ packageManifest = {}, env = process.env, isPackaged = false, platform = process.platform } = {}) {
  const packageConfig = getPackageAutoUpdateMeta(packageManifest)
  const provider = String(env.WORDZ_AUTO_UPDATE_PROVIDER || packageConfig.provider || 'generic').trim() || 'generic'
  const url = normalizeUrl(env.WORDZ_AUTO_UPDATE_URL || packageConfig.url)
  const channel = 'latest'
  const enabled = normalizeBoolean(env.WORDZ_AUTO_UPDATE_ENABLED, packageConfig.enabled)
  const checkOnLaunch = normalizeBoolean(env.WORDZ_AUTO_UPDATE_CHECK_ON_LAUNCH, packageConfig.checkOnLaunch)
  const autoDownload = normalizeBoolean(env.WORDZ_AUTO_UPDATE_AUTO_DOWNLOAD, packageConfig.autoDownload)
  const allowPrerelease = normalizeBoolean(env.WORDZ_AUTO_UPDATE_ALLOW_PRERELEASE, packageConfig.allowPrerelease)
  const checkDelayMs = normalizeInteger(env.WORDZ_AUTO_UPDATE_CHECK_DELAY_MS, packageConfig.checkDelayMs, {
    min: 0,
    max: 300000
  })
  const github = {
    owner: normalizeText(env.WORDZ_AUTO_UPDATE_GITHUB_OWNER || env.WORDZ_GH_OWNER || packageConfig.github.owner),
    repo: normalizeText(env.WORDZ_AUTO_UPDATE_GITHUB_REPO || env.WORDZ_GH_REPO || packageConfig.github.repo),
    private: normalizeBoolean(env.WORDZ_AUTO_UPDATE_GITHUB_PRIVATE || env.WORDZ_GH_PRIVATE, packageConfig.github.private)
  }
  const configured =
    provider === 'github'
      ? Boolean(github.owner && github.repo)
      : provider === 'generic'
        ? Boolean(url)
        : false
  const providerLabel = getAutoUpdateProviderLabel(provider)
  const targetLabel = getAutoUpdateTargetLabel({ provider, url, github })

  let disableReason = ''
  if (!enabled) {
    disableReason = '自动更新已在配置中关闭。'
  } else if (!isPackaged) {
    disableReason = '当前是开发环境，自动更新仅在打包后的应用中启用。'
  } else if (!['darwin', 'win32'].includes(platform)) {
    disableReason = '当前平台暂未启用自动更新。'
  } else if (!['generic', 'github'].includes(provider)) {
    disableReason = '当前自动更新 provider 不受支持。'
  } else if (provider === 'generic' && !url) {
    disableReason = '尚未配置自动更新地址。'
  } else if (provider === 'github' && !(github.owner && github.repo)) {
    disableReason = '尚未配置 GitHub Releases 仓库（owner/repo）。'
  }

  return {
    enabled: enabled && !disableReason,
    configured,
    provider,
    providerLabel,
    targetLabel,
    url,
    channel,
    releaseChannel: 'stable',
    releaseChannelLabel: getReleaseChannelLabel('stable'),
    github,
    checkOnLaunch,
    autoDownload,
    allowPrerelease,
    checkDelayMs,
    disableReason: disableReason || ''
  }
}

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
