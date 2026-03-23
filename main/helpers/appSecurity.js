const { setupCustomAppProtocol } = require('./appProtocol')

const MIME_TYPE_BY_EXTENSION = Object.freeze({
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.bmp': 'image/bmp',
  '.txt': 'text/plain; charset=utf-8',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json; charset=utf-8'
})

const PROTOCOL_CACHEABLE_EXTENSIONS = new Set([
  '.html',
  '.css',
  '.js',
  '.mjs',
  '.json',
  '.svg',
  '.txt'
])

function createAppSecurityController({
  app,
  session,
  protocol,
  fs,
  fsSync,
  path,
  baseDir,
  indexHtmlPath,
  appProtocolScheme,
  appProtocolHost,
  fileAppEntryUrl,
  protocolAppEntryUrl,
  appEntryUrl,
  trustedDataUrlPrefix = 'data:text/html;charset=UTF-8,',
  protocolStartupAssets = [],
  enableCustomProtocol = true,
  responseCtor,
  appendEarlyCrashLog
}) {
  let appProtocolReady = false
  let appProtocolRequestLogCount = 0
  const protocolAssetCache = new Map()
  const maxProtocolCacheEntries = 120

  function normalizePathForTrustComparison(filePath) {
    const normalizedPath = path.normalize(String(filePath || ''))
    return process.platform === 'win32' ? normalizedPath.toLowerCase() : normalizedPath
  }

  function toFilePathFromUrl(rawUrl) {
    const urlText = String(rawUrl || '').trim()
    if (!urlText) return ''
    try {
      const parsedUrl = new URL(urlText)
      if (parsedUrl.protocol !== 'file:') return ''
      let filePath = decodeURIComponent(parsedUrl.pathname || '')
      if (process.platform === 'win32') {
        filePath = filePath.replace(/^\/([A-Za-z]:)/, '$1')
      }
      return path.normalize(filePath)
    } catch {
      return ''
    }
  }

  function isPathInsideDirectory(rootPath, targetPath) {
    const normalizedRoot = normalizePathForTrustComparison(path.resolve(String(rootPath || '')))
    const normalizedTarget = normalizePathForTrustComparison(path.resolve(String(targetPath || '')))
    if (!normalizedRoot || !normalizedTarget) return false
    if (normalizedTarget === normalizedRoot) return true
    return normalizedTarget.startsWith(`${normalizedRoot}${path.sep}`)
  }

  function getMimeTypeForFilePath(filePath) {
    const extension = path.extname(String(filePath || '')).toLowerCase()
    return MIME_TYPE_BY_EXTENSION[extension] || 'application/octet-stream'
  }

  function appendProtocolRequestLog(scope, requestUrl, targetPath, details = null) {
    if (appProtocolRequestLogCount >= 40) return
    appProtocolRequestLogCount += 1
    appendEarlyCrashLog(scope, 'protocol request', {
      requestUrl: String(requestUrl || ''),
      targetPath: String(targetPath || ''),
      ...(details && typeof details === 'object' ? details : {})
    })
  }

  function resolveProtocolAssetPath(requestUrl) {
    try {
      const parsedUrl = new URL(String(requestUrl || ''))
      if (parsedUrl.protocol !== `${appProtocolScheme}:`) return ''
      if (parsedUrl.hostname !== appProtocolHost) return ''

      let pathname = parsedUrl.pathname || '/'
      try {
        pathname = decodeURIComponent(pathname)
      } catch {
        pathname = parsedUrl.pathname || '/'
      }

      const normalizedPosixPath = path.posix.normalize(pathname)
      const relativePosixPath = normalizedPosixPath.replace(/^\/+/, '')
      const safeRelativePath = !relativePosixPath || relativePosixPath === '.'
        ? 'index.html'
        : relativePosixPath
      if (safeRelativePath.startsWith('..')) return ''

      const resolvedPath = path.resolve(baseDir, ...safeRelativePath.split('/'))
      if (!isPathInsideDirectory(baseDir, resolvedPath)) return ''
      return resolvedPath
    } catch {
      return ''
    }
  }

  function isProtocolCacheableAsset(targetPath) {
    const extension = path.extname(String(targetPath || '')).toLowerCase()
    return PROTOCOL_CACHEABLE_EXTENSIONS.has(extension)
  }

  function trimProtocolAssetCacheIfNeeded() {
    while (protocolAssetCache.size > maxProtocolCacheEntries) {
      const oldestCacheKey = protocolAssetCache.keys().next().value
      if (!oldestCacheKey) break
      protocolAssetCache.delete(oldestCacheKey)
    }
  }

  async function readProtocolAssetContent(targetPath) {
    const normalizedPath = path.resolve(String(targetPath || ''))
    const cachedContent = protocolAssetCache.get(normalizedPath)
    if (cachedContent) {
      protocolAssetCache.delete(normalizedPath)
      protocolAssetCache.set(normalizedPath, cachedContent)
      return cachedContent
    }

    const content = await fs.readFile(normalizedPath)
    if (isProtocolCacheableAsset(normalizedPath)) {
      protocolAssetCache.set(normalizedPath, content)
      trimProtocolAssetCacheIfNeeded()
    }
    return content
  }

  async function warmupProtocolAssetCache() {
    const warmupResult = {
      total: 0,
      cached: 0
    }
    for (const targetPath of protocolStartupAssets) {
      warmupResult.total += 1
      try {
        if (!fsSync.existsSync(targetPath)) continue
        await readProtocolAssetContent(targetPath)
        warmupResult.cached += 1
      } catch (error) {
        appendEarlyCrashLog('protocol.cache.warmup.error', error, {
          targetPath
        })
      }
    }
    appendEarlyCrashLog('protocol.cache.warmup.done', 'startup asset cache warmed', warmupResult)
  }

  function buildProtocolHeaders(targetPath) {
    return {
      'content-type': getMimeTypeForFilePath(targetPath),
      'cache-control': 'no-store',
      'access-control-allow-origin': '*',
      'cross-origin-resource-policy': 'same-origin'
    }
  }

  function registerProtocolScheme() {
    if (enableCustomProtocol) {
      try {
        protocol.registerSchemesAsPrivileged([
          {
            scheme: appProtocolScheme,
            privileges: {
              standard: true,
              secure: true,
              supportFetchAPI: true,
              corsEnabled: true,
              stream: true
            }
          }
        ])
      } catch (error) {
        appendEarlyCrashLog('protocol.scheme.register-error', error, {
          scheme: appProtocolScheme
        })
      }
      return
    }

    appendEarlyCrashLog('protocol.scheme.disabled', 'custom protocol disabled for this platform', {
      platform: process.platform,
      appEntryUrl
    })
  }

  async function setupAppProtocol() {
    return setupCustomAppProtocol({
      getIsReady: () => appProtocolReady,
      setIsReady: nextValue => {
        appProtocolReady = Boolean(nextValue)
      },
      enableCustomProtocol,
      protocol,
      responseCtor,
      scheme: appProtocolScheme,
      host: appProtocolHost,
      appEntryUrl,
      appendEarlyCrashLog,
      resolveProtocolAssetPath,
      appendProtocolRequestLog,
      readProtocolAssetContent,
      buildProtocolHeaders,
      warmupProtocolAssetCache
    })
  }

  function isTrustedAppEntryUrl(rawUrl) {
    const urlText = String(rawUrl || '').trim()
    if (!urlText) return false
    if (urlText === appEntryUrl) return true
    if (enableCustomProtocol && urlText === protocolAppEntryUrl) return true
    try {
      const parsedUrl = new URL(urlText)
      if (
        enableCustomProtocol &&
        parsedUrl.protocol === `${appProtocolScheme}:` &&
        parsedUrl.hostname === appProtocolHost
      ) {
        return true
      }
    } catch {
      // ignore parse failures and continue to file-path trust checks
    }
    if (urlText === fileAppEntryUrl) return true
    const filePath = toFilePathFromUrl(urlText)
    if (!filePath) return false
    return normalizePathForTrustComparison(filePath) === normalizePathForTrustComparison(indexHtmlPath)
  }

  function isTrustedNavigationTarget(targetUrl) {
    const normalizedTarget = String(targetUrl || '').trim()
    if (!normalizedTarget) return false
    if (normalizedTarget.startsWith(trustedDataUrlPrefix)) return true
    return isTrustedAppEntryUrl(normalizedTarget)
  }

  function configureSessionSecurity() {
    const currentSession = session.defaultSession
    if (!currentSession) return

    currentSession.setPermissionRequestHandler((_webContents, _permission, callback) => {
      callback(false)
    })
  }

  function isTrustedIpcSender(event) {
    const senderUrl = event?.senderFrame?.url || event?.sender?.getURL?.() || ''
    return isTrustedAppEntryUrl(senderUrl)
  }

  function assertTrustedIpcSender(event) {
    if (!isTrustedIpcSender(event)) {
      throw new Error('拒绝来自未受信任页面的请求')
    }
  }

  return {
    assertTrustedIpcSender,
    configureSessionSecurity,
    isTrustedAppEntryUrl,
    isTrustedNavigationTarget,
    registerProtocolScheme,
    setupAppProtocol
  }
}

module.exports = {
  createAppSecurityController
}
