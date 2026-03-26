import test from 'node:test'
import assert from 'node:assert/strict'

import { createWorkspaceDocumentService } from '../renderer/services/workspaceDocumentService.mjs'

function createControllerStub() {
  const calls = {
    syncDocumentState: [],
    setEdited: [],
    clear: []
  }

  return {
    calls,
    controller: {
      syncDocumentState(payload, options = {}) {
        calls.syncDocumentState.push({ payload, options })
        return Promise.resolve({ success: true, payload, options })
      },
      setEdited(edited, options = {}) {
        calls.setEdited.push({ edited, options })
        return Promise.resolve({ success: true, edited, options })
      },
      clear(options = {}) {
        calls.clear.push({ options })
        return Promise.resolve({ success: true, options })
      }
    }
  }
}

test('workspace document service derives represented path from corpus result', async () => {
  const { controller, calls } = createControllerStub()
  const service = createWorkspaceDocumentService({
    windowDocumentController: controller,
    hasMeaningfulWorkspaceSnapshot: () => false,
    workspaceSnapshotVersion: 3,
    defaultWindowSize: 7
  })

  await service.syncContextFromCorpusResult(
    {
      mode: 'quick',
      filePath: '/tmp/demo.txt',
      displayName: 'Quick Demo'
    },
    { displayName: 'Quick Demo' }
  )

  assert.deepEqual(calls.syncDocumentState.at(-1)?.payload, {
    representedPath: '/tmp/demo.txt',
    displayName: 'Quick Demo',
    edited: false
  })

  await service.syncContextFromCorpusResult(
    {
      mode: 'saved-multi',
      filePath: '/tmp/ignored.txt',
      displayName: 'Multi Demo'
    },
    { displayName: 'Multi Demo' }
  )

  assert.deepEqual(calls.syncDocumentState.at(-1)?.payload, {
    representedPath: '',
    displayName: 'Multi Demo',
    edited: false
  })
})

test('workspace document service builds snapshots with configured defaults', () => {
  const { controller } = createControllerStub()
  const service = createWorkspaceDocumentService({
    windowDocumentController: controller,
    hasMeaningfulWorkspaceSnapshot: () => false,
    workspaceSnapshotVersion: 9,
    defaultWindowSize: 11
  })

  const snapshot = service.buildWorkspaceSnapshot({
    currentTab: 'kwic',
    currentLibraryFolderId: 'all',
    previewCollapsed: true,
    currentCorpusMode: 'saved',
    currentSelectedCorpora: [{ id: 'a', name: 'Corpus A' }],
    currentSearchQuery: 'rose',
    currentSearchOptions: { words: true, caseSensitive: false, regex: false }
  })

  assert.equal(snapshot.version, 9)
  assert.equal(snapshot.kwic.leftWindow, '11')
  assert.equal(snapshot.kwic.rightWindow, '11')
})

test('workspace document service establishes snapshot baseline on persist', async () => {
  const { controller, calls } = createControllerStub()
  const service = createWorkspaceDocumentService({
    windowDocumentController: controller,
    hasMeaningfulWorkspaceSnapshot: snapshot => Boolean(snapshot?.currentTab)
  })

  const snapshot = service.buildWorkspaceSnapshot({
    currentTab: 'stats',
    currentLibraryFolderId: 'all',
    previewCollapsed: true,
    currentCorpusMode: 'quick',
    currentSelectedCorpora: [],
    currentSearchQuery: '',
    currentSearchOptions: {}
  })

  const beforePersist = service.syncEditedFromSnapshot(snapshot, {
    workspaceReady: true,
    workspaceRestoreInProgress: false
  })
  assert.equal(beforePersist.edited, true)

  const persisted = service.markSnapshotPersisted(snapshot)
  assert.equal(persisted.edited, false)
  assert.ok(service.getLastSuccessfulSnapshotKey())
  assert.equal(calls.setEdited.at(-1)?.edited, false)

  const afterPersist = service.syncEditedFromSnapshot(snapshot, {
    workspaceReady: true,
    workspaceRestoreInProgress: false
  })
  assert.equal(afterPersist.edited, false)
})

test('workspace document service blocks edited state while restore is in progress', () => {
  const { controller, calls } = createControllerStub()
  const service = createWorkspaceDocumentService({
    windowDocumentController: controller,
    hasMeaningfulWorkspaceSnapshot: () => true
  })

  const snapshot = service.buildWorkspaceSnapshot({
    currentTab: 'compare',
    currentLibraryFolderId: 'all',
    previewCollapsed: true,
    currentCorpusMode: 'quick',
    currentSelectedCorpora: [],
    currentSearchQuery: 'rose',
    currentSearchOptions: {}
  })

  const resolved = service.syncEditedFromSnapshot(snapshot, {
    workspaceReady: false,
    workspaceRestoreInProgress: true
  })

  assert.equal(resolved.edited, false)
  assert.equal(resolved.blocked, true)
  assert.equal(calls.setEdited.at(-1)?.edited, false)
})
