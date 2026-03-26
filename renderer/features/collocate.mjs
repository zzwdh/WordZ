import { buildPaginationDisplayState } from '../viewModels/paginationState.mjs'

function getCurrentCollocatePageRows(state) {
  if (state.currentCollocateRows.length === 0) {
    return { pageRows: [], currentCollocatePage: 1, totalPages: 0, totalRows: 0, startIndex: 0 }
  }
  const totalRows = state.currentCollocateRows.length
  const totalPages = Math.ceil(totalRows / state.currentCollocatePageSize)
  const currentCollocatePage = Math.min(state.currentCollocatePage, totalPages)
  const startIndex = (currentCollocatePage - 1) * state.currentCollocatePageSize
  return {
    pageRows: state.currentCollocateRows.slice(startIndex, startIndex + state.currentCollocatePageSize),
    currentCollocatePage,
    totalPages,
    totalRows,
    startIndex
  }
}

export function renderCollocateTable(state, dom, helpers) {
  const { pageRows, currentCollocatePage, totalPages, totalRows, startIndex } = getCurrentCollocatePageRows(state)

  if (totalRows === 0) {
    const paginationState = buildPaginationDisplayState({
      totalRows,
      currentPage: 1,
      totalPages: 0
    })
    helpers.cancelTableRender(dom.collocateWrapper)
    dom.collocateWrapper.classList.remove('show-all-results')
    dom.collocateTotalRowsInfo.textContent = '共 0 条结果'
    dom.collocatePageInfo.textContent = paginationState.pageLabel
    dom.collocatePrevPageButton.disabled = paginationState.previousDisabled
    dom.collocateNextPageButton.disabled = paginationState.nextDisabled
    dom.collocateWrapper.innerHTML = '<div class="empty-tip">没有找到符合条件的 Collocate 结果</div>'
    return { currentCollocatePage: 1 }
  }

  const isShowingAllRows = dom.collocatePageSizeSelect.value === 'all'
  const paginationState = buildPaginationDisplayState({
    totalRows,
    currentPage: currentCollocatePage,
    totalPages,
    showAll: isShowingAllRows
  })
  dom.collocateWrapper.classList.toggle('show-all-results', isShowingAllRows)
  dom.collocateTotalRowsInfo.textContent = `共 ${totalRows} 条结果`
  dom.collocatePageInfo.textContent = paginationState.pageLabel
  dom.collocatePrevPageButton.disabled = paginationState.previousDisabled
  dom.collocateNextPageButton.disabled = paginationState.nextDisabled
  helpers.renderTableInChunks({
    container: dom.collocateWrapper,
    rows: pageRows,
    tableClassName: 'fit-data-table',
    headerHtml: '<tr><th class="numeric-cell">Rank</th><th>搭配词</th><th class="numeric-cell">FreqLR</th><th class="numeric-cell">FreqL</th><th class="numeric-cell">FreqR</th><th class="numeric-cell">搭配词词频</th><th class="numeric-cell">节点词词频</th><th class="numeric-cell">共现率</th></tr>',
    rowUnit: '结果',
    virtualize: !isShowingAllRows,
    emptyHtml: '<div class="empty-tip">没有找到符合条件的 Collocate 结果</div>',
    renderRow: (item, index) => `<tr><td class="numeric-cell mono-readout">${helpers.formatCount(startIndex + index + 1)}</td><td>${helpers.escapeHtml(item.word)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.total)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.left)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.right)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.wordFreq)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.keywordFreq)}</td><td class="numeric-cell mono-readout">${item.rate.toFixed(4)}</td></tr>`
  })

  return { currentCollocatePage }
}

export function buildCollocateRows(state) {
  const { pageRows, startIndex } = getCurrentCollocatePageRows(state)
  if (pageRows.length === 0) return []
  const result = [['Rank', '搭配词', 'FreqLR', 'FreqL', 'FreqR', '搭配词词频', '节点词词频', '共现率']]
  for (let index = 0; index < pageRows.length; index++) {
    const item = pageRows[index]
    result.push([startIndex + index + 1, item.word, item.total, item.left, item.right, item.wordFreq, item.keywordFreq, item.rate.toFixed(4)])
  }
  return result
}

export function buildAllCollocateRows(state) {
  if (state.currentCollocateRows.length === 0) return []
  const result = [['Rank', '搭配词', 'FreqLR', 'FreqL', 'FreqR', '搭配词词频', '节点词词频', '共现率']]
  for (let index = 0; index < state.currentCollocateRows.length; index++) {
    const item = state.currentCollocateRows[index]
    result.push([index + 1, item.word, item.total, item.left, item.right, item.wordFreq, item.keywordFreq, item.rate.toFixed(4)])
  }
  return result
}
