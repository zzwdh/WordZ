function normalizeSnapshotVersion(version = 1) {
  const numericVersion = Number(version)
  if (!Number.isFinite(numericVersion) || numericVersion <= 0) return 1
  return Math.trunc(numericVersion)
}

function sanitizeCorpusSelection(selectedCorpora = []) {
  return Array.isArray(selectedCorpora)
    ? selectedCorpora
        .map(item => ({
          id: String(item?.id || '').trim(),
          name: String(item?.name || '').trim()
        }))
        .filter(item => item.id)
    : []
}

export function normalizeWorkspaceDocumentContext(context = {}) {
  return {
    representedPath: String(context?.representedPath || '').trim(),
    displayName: String(context?.displayName || '').trim()
  }
}

export function serializeWorkspaceDocumentSnapshot(snapshot = {}) {
  try {
    return JSON.stringify(snapshot)
  } catch {
    return ''
  }
}

export function buildWorkspaceDocumentSnapshot(workspaceState = {}, options = {}) {
  const {
    version = 1,
    defaultWindowSize = 5
  } = options
  const normalizedSelectedCorpora = sanitizeCorpusSelection(workspaceState.currentSelectedCorpora)
  const restorableCorpusIds =
    workspaceState.currentCorpusMode === 'saved' || workspaceState.currentCorpusMode === 'saved-multi'
      ? normalizedSelectedCorpora.map(item => item.id)
      : []
  const restorableCorpusNames =
    workspaceState.currentCorpusMode === 'saved' || workspaceState.currentCorpusMode === 'saved-multi'
      ? normalizedSelectedCorpora.map(item => item.name).filter(Boolean)
      : []

  return {
    version: normalizeSnapshotVersion(version),
    savedAt: new Date().toISOString(),
    currentTab: workspaceState.currentTab,
    currentLibraryFolderId: workspaceState.currentLibraryFolderId,
    previewCollapsed: workspaceState.previewCollapsed !== false,
    workspace: {
      corpusIds: restorableCorpusIds,
      corpusNames: restorableCorpusNames
    },
    search: {
      query: String(workspaceState.currentSearchQuery || ''),
      options: { ...(workspaceState.currentSearchOptions || {}) },
      stopwordFilter: { ...(workspaceState.stopwordFilter || {}) }
    },
    stats: {
      pageSize: workspaceState.statsPageSize || '10'
    },
    compare: {
      pageSize: workspaceState.comparePageSize || '10'
    },
    ngram: {
      pageSize: workspaceState.ngramPageSize || '10',
      size: workspaceState.ngramSize || '2'
    },
    kwic: {
      pageSize: workspaceState.kwicPageSize || '10',
      scope: workspaceState.kwicScope || 'current',
      sortMode: workspaceState.kwicSortMode || 'original',
      leftWindow: workspaceState.kwicLeftWindow || String(defaultWindowSize),
      rightWindow: workspaceState.kwicRightWindow || String(defaultWindowSize)
    },
    collocate: {
      pageSize: workspaceState.collocatePageSize || '10',
      leftWindow: workspaceState.collocateLeftWindow || String(defaultWindowSize),
      rightWindow: workspaceState.collocateRightWindow || String(defaultWindowSize),
      minFreq: workspaceState.collocateMinFreq || '1'
    },
    chiSquare: {
      ...(workspaceState.chiSquare || {})
    }
  }
}

export function resolveWorkspaceDocumentEditedState({
  snapshot,
  lastSuccessfulSnapshotKey = '',
  hasMeaningfulWorkspaceSnapshot = () => false
} = {}) {
  const snapshotKey = serializeWorkspaceDocumentSnapshot(snapshot)
  const hasBaseline = Boolean(lastSuccessfulSnapshotKey)
  const edited = hasBaseline
    ? snapshotKey !== lastSuccessfulSnapshotKey
    : hasMeaningfulWorkspaceSnapshot(snapshot)

  return {
    edited,
    snapshotKey
  }
}

export function resolveRepresentedPathFromCorpusResult(result = {}) {
  const mode = String(result?.mode || '').trim()
  if (mode !== 'quick' && mode !== 'saved') return ''
  return String(result?.filePath || '').trim()
}

export function buildWorkspaceDocumentState({
  corpusContext = {},
  edited = false
} = {}) {
  const normalizedContext = normalizeWorkspaceDocumentContext(corpusContext)
  return {
    ...normalizedContext,
    edited: edited === true
  }
}

export function buildWindowDocumentPayload({
  representedPath = '',
  displayName = '',
  edited = false
} = {}) {
  return buildWorkspaceDocumentState({
    corpusContext: {
      representedPath,
      displayName
    },
    edited
  })
}
