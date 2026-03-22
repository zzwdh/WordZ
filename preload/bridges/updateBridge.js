function createUpdateBridge({ ipcClient }) {
  return {
    getAutoUpdateState: () =>
      ipcClient.invoke('get-auto-update-state'),

    checkForUpdates: () =>
      ipcClient.invoke('check-for-updates'),

    installDownloadedUpdate: () =>
      ipcClient.invoke('install-downloaded-update'),

    onAutoUpdateStatus: callback =>
      ipcClient.subscribe('auto-update-status', callback, 'onAutoUpdateStatus')
  }
}

module.exports = {
  createUpdateBridge
}
