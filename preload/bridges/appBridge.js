function createAppBridge({ ipcClient }) {
  return {
    getAppInfo: () =>
      ipcClient.invoke('get-app-info'),

    getSystemAppearanceState: () =>
      ipcClient.invoke('get-system-appearance-state'),

    consumePendingSystemOpenFiles: () =>
      ipcClient.invoke('consume-pending-system-open-files'),

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
