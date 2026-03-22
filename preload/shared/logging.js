function writePreloadLog(scope, details = null) {
  try {
    if (details && typeof details === 'object') {
      console.warn(`[startup.preload] ${scope}`, JSON.stringify(details))
      return
    }
    console.warn(`[startup.preload] ${scope}`)
  } catch {
    // ignore preload logging failures
  }
}

function writePreloadError(scope, error, details = null) {
  const normalizedError = error instanceof Error ? error : new Error(String(error || 'Unknown preload error'))
  try {
    if (details && typeof details === 'object') {
      console.error(`[startup.preload] ${scope}`, {
        message: normalizedError.message,
        stack: normalizedError.stack || '',
        ...details
      })
      return
    }
    console.error(`[startup.preload] ${scope}`, normalizedError)
  } catch {
    // ignore preload logging failures
  }
}

function deepFreeze(value, seen = new WeakSet()) {
  if (!value || typeof value !== 'object') return value
  if (seen.has(value)) return value
  seen.add(value)
  Object.freeze(value)
  for (const nestedValue of Object.values(value)) {
    deepFreeze(nestedValue, seen)
  }
  return value
}

module.exports = {
  deepFreeze,
  writePreloadError,
  writePreloadLog
}
