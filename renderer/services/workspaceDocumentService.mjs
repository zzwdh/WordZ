import {
  buildWorkspaceDocumentState,
  buildWorkspaceDocumentSnapshot,
  normalizeWorkspaceDocumentContext,
  resolveRepresentedPathFromCorpusResult,
  resolveWorkspaceDocumentEditedState,
  serializeWorkspaceDocumentSnapshot
} from '../workspaceDocumentModel.mjs'

function createUnavailableResult(message = '当前桌面宿主不支持窗口文档状态。') {
  return {
    success: false,
    message
  }
}

export function createWorkspaceDocumentService({
  windowDocumentController,
  hasMeaningfulWorkspaceSnapshot = () => false,
  workspaceSnapshotVersion = 1,
  defaultWindowSize = 5
} = {}) {
  let corpusContext = normalizeWorkspaceDocumentContext()
  let lastSuccessfulSnapshotKey = ''

  function getCorpusContext() {
    return { ...corpusContext }
  }

  function getLastSuccessfulSnapshotKey() {
    return lastSuccessfulSnapshotKey
  }

  function buildWorkspaceSnapshot(workspaceState = {}) {
    return buildWorkspaceDocumentSnapshot(workspaceState, {
      version: workspaceSnapshotVersion,
      defaultWindowSize
    })
  }

  function buildPayload(overrides = {}) {
    return buildWorkspaceDocumentState({
      corpusContext: {
        ...corpusContext,
        ...overrides
      }
    })
  }

  function rememberSuccessfulSnapshot(snapshot = {}) {
    lastSuccessfulSnapshotKey = serializeWorkspaceDocumentSnapshot(snapshot)
    return lastSuccessfulSnapshotKey
  }

  function resolveEditedState(snapshot = {}) {
    return resolveWorkspaceDocumentEditedState({
      snapshot,
      lastSuccessfulSnapshotKey,
      hasMeaningfulWorkspaceSnapshot
    })
  }

  function syncContext(partialContext = {}, options = {}) {
    corpusContext = normalizeWorkspaceDocumentContext({
      ...corpusContext,
      ...partialContext
    })

    if (!windowDocumentController?.syncDocumentState) {
      return Promise.resolve(createUnavailableResult())
    }

    return windowDocumentController.syncDocumentState(
      buildPayload(),
      options
    )
  }

  function syncContextFromCorpusResult(result = {}, { displayName = '', immediate = false } = {}) {
    return syncContext(
      {
        representedPath: resolveRepresentedPathFromCorpusResult(result),
        displayName: String(displayName || result?.displayName || result?.fileName || '')
      },
      { immediate }
    )
  }

  function clearContext(options = {}) {
    corpusContext = normalizeWorkspaceDocumentContext()
    if (typeof windowDocumentController?.clear === 'function') {
      return windowDocumentController.clear(options)
    }
    return syncContext({}, options)
  }

  function setEdited(edited, options = {}) {
    if (!windowDocumentController?.setEdited) {
      return Promise.resolve(createUnavailableResult())
    }
    return windowDocumentController.setEdited(edited === true, options)
  }

  function syncEditedFromSnapshot(
    snapshot = {},
    {
      workspaceReady = true,
      workspaceRestoreInProgress = false
    } = {}
  ) {
    const snapshotKey = serializeWorkspaceDocumentSnapshot(snapshot)
    if (!workspaceReady || workspaceRestoreInProgress) {
      void setEdited(false, { immediate: false })
      return {
        edited: false,
        snapshotKey,
        blocked: true
      }
    }

    const resolved = resolveEditedState(snapshot)
    void setEdited(resolved.edited, {
      immediate: resolved.edited === true
    })
    return resolved
  }

  function markSnapshotPersisted(snapshot = {}) {
    const snapshotKey = rememberSuccessfulSnapshot(snapshot)
    void setEdited(false, { immediate: true })
    return {
      edited: false,
      snapshotKey
    }
  }

  return Object.freeze({
    buildPayload,
    buildWorkspaceSnapshot,
    clearContext,
    getCorpusContext,
    getLastSuccessfulSnapshotKey,
    markSnapshotPersisted,
    rememberSuccessfulSnapshot,
    resolveEditedState,
    setEdited,
    syncContext,
    syncContextFromCorpusResult,
    syncEditedFromSnapshot
  })
}
