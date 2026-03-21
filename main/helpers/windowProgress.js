function clampProgress(value) {
  const numericValue = Number(value)
  if (!Number.isFinite(numericValue)) return 0
  return Math.min(Math.max(numericValue, 0), 1)
}

function resolveProgressPayload(entry, platform) {
  if (!entry) {
    return {
      progress: -1,
      options: undefined
    }
  }

  if (entry.state === 'indeterminate') {
    return {
      progress: 2,
      options: platform === 'win32' ? { mode: 'indeterminate' } : undefined
    }
  }

  if (entry.state === 'paused') {
    return {
      progress: clampProgress(entry.progress),
      options: platform === 'win32' ? { mode: 'paused' } : undefined
    }
  }

  if (entry.state === 'error') {
    return {
      progress: clampProgress(entry.progress || 1),
      options: platform === 'win32' ? { mode: 'error' } : undefined
    }
  }

  return {
    progress: clampProgress(entry.progress),
    options: platform === 'win32' ? { mode: 'normal' } : undefined
  }
}

function createWindowProgressController({
  platform = process.platform,
  getWindows = () => [],
  logger = console,
  onApply = null
} = {}) {
  const sourceStates = new Map()
  let sequence = 0

  function getWinningEntry() {
    const entries = [...sourceStates.values()]
    if (entries.length === 0) return null
    entries.sort((left, right) => {
      if (right.priority !== left.priority) return right.priority - left.priority
      return right.sequence - left.sequence
    })
    return entries[0]
  }

  function applyProgressToWindows() {
    const winningEntry = getWinningEntry()
    const payload = resolveProgressPayload(winningEntry, platform)

    for (const win of getWindows()) {
      try {
        if (!win || win.isDestroyed?.()) continue
        win.setProgressBar(payload.progress, payload.options)
      } catch (error) {
        logger.warn?.('[window-progress.apply]', error)
      }
    }

    onApply?.({
      winningEntry: winningEntry
        ? {
            source: winningEntry.source,
            state: winningEntry.state,
            progress: winningEntry.progress,
            priority: winningEntry.priority
          }
        : null,
      payload,
      activeSourceCount: sourceStates.size
    })
  }

  function updateSource(source, patch = {}) {
    const key = String(source || '').trim()
    if (!key) return false

    if (patch.state === 'none') {
      sourceStates.delete(key)
      applyProgressToWindows()
      return true
    }

    const currentEntry = sourceStates.get(key) || {}
    sourceStates.set(key, {
      source: key,
      state: String(patch.state || currentEntry.state || 'indeterminate').trim() || 'indeterminate',
      progress: patch.progress ?? currentEntry.progress ?? 0,
      priority: Number.isFinite(Number(patch.priority)) ? Number(patch.priority) : (currentEntry.priority || 0),
      sequence: ++sequence
    })
    applyProgressToWindows()
    return true
  }

  function clearSource(source) {
    return updateSource(source, { state: 'none' })
  }

  function clearAll() {
    sourceStates.clear()
    applyProgressToWindows()
  }

  return {
    updateSource,
    clearSource,
    clearAll
  }
}

module.exports = {
  createWindowProgressController
}
