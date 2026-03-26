function normalizeWindowDocumentPayload(payload = {}) {
  return {
    representedPath: String(payload?.representedPath || '').trim(),
    displayName: String(payload?.displayName || '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 160),
    edited: payload?.edited === true
  }
}

function createUnavailableResult(message = '当前桌面宿主不支持窗口文档状态。') {
  return {
    success: false,
    message
  }
}

export function createWindowDocumentController({
  electronAPI,
  debounceMs = 380
}) {
  let timer = null
  let state = normalizeWindowDocumentPayload()
  let lastSentKey = ''

  function getPayloadKey(payload = state) {
    return JSON.stringify(payload)
  }

  function getState() {
    return { ...state }
  }

  async function flush() {
    if (timer) {
      clearTimeout(timer)
      timer = null
    }

    if (!electronAPI?.setWindowDocumentState) {
      return createUnavailableResult()
    }

    const payload = getState()
    const payloadKey = getPayloadKey(payload)
    if (payloadKey === lastSentKey) {
      return {
        success: true,
        skipped: true,
        documentState: payload
      }
    }

    try {
      const result = await electronAPI.setWindowDocumentState(payload)
      if (result?.success) {
        lastSentKey = payloadKey
      }
      return result || createUnavailableResult()
    } catch (error) {
      return {
        success: false,
        message: String(error?.message || '窗口文档状态同步失败')
      }
    }
  }

  function scheduleFlush({ immediate = false } = {}) {
    if (timer) {
      clearTimeout(timer)
      timer = null
    }

    if (immediate) {
      return flush()
    }

    timer = setTimeout(() => {
      timer = null
      void flush()
    }, Math.max(0, Number(debounceMs) || 0))

    return Promise.resolve({
      success: true,
      scheduled: true,
      documentState: getState()
    })
  }

  function syncDocumentState(partialPayload = {}, options = {}) {
    const nextState = normalizeWindowDocumentPayload({
      ...state,
      ...partialPayload
    })
    const nextStateKey = getPayloadKey(nextState)
    const currentStateKey = getPayloadKey(state)
    state = nextState

    if (nextStateKey === currentStateKey && !options?.immediate) {
      return Promise.resolve({
        success: true,
        skipped: true,
        documentState: getState()
      })
    }

    return scheduleFlush(options)
  }

  function setEdited(edited, options = {}) {
    return syncDocumentState(
      {
        edited: edited === true
      },
      options
    )
  }

  function clear(options = {}) {
    return syncDocumentState(
      {
        representedPath: '',
        displayName: '',
        edited: false
      },
      options
    )
  }

  return {
    clear,
    flush,
    getState,
    setEdited,
    syncDocumentState
  }
}
