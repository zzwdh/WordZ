function createWindowBridgeController({
  app,
  focusWindow,
  extractLaunchFilePaths,
  normalizeSupportedCorpusFilePath,
  captureMainError,
  getPrimaryWindow,
  createWindowSafely,
  ensurePrimaryWindow
}) {
  let systemOpenBridgeReady = false
  const pendingSystemOpenFilePaths = []
  const pendingAppMenuActions = []
  const pendingSystemNotificationActions = []

  function queueSystemOpenFilePath(filePath) {
    const normalizedPath = normalizeSupportedCorpusFilePath(filePath)
    if (!normalizedPath) return ''

    const existingIndex = pendingSystemOpenFilePaths.indexOf(normalizedPath)
    if (existingIndex >= 0) {
      pendingSystemOpenFilePaths.splice(existingIndex, 1)
    }
    pendingSystemOpenFilePaths.push(normalizedPath)
    return normalizedPath
  }

  function consumePendingSystemOpenFilePaths() {
    const filePaths = [...pendingSystemOpenFilePaths]
    pendingSystemOpenFilePaths.length = 0
    return filePaths
  }

  function queueAppMenuAction(action) {
    const normalizedAction = String(action || '').trim()
    if (!normalizedAction) return ''

    pendingAppMenuActions.push(normalizedAction)
    if (pendingAppMenuActions.length > 30) {
      pendingAppMenuActions.splice(0, pendingAppMenuActions.length - 30)
    }
    return normalizedAction
  }

  function consumePendingAppMenuActions() {
    const actions = [...pendingAppMenuActions]
    pendingAppMenuActions.length = 0
    return actions
  }

  function sendAppMenuActionToWindow(targetWindow, action) {
    const normalizedAction = String(action || '').trim()
    if (!targetWindow || targetWindow.isDestroyed?.() || !normalizedAction) return false
    focusWindow(targetWindow)
    try {
      targetWindow.webContents.send('app-menu-action', {
        action: normalizedAction
      })
      return true
    } catch (error) {
      captureMainError('menu.dispatch-action', error, { action: normalizedAction })
      return false
    }
  }

  function flushPendingAppMenuActions(targetWindow = getPrimaryWindow()) {
    if (!systemOpenBridgeReady || !targetWindow || targetWindow.isDestroyed?.()) return
    const actions = consumePendingAppMenuActions()
    for (const action of actions) {
      if (!sendAppMenuActionToWindow(targetWindow, action)) {
        queueAppMenuAction(action)
      }
    }
  }

  function normalizeSystemNotificationActionPayload(payload = {}) {
    const actionId = String(payload?.actionId || '').trim()
    if (!actionId) return null

    return {
      actionId,
      tag: String(payload?.tag || '').trim(),
      title: String(payload?.title || '').trim(),
      body: String(payload?.body || '').trim(),
      actionPayload: payload?.actionPayload ?? null
    }
  }

  function queueSystemNotificationAction(payload) {
    const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
    if (!normalizedPayload) return null

    pendingSystemNotificationActions.push(normalizedPayload)
    if (pendingSystemNotificationActions.length > 30) {
      pendingSystemNotificationActions.splice(0, pendingSystemNotificationActions.length - 30)
    }
    return normalizedPayload
  }

  function consumePendingSystemNotificationActions() {
    const actions = [...pendingSystemNotificationActions]
    pendingSystemNotificationActions.length = 0
    return actions
  }

  function sendSystemNotificationActionToWindow(targetWindow, payload) {
    const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
    if (!targetWindow || targetWindow.isDestroyed?.() || !normalizedPayload) return false

    focusWindow(targetWindow)
    try {
      targetWindow.webContents.send('system-notification-action', normalizedPayload)
      return true
    } catch (error) {
      captureMainError('system-notification.dispatch-action', error, normalizedPayload)
      return false
    }
  }

  function flushPendingSystemNotificationActions(targetWindow = getPrimaryWindow()) {
    if (!systemOpenBridgeReady || !targetWindow || targetWindow.isDestroyed?.()) return
    const actions = consumePendingSystemNotificationActions()
    for (const action of actions) {
      if (!sendSystemNotificationActionToWindow(targetWindow, action)) {
        queueSystemNotificationAction(action)
      }
    }
  }

  function dispatchSystemNotificationAction(payload) {
    const normalizedPayload = normalizeSystemNotificationActionPayload(payload)
    if (!normalizedPayload) return false

    const primaryWindow = getPrimaryWindow()
    if (!primaryWindow || !systemOpenBridgeReady) {
      queueSystemNotificationAction(normalizedPayload)
      if (primaryWindow) {
        focusWindow(primaryWindow)
      } else if (app.isReady()) {
        const createdWindow = ensurePrimaryWindow('system-notification-action') || createWindowSafely('system-notification-action')
        if (createdWindow && !createdWindow.isDestroyed?.()) {
          createdWindow.webContents.once('did-finish-load', () => {
            flushPendingSystemNotificationActions(createdWindow)
          })
        }
      }
      return false
    }

    if (!sendSystemNotificationActionToWindow(primaryWindow, normalizedPayload)) {
      queueSystemNotificationAction(normalizedPayload)
      return false
    }

    return true
  }

  function dispatchSystemOpenFilePath(filePath) {
    const normalizedPath = normalizeSupportedCorpusFilePath(filePath)
    if (!normalizedPath) return false

    const primaryWindow = getPrimaryWindow()
    if (!systemOpenBridgeReady || !primaryWindow) {
      queueSystemOpenFilePath(normalizedPath)
      if (primaryWindow) {
        focusWindow(primaryWindow)
      } else if (app.isReady()) {
        ensurePrimaryWindow('system-open-file-path')
      }
      return false
    }

    try {
      focusWindow(primaryWindow)
      primaryWindow.webContents.send('system-open-file-request', {
        filePath: normalizedPath
      })
      return true
    } catch (error) {
      queueSystemOpenFilePath(normalizedPath)
      captureMainError('system-open.dispatch', error, { filePath: normalizedPath })
      return false
    }
  }

  function handleSystemOpenFilePaths(filePaths = []) {
    const normalizedPaths = extractLaunchFilePaths(filePaths)
    if (normalizedPaths.length === 0) {
      ensurePrimaryWindow('system-open-empty')
      return
    }

    let hasDispatched = false
    for (const filePath of normalizedPaths) {
      if (dispatchSystemOpenFilePath(filePath)) {
        hasDispatched = true
      }
    }

    if (!hasDispatched && app.isReady() && !getPrimaryWindow()) {
      ensurePrimaryWindow('system-open-paths-undispatched')
    }
  }

  function dispatchAppMenuAction(action) {
    const normalizedAction = String(action || '').trim()
    if (!normalizedAction) return

    const primaryWindow = getPrimaryWindow()
    if (!primaryWindow) {
      queueAppMenuAction(normalizedAction)
      if (!app.isReady()) return
      const createdWindow = ensurePrimaryWindow('app-menu-action') || createWindowSafely('app-menu-action')
      if (createdWindow && !createdWindow.isDestroyed?.()) {
        createdWindow.webContents.once('did-finish-load', () => {
          flushPendingAppMenuActions(createdWindow)
        })
      }
      return
    }

    if (!systemOpenBridgeReady) {
      queueAppMenuAction(normalizedAction)
      focusWindow(primaryWindow)
      return
    }

    if (!sendAppMenuActionToWindow(primaryWindow, normalizedAction)) {
      queueAppMenuAction(normalizedAction)
    }
  }

  function markSystemOpenBridgeReady(targetWindow = getPrimaryWindow()) {
    systemOpenBridgeReady = true
    flushPendingAppMenuActions(targetWindow)
    flushPendingSystemNotificationActions(targetWindow)
  }

  function resetSystemOpenBridgeReady() {
    systemOpenBridgeReady = false
  }

  return {
    consumePendingSystemOpenFilePaths,
    dispatchAppMenuAction,
    dispatchSystemNotificationAction,
    flushPendingAppMenuActions,
    flushPendingSystemNotificationActions,
    handleSystemOpenFilePaths,
    markSystemOpenBridgeReady,
    resetSystemOpenBridgeReady
  }
}

module.exports = {
  createWindowBridgeController
}
