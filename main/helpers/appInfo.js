function getRepositoryUrl(packageManifest) {
  return String(
    typeof packageManifest.repository === 'string'
      ? packageManifest.repository
      : packageManifest.repository && typeof packageManifest.repository.url === 'string'
        ? packageManifest.repository.url
        : ''
  )
    .trim()
    .replace(/^git\+/, '')
    .replace(/\.git$/i, '')
    .replace(/\/+$/, '')
}

function getAuthorName(packageManifest) {
  return typeof packageManifest.author === 'string'
    ? packageManifest.author
    : packageManifest.author && typeof packageManifest.author.name === 'string'
      ? packageManifest.author.name
      : ''
}

function getAppInfo({ app, packageManifest, autoUpdateController }) {
  const autoUpdateSnapshot = autoUpdateController?.getStatusSnapshot?.() || {}
  const repositoryUrl = getRepositoryUrl(packageManifest)
  const author = getAuthorName(packageManifest)
  const wordzMeta =
    packageManifest.wordz && typeof packageManifest.wordz === 'object'
      ? packageManifest.wordz
      : {}
  const releaseMeta = wordzMeta.release && typeof wordzMeta.release === 'object'
    ? wordzMeta.release
    : {}
  const help = Array.isArray(wordzMeta.help)
    ? wordzMeta.help.map(item => String(item).trim()).filter(Boolean)
    : []
  const releaseChannel = String(autoUpdateSnapshot.releaseChannel || releaseMeta.channel || 'stable').trim() || 'stable'
  const releaseChannelLabel = String(
    autoUpdateSnapshot.releaseChannelLabel ||
    (releaseChannel === 'stable' ? '稳定版' : releaseChannel)
  ).trim() || '稳定版'

  return {
    name: packageManifest.productName || app.getName() || packageManifest.name || 'WordZ',
    version: app.getVersion() || packageManifest.version || '',
    description: packageManifest.description || '',
    author,
    repositoryUrl,
    help,
    autoUpdateConfigured: Boolean(autoUpdateSnapshot.configured),
    autoUpdateProvider: String(autoUpdateSnapshot.provider || '').trim(),
    autoUpdateProviderLabel: String(autoUpdateSnapshot.providerLabel || '').trim(),
    autoUpdateTarget: String(autoUpdateSnapshot.providerTarget || '').trim(),
    releaseChannel,
    releaseChannelLabel,
    releaseNotes: Array.isArray(wordzMeta.releaseNotes)
      ? wordzMeta.releaseNotes.map(item => String(item).trim()).filter(Boolean)
      : []
  }
}

module.exports = {
  getAppInfo
}
