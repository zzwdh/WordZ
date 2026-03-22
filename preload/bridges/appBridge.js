function createAppBridge({ ipcClient }) {
  return {
    getAppInfo: () =>
      ipcClient.invoke('get-app-info'),

    getRendererShellMarkup: () =>
      ipcClient.invoke('get-renderer-shell-markup'),

    consumePendingSystemOpenFiles: () =>
      ipcClient.invoke('consume-pending-system-open-files'),

    reportRendererReady: (payload = {}) =>
      ipcClient.invoke('report-renderer-ready', payload),

    onSystemOpenFileRequest: callback =>
      ipcClient.subscribe('system-open-file-request', callback, 'onSystemOpenFileRequest'),

    onAppMenuAction: callback =>
      ipcClient.subscribe('app-menu-action', callback, 'onAppMenuAction'),

    onSystemNotificationAction: callback =>
      ipcClient.subscribe('system-notification-action', callback, 'onSystemNotificationAction')
  }
}

module.exports = {
  createAppBridge
}
