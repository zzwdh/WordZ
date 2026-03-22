function clearExistingProtocolHandler(protocol, scheme) {
  if (!protocol || !scheme) return

  if (typeof protocol.unhandle === 'function') {
    try {
      protocol.unhandle(scheme)
      return
    } catch {
      // ignore stale handler cleanup errors
    }
  }

  if (typeof protocol.unregisterProtocol === 'function') {
    try {
      protocol.unregisterProtocol(scheme)
    } catch {
      // ignore deprecated cleanup errors on older Electron builds
    }
  }
}

async function setupCustomAppProtocol({
  getIsReady,
  setIsReady,
  enableCustomProtocol,
  protocol,
  responseCtor,
  scheme,
  host,
  appEntryUrl,
  appendEarlyCrashLog,
  resolveProtocolAssetPath,
  appendProtocolRequestLog,
  readProtocolAssetContent,
  buildProtocolHeaders,
  warmupProtocolAssetCache
}) {
  if (typeof getIsReady === 'function' && getIsReady()) return true

  if (!enableCustomProtocol) {
    appendEarlyCrashLog('protocol.setup.skipped', 'custom app protocol is disabled', {
      platform: process.platform,
      appEntryUrl
    })
    return true
  }

  try {
    clearExistingProtocolHandler(protocol, scheme)

    if (typeof protocol?.handle !== 'function') {
      appendEarlyCrashLog('protocol.handle.unavailable', 'protocol.handle is not available', {
        scheme
      })
      return false
    }

    if (typeof responseCtor !== 'function') {
      appendEarlyCrashLog('protocol.response.unavailable', 'global Response API is unavailable', {
        scheme
      })
      return false
    }

    protocol.handle(scheme, async request => {
      const requestUrl = String(request?.url || '')
      const targetPath = resolveProtocolAssetPath(requestUrl)
      appendProtocolRequestLog('protocol.handle.request', requestUrl, targetPath)
      if (!targetPath) {
        return new responseCtor('Forbidden', {
          status: 403,
          headers: { 'content-type': 'text/plain; charset=utf-8' }
        })
      }

      try {
        const content = await readProtocolAssetContent(targetPath)
        return new responseCtor(content, {
          status: 200,
          headers: buildProtocolHeaders(targetPath)
        })
      } catch (error) {
        appendEarlyCrashLog('protocol.request.error', error, {
          requestUrl,
          targetPath
        })
        return new responseCtor('Not Found', {
          status: 404,
          headers: { 'content-type': 'text/plain; charset=utf-8' }
        })
      }
    })

    await warmupProtocolAssetCache()

    if (typeof setIsReady === 'function') {
      setIsReady(true)
    }

    appendEarlyCrashLog('protocol.handle.ready', 'app protocol registered', {
      scheme,
      host,
      appEntryUrl
    })
    return true
  } catch (error) {
    appendEarlyCrashLog('protocol.setup.error', error, {
      scheme,
      host
    })
    return false
  }
}

module.exports = {
  setupCustomAppProtocol
}
