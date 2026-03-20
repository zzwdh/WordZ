function getCurrentCollocatePageRows(state) {
  if (state.currentCollocateRows.length === 0) {
    return { pageRows: [], currentCollocatePage: 1, totalPages: 0, totalRows: 0 }
  }
  const totalRows = state.currentCollocateRows.length
  const totalPages = Math.ceil(totalRows / state.currentCollocatePageSize)
  const currentCollocatePage = Math.min(state.currentCollocatePage, totalPages)
  const startIndex = (currentCollocatePage - 1) * state.currentCollocatePageSize
  return {
    pageRows: state.currentCollocateRows.slice(startIndex, startIndex + state.currentCollocatePageSize),
    currentCollocatePage,
    totalPages,
    totalRows
  }
}

export function renderCollocateTable(state, dom, helpers) {
  const { pageRows, currentCollocatePage, totalPages, totalRows } = getCurrentCollocatePageRows(state)

  if (totalRows === 0) {
    helpers.cancelTableRender(dom.collocateWrapper)
    dom.collocateTotalRowsInfo.textContent = '共 0 条结果'
    dom.collocatePageInfo.textContent = '第 0 / 0 页'
    dom.collocatePrevPageButton.disabled = true
    dom.collocateNextPageButton.disabled = true
    dom.collocateWrapper.innerHTML = '<div class="empty-tip">没有找到符合条件的 Collocate 结果</div>'
    return { currentCollocatePage: 1 }
  }

  const isShowingAllRows = dom.collocatePageSizeSelect.value === 'all'
  dom.collocateTotalRowsInfo.textContent = `共 ${totalRows} 条结果`
  dom.collocatePageInfo.textContent = isShowingAllRows ? '全部显示' : `第 ${currentCollocatePage} / ${totalPages} 页`
  dom.collocatePrevPageButton.disabled = isShowingAllRows || currentCollocatePage === 1
  dom.collocateNextPageButton.disabled = isShowingAllRows || currentCollocatePage === totalPages
  helpers.renderTableInChunks({
    container: dom.collocateWrapper,
    rows: pageRows,
    headerHtml: '<tr><th>搭配词</th><th class="numeric-cell">共现次数</th><th class="numeric-cell">左侧次数</th><th class="numeric-cell">右侧次数</th><th class="numeric-cell">搭配词词频</th><th class="numeric-cell">节点词词频</th><th class="numeric-cell">共现率</th></tr>',
    rowUnit: '结果',
    emptyHtml: '<div class="empty-tip">没有找到符合条件的 Collocate 结果</div>',
    renderRow: item => `<tr><td>${helpers.escapeHtml(item.word)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.total)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.left)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.right)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.wordFreq)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(item.keywordFreq)}</td><td class="numeric-cell mono-readout">${item.rate.toFixed(4)}</td></tr>`
  })

  return { currentCollocatePage }
}

export function buildCollocateRows(state) {
  const { pageRows } = getCurrentCollocatePageRows(state)
  if (pageRows.length === 0) return []
  const result = [['搭配词', '共现次数', '左侧次数', '右侧次数', '搭配词词频', '节点词词频', '共现率']]
  for (const item of pageRows) {
    result.push([item.word, item.total, item.left, item.right, item.wordFreq, item.keywordFreq, item.rate.toFixed(4)])
  }
  return result
}

export function buildAllCollocateRows(state) {
  if (state.currentCollocateRows.length === 0) return []
  const result = [['搭配词', '共现次数', '左侧次数', '右侧次数', '搭配词词频', '节点词词频', '共现率']]
  for (const item of state.currentCollocateRows) {
    result.push([item.word, item.total, item.left, item.right, item.wordFreq, item.keywordFreq, item.rate.toFixed(4)])
  }
  return result
}
