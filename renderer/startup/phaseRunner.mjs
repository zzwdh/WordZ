const DEFAULT_MAX_EVENTS = 80

function getTimestampMs() {
  if (typeof globalThis.performance?.now === 'function') {
    return globalThis.performance.now()
  }
  return Date.now()
}

function normalizePhaseName(phaseName) {
  const normalized = String(phaseName || '').trim()
  return normalized || 'unknown-phase'
}

function normalizeErrorDetails(error) {
  if (error instanceof Error) {
    return {
      errorName: error.name || 'Error',
      errorMessage: error.message || '',
      errorStack: error.stack || ''
    }
  }
  return {
    errorName: 'Error',
    errorMessage: String(error || ''),
    errorStack: ''
  }
}

function cloneEvent(event) {
  return {
    ...event
  }
}

export function createStartupPhaseRunner({ maxEvents = DEFAULT_MAX_EVENTS, onEvent } = {}) {
  const safeMaxEvents = Number.isFinite(Number(maxEvents)) && Number(maxEvents) > 0
    ? Math.trunc(Number(maxEvents))
    : DEFAULT_MAX_EVENTS
  const events = []

  function emit(event) {
    events.push(cloneEvent(event))
    while (events.length > safeMaxEvents) {
      events.shift()
    }
    if (typeof onEvent === 'function') {
      try {
        onEvent(cloneEvent(event), events.map(cloneEvent))
      } catch {
        // ignore observer failures
      }
    }
  }

  function runSyncPhase(phaseName, task) {
    const phase = normalizePhaseName(phaseName)
    const startedAt = new Date().toISOString()
    const startedAtMs = getTimestampMs()
    emit({
      phase,
      status: 'started',
      startedAt
    })
    try {
      const result = typeof task === 'function' ? task() : undefined
      const durationMs = Math.max(0, getTimestampMs() - startedAtMs)
      emit({
        phase,
        status: 'completed',
        startedAt,
        endedAt: new Date().toISOString(),
        durationMs
      })
      return result
    } catch (error) {
      const durationMs = Math.max(0, getTimestampMs() - startedAtMs)
      emit({
        phase,
        status: 'failed',
        startedAt,
        endedAt: new Date().toISOString(),
        durationMs,
        ...normalizeErrorDetails(error)
      })
      throw error
    }
  }

  async function runPhase(phaseName, task) {
    const phase = normalizePhaseName(phaseName)
    const startedAt = new Date().toISOString()
    const startedAtMs = getTimestampMs()
    emit({
      phase,
      status: 'started',
      startedAt
    })
    try {
      const result = typeof task === 'function' ? await task() : undefined
      const durationMs = Math.max(0, getTimestampMs() - startedAtMs)
      emit({
        phase,
        status: 'completed',
        startedAt,
        endedAt: new Date().toISOString(),
        durationMs
      })
      return result
    } catch (error) {
      const durationMs = Math.max(0, getTimestampMs() - startedAtMs)
      emit({
        phase,
        status: 'failed',
        startedAt,
        endedAt: new Date().toISOString(),
        durationMs,
        ...normalizeErrorDetails(error)
      })
      throw error
    }
  }

  function getEvents() {
    return events.map(cloneEvent)
  }

  return {
    runSyncPhase,
    runPhase,
    getEvents
  }
}
