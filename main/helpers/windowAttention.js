function clampCount(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return 0
  return Math.min(Math.max(Math.trunc(numericValue), 0), 99)
}

function normalizeDescription(value) {
  return String(value || '').trim().slice(0, 120)
}

function escapeSvgText(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function createOverlayIcon(nativeImage, count) {
  if (!nativeImage || typeof nativeImage.createFromDataURL !== 'function') return null
  const safeCount = clampCount(count)
  if (!safeCount) return null

  const displayText = safeCount >= 99 ? '99+' : String(safeCount)
  const fontSize = displayText.length >= 3 ? 12 : 14
  const svg = [
    '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">',
    '<circle cx="16" cy="16" r="14" fill="#d93025"/>',
    `<text x="16" y="20" text-anchor="middle" font-family="Segoe UI, Arial, sans-serif" font-size="${fontSize}" font-weight="700" fill="#ffffff">${escapeSvgText(displayText)}</text>`,
    '</svg>'
  ].join('')
  const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg, 'utf8').toString('base64')}`
  const image = nativeImage.createFromDataURL(dataUrl)
  if (!image || image.isEmpty?.()) return null
  if (typeof image.resize === 'function') {
    return image.resize({ width: 16, height: 16 })
  }
  return image
}

function resolveAttentionDescription(entry, appName = 'WordZ') {
  const description = normalizeDescription(entry?.description)
  if (description) return description
  const count = clampCount(entry?.count)
  return count > 0 ? `${appName} 有 ${count} 项待处理` : `${appName} 提醒`
}

function createWindowAttentionController({
  app,
  nativeImage,
  appName = 'WordZ',
  platform = process.platform,
  getWindows = () => [],
  logger = console,
  onApply = null
} = {}) {
  const sourceStates = new Map()
  let sequence = 0
  let lastBouncedAt = 0

  function getWinningEntry() {
    const entries = [...sourceStates.values()]
    if (entries.length === 0) return null
    entries.sort((left, right) => {
      if (right.priority !== left.priority) return right.priority - left.priority
      return right.sequence - left.sequence
    })
    return entries[0]
  }

  function applyMacDockAttention(entry) {
    if (platform !== 'darwin' || !app?.dock) return
    const count = clampCount(entry?.count)
    const badgeText = count > 0 ? String(count) : ''
    try {
      app.dock.setBadge?.(badgeText)
    } catch (error) {
      logger.warn?.('[window-attention.dock.badge]', error)
    }

    if (count <= 0 || !entry?.requestAttention) return
    const now = Date.now()
    if (now - lastBouncedAt < 3000) return
    lastBouncedAt = now
    try {
      app.dock.bounce?.('informational')
    } catch (error) {
      logger.warn?.('[window-attention.dock.bounce]', error)
    }
  }

  function applyWindowsOverlay(entry) {
    if (platform !== 'win32') return
    const count = clampCount(entry?.count)
    const overlayIcon = count > 0 ? createOverlayIcon(nativeImage, count) : null
    const description = count > 0 ? resolveAttentionDescription(entry, appName) : ''

    for (const win of getWindows()) {
      if (!win || win.isDestroyed?.()) continue
      try {
        win.setOverlayIcon?.(overlayIcon, description)
      } catch (error) {
        logger.warn?.('[window-attention.overlay]', error)
      }
    }
  }

  function applyAttention() {
    const winningEntry = getWinningEntry()
    applyMacDockAttention(winningEntry)
    applyWindowsOverlay(winningEntry)

    onApply?.({
      winningEntry: winningEntry
        ? {
            source: winningEntry.source,
            count: clampCount(winningEntry.count),
            description: resolveAttentionDescription(winningEntry, appName),
            priority: winningEntry.priority,
            requestAttention: Boolean(winningEntry.requestAttention)
          }
        : null,
      activeSourceCount: sourceStates.size
    })
  }

  function updateSource(source, patch = {}) {
    const key = String(source || '').trim()
    if (!key) return false

    const count = clampCount(patch.count)
    if (patch.state === 'none' || count <= 0) {
      sourceStates.delete(key)
      applyAttention()
      return true
    }

    const currentEntry = sourceStates.get(key) || {}
    sourceStates.set(key, {
      source: key,
      count,
      description: normalizeDescription(patch.description || currentEntry.description || ''),
      priority: Number.isFinite(Number(patch.priority)) ? Number(patch.priority) : (currentEntry.priority || 0),
      requestAttention: patch.requestAttention === true,
      sequence: ++sequence
    })
    applyAttention()
    return true
  }

  function clearSource(source) {
    return updateSource(source, { state: 'none' })
  }

  function clearAll() {
    sourceStates.clear()
    applyAttention()
  }

  return {
    updateSource,
    clearSource,
    clearAll
  }
}

module.exports = {
  createWindowAttentionController
}
