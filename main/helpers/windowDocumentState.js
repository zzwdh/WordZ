const path = require('path')

function normalizeWindowDocumentState(
  payload = {},
  {
    appName = 'WordZ',
    pathModule = path
  } = {}
) {
  const rawRepresentedPath = String(payload?.representedPath || '').trim()
  let representedPath = ''

  if (rawRepresentedPath) {
    try {
      representedPath = pathModule.resolve(rawRepresentedPath)
    } catch {
      representedPath = ''
    }
  }

  const displayName = String(payload?.displayName || '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 160)

  const edited = payload?.edited === true

  return {
    representedPath,
    displayName,
    edited,
    windowTitle: displayName ? `${appName} — ${displayName}` : appName
  }
}

function createWindowDocumentStateController({
  win,
  platform = process.platform,
  appName = 'WordZ',
  pathModule = path
}) {
  let currentState = normalizeWindowDocumentState({}, { appName, pathModule })

  function applyState() {
    if (!win || win.isDestroyed?.()) return

    if (platform === 'darwin') {
      if (typeof win.setRepresentedFilename === 'function') {
        win.setRepresentedFilename(currentState.representedPath || '')
      }
      if (typeof win.setDocumentEdited === 'function') {
        win.setDocumentEdited(currentState.edited)
      }
    }

    if (typeof win.setTitle === 'function') {
      win.setTitle(currentState.windowTitle)
    }
  }

  function getState() {
    return { ...currentState }
  }

  function update(payload = {}) {
    const nextState = normalizeWindowDocumentState(
      {
        representedPath:
          payload?.representedPath === undefined
            ? currentState.representedPath
            : payload.representedPath,
        displayName:
          payload?.displayName === undefined
            ? currentState.displayName
            : payload.displayName,
        edited:
          payload?.edited === undefined
            ? currentState.edited
            : payload.edited
      },
      {
        appName,
        pathModule
      }
    )

    const changed =
      nextState.representedPath !== currentState.representedPath ||
      nextState.displayName !== currentState.displayName ||
      nextState.edited !== currentState.edited

    currentState = nextState
    if (changed) {
      applyState()
    }

    return {
      success: true,
      changed,
      documentState: getState()
    }
  }

  function clear() {
    return update({
      representedPath: '',
      displayName: '',
      edited: false
    })
  }

  applyState()

  return {
    clear,
    getState,
    update
  }
}

module.exports = {
  createWindowDocumentStateController,
  normalizeWindowDocumentState
}
