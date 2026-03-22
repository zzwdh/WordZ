function createWindowBridge({
  ipcClient,
  normalizeBoolean,
  normalizeNotificationAction,
  normalizeTextInput,
  clampZoomFactor,
  electronModuleLoader = require
}) {
  let webFrameRef = null

  function getWebFrame() {
    if (webFrameRef) return webFrameRef
    const { webFrame } = electronModuleLoader('electron')
    webFrameRef = webFrame
    return webFrameRef
  }

  return {
    showSystemNotification: ({ title, body, subtitle, tag, silent, action } = {}) =>
      ipcClient.invoke('show-system-notification', {
        title: normalizeTextInput(title, 80),
        body: normalizeTextInput(body, 240),
        subtitle: normalizeTextInput(subtitle, 80),
        tag: normalizeTextInput(tag, 64),
        silent: normalizeBoolean(silent),
        action: normalizeNotificationAction(action)
      }),

    setWindowProgressState: ({ source, state, progress, priority } = {}) =>
      ipcClient.invoke('set-window-progress-state', {
        source: normalizeTextInput(source, 40),
        state: normalizeTextInput(state, 20),
        progress: Number(progress),
        priority: Number(priority)
      }),

    setWindowAttentionState: ({ source, state, count, description, priority, requestAttention } = {}) =>
      ipcClient.invoke('set-window-attention-state', {
        source: normalizeTextInput(source, 40),
        state: normalizeTextInput(state, 20),
        count: Number(count),
        description: normalizeTextInput(description, 120),
        priority: Number(priority),
        requestAttention: normalizeBoolean(requestAttention)
      }),

    setZoomFactor: factor =>
      getWebFrame().setZoomFactor(clampZoomFactor(factor)),

    getZoomFactor: () =>
      getWebFrame().getZoomFactor()
  }
}

module.exports = {
  createWindowBridge
}
