import {
  APP_FEATURE_SUMMARY,
  APP_SUBTITLE_TEXT,
  DEFAULT_APP_INFO,
  HELP_CENTER_QUICK_LINK_NOTE
} from './constants.mjs'

function setText(target, text) {
  if (target) target.textContent = text
}

function buildVersionLabel(appInfo) {
  return appInfo.version ? `当前版本 v${appInfo.version}` : '正在读取版本...'
}

function setHelpCenterList(target, items, emptyText) {
  if (!target) return

  target.replaceChildren()
  if (!Array.isArray(items) || items.length === 0) {
    const emptyNode = document.createElement('div')
    emptyNode.className = 'empty-tip'
    emptyNode.textContent = emptyText
    target.append(emptyNode)
    return
  }

  for (const item of items) {
    const listItem = document.createElement('div')
    listItem.className = 'help-center-list-item'
    listItem.textContent = item
    target.append(listItem)
  }
}

export function normalizeAppInfo(rawInfo = {}) {
  const normalizedName = String(rawInfo.name || '').trim() || DEFAULT_APP_INFO.name
  return {
    ...DEFAULT_APP_INFO,
    ...rawInfo,
    name: normalizedName,
    version: String(rawInfo.version || '').trim(),
    description: String(rawInfo.description || '').trim(),
    author: String(rawInfo.author || '').trim(),
    repositoryUrl: String(rawInfo.repositoryUrl || '').trim(),
    releaseChannel: String(rawInfo.releaseChannel || 'stable').trim() || 'stable',
    releaseChannelLabel: String(rawInfo.releaseChannelLabel || '稳定版').trim() || '稳定版',
    autoUpdateConfigured: Boolean(rawInfo.autoUpdateConfigured),
    autoUpdateProvider: String(rawInfo.autoUpdateProvider || '').trim(),
    autoUpdateProviderLabel: String(rawInfo.autoUpdateProviderLabel || '').trim(),
    autoUpdateTarget: String(rawInfo.autoUpdateTarget || '').trim(),
    help: Array.isArray(rawInfo.help)
      ? rawInfo.help.map(item => String(item).trim()).filter(Boolean)
      : [],
    releaseNotes: Array.isArray(rawInfo.releaseNotes)
      ? rawInfo.releaseNotes.map(item => String(item).trim()).filter(Boolean)
      : []
  }
}

export function getAppAboutDescription(appInfo = DEFAULT_APP_INFO) {
  const description = String(appInfo.description || '').trim()
  if (!description || description === appInfo.name) {
    return '一个本地桌面语料分析工具。'
  }
  return description
}

export function applyAppInfoToShell(appInfo = DEFAULT_APP_INFO, dom) {
  const normalizedInfo = normalizeAppInfo(appInfo)
  const versionLabel = buildVersionLabel(normalizedInfo)

  document.title = normalizedInfo.name
  setText(dom?.appTitleHeading, normalizedInfo.name)
  setText(dom?.appSubtitle, APP_SUBTITLE_TEXT)
  setText(dom?.settingsPreviewText, `${normalizedInfo.name} Corpus Helper 123 ABC。这里会实时预览你当前选择的字体和字号效果。`)
  setText(dom?.welcomeTitle, `欢迎使用 ${normalizedInfo.name}`)
  setText(dom?.welcomeSubtitle, getAppAboutDescription(normalizedInfo))
  setText(dom?.welcomeFeatureSummary, APP_FEATURE_SUMMARY)
  setText(dom?.topbarVersionBadge, versionLabel)
  setText(dom?.welcomeVersionBadge, versionLabel)
}

export function renderHelpCenter(appInfo = DEFAULT_APP_INFO, dom) {
  const normalizedInfo = normalizeAppInfo(appInfo)
  setText(dom?.helpCenterTitle, `${normalizedInfo.name} 帮助中心`)
  setText(dom?.helpCenterSummary, `${getAppAboutDescription(normalizedInfo)} ${HELP_CENTER_QUICK_LINK_NOTE}`)
  setText(
    dom?.helpCenterVersionChip,
    normalizedInfo.version
      ? `当前版本 v${normalizedInfo.version} · ${normalizedInfo.releaseChannelLabel || '稳定版'}`
      : `当前版本 · ${normalizedInfo.releaseChannelLabel || '稳定版'}`
  )
  setText(
    dom?.helpCenterAuthorChip,
    normalizedInfo.author ? `作者：${normalizedInfo.author}` : '作者信息未配置'
  )
  setText(
    dom?.helpCenterRepositoryUrl,
    normalizedInfo.repositoryUrl || '当前版本未配置 GitHub 地址'
  )

  if (dom?.openGitHubRepoButton) {
    dom.openGitHubRepoButton.disabled = !normalizedInfo.repositoryUrl
  }

  setHelpCenterList(dom?.helpCenterHelpList, normalizedInfo.help, '当前版本没有额外帮助说明。')
  setHelpCenterList(dom?.helpCenterReleaseList, normalizedInfo.releaseNotes, '当前版本没有额外发布说明。')
}
