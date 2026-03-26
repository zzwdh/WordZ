import test from 'node:test'
import assert from 'node:assert/strict'

import {
  buildWorkspaceShellState,
  getWorkspaceFileInfoText,
  normalizeWorkspaceCorpusState
} from '../renderer/workspaceSessionModel.mjs'

test('workspace session model normalizes corpus selection and labels saved corpus info', () => {
  const state = normalizeWorkspaceCorpusState({
    mode: 'saved',
    displayName: 'Corpus A',
    folderName: '文学',
    selectedCorpora: [{ id: 'a', name: 'Corpus A', sourceType: 'txt' }]
  })

  assert.equal(state.selectedCorpora.length, 1)
  assert.equal(getWorkspaceFileInfoText(state), '当前语料（已保存 / 文学）：Corpus A')
})

test('workspace shell state builds quick and multi-corpus labels', () => {
  const quick = buildWorkspaceShellState({
    mode: 'quick',
    displayName: 'demo.txt',
    selectedCorpora: []
  })
  assert.equal(quick.fileInfoText, '当前语料（Quick Corpus）：demo.txt')

  const multi = buildWorkspaceShellState({
    mode: 'saved-multi',
    displayName: '已选 2 条语料',
    selectedCorpora: [
      { id: 'a', name: 'A' },
      { id: 'b', name: 'B' }
    ]
  })
  assert.equal(multi.fileInfoText, '当前语料（多选 / 2 条）：已选 2 条语料')
})
