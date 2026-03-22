const { writePreloadError } = require('./logging')

function createIpcClient({ ipcRenderer, writeLog = () => {}, writeError = writePreloadError }) {
  function invoke(channel, payload) {
    if (typeof payload === 'undefined') {
      return ipcRenderer.invoke(channel)
    }
    return ipcRenderer.invoke(channel, payload)
  }

  function subscribe(channel, callback, scope = channel) {
    if (typeof callback !== 'function') return () => {}
    const listener = (_event, payload) => {
      try {
        callback(payload)
      } catch (error) {
        writeError('listener-failed', error, {
          channel,
          scope
        })
      }
    }
    ipcRenderer.on(channel, listener)
    writeLog('listener-ready', {
      channel,
      scope
    })
    return () => {
      ipcRenderer.removeListener(channel, listener)
    }
  }

  return Object.freeze({
    invoke,
    subscribe
  })
}

module.exports = {
  createIpcClient
}
