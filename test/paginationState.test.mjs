import test from 'node:test'
import assert from 'node:assert/strict'

import { buildPaginationDisplayState } from '../renderer/viewModels/paginationState.mjs'

test('pagination state returns zero-page controls when there are no rows', () => {
  const state = buildPaginationDisplayState({
    totalRows: 0,
    currentPage: 1,
    totalPages: 0
  })

  assert.deepEqual(state, {
    pageLabel: '第 0 / 0 页',
    previousDisabled: true,
    nextDisabled: true,
    hasRows: false
  })
})

test('pagination state returns all-results label when showing all rows', () => {
  const state = buildPaginationDisplayState({
    totalRows: 120,
    currentPage: 1,
    totalPages: 6,
    showAll: true
  })

  assert.deepEqual(state, {
    pageLabel: '全部显示',
    previousDisabled: true,
    nextDisabled: true,
    hasRows: true
  })
})

test('pagination state clamps page and button states for paged results', () => {
  const firstPage = buildPaginationDisplayState({
    totalRows: 120,
    currentPage: 1,
    totalPages: 6
  })
  const lastPage = buildPaginationDisplayState({
    totalRows: 120,
    currentPage: 6,
    totalPages: 6
  })

  assert.deepEqual(firstPage, {
    pageLabel: '第 1 / 6 页',
    previousDisabled: true,
    nextDisabled: false,
    hasRows: true
  })

  assert.deepEqual(lastPage, {
    pageLabel: '第 6 / 6 页',
    previousDisabled: false,
    nextDisabled: true,
    hasRows: true
  })
})
