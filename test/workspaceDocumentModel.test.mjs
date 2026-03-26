import test from 'node:test'
import assert from 'node:assert/strict'

import {
  buildWorkspaceDocumentSnapshot,
  resolveRepresentedPathFromCorpusResult,
  resolveWorkspaceDocumentEditedState,
  serializeWorkspaceDocumentSnapshot
} from '../renderer/workspaceDocumentModel.mjs'

test('workspace document snapshot captures search and selection state', () => {
  const snapshot = buildWorkspaceDocumentSnapshot(
    {
      currentTab: 'ngram',
      currentLibraryFolderId: 'all',
      previewCollapsed: true,
      currentCorpusMode: 'saved-multi',
      currentSelectedCorpora: [
        { id: 'a', name: 'A' },
        { id: 'b', name: 'B' }
      ],
      currentSearchQuery: 'rose',
      currentSearchOptions: { words: true, caseSensitive: false, regex: false },
      stopwordFilter: { enabled: true, mode: 'exclude', listText: 'the\nof' },
      ngramPageSize: '100',
      ngramSize: '3',
      chiSquare: { a: '1', b: '2', c: '3', d: '4', yates: true }
    },
    {
      version: 7,
      defaultWindowSize: 5
    }
  )

  assert.equal(snapshot.version, 7)
  assert.deepEqual(snapshot.workspace.corpusIds, ['a', 'b'])
  assert.equal(snapshot.search.query, 'rose')
  assert.equal(snapshot.search.stopwordFilter.mode, 'exclude')
  assert.equal(snapshot.ngram.size, '3')
  assert.equal(snapshot.chiSquare.yates, true)
})

test('workspace document edited state compares against last successful snapshot', () => {
  const snapshot = buildWorkspaceDocumentSnapshot({
    currentTab: 'stats',
    currentLibraryFolderId: 'all',
    previewCollapsed: true,
    currentCorpusMode: 'quick',
    currentSelectedCorpora: [],
    currentSearchQuery: '',
    currentSearchOptions: {}
  })
  const snapshotKey = serializeWorkspaceDocumentSnapshot(snapshot)

  const unchanged = resolveWorkspaceDocumentEditedState({
    snapshot,
    lastSuccessfulSnapshotKey: snapshotKey,
    hasMeaningfulWorkspaceSnapshot: () => true
  })
  assert.equal(unchanged.edited, false)

  const changed = resolveWorkspaceDocumentEditedState({
    snapshot: {
      ...snapshot,
      currentTab: 'ngram'
    },
    lastSuccessfulSnapshotKey: snapshotKey,
    hasMeaningfulWorkspaceSnapshot: () => true
  })
  assert.equal(changed.edited, true)
})

test('represented path only resolves for quick or saved corpus results', () => {
  assert.equal(
    resolveRepresentedPathFromCorpusResult({
      mode: 'quick',
      filePath: '/tmp/example.txt'
    }),
    '/tmp/example.txt'
  )
  assert.equal(
    resolveRepresentedPathFromCorpusResult({
      mode: 'saved-multi',
      filePath: '/tmp/example.txt'
    }),
    ''
  )
})
