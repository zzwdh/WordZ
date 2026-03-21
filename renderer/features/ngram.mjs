function getCurrentNgramPageRows(state) {
  if (state.currentNgramRows.length === 0) {
    return { pageRows: [], currentNgramPage: 1, totalPages: 0, totalRows: 0, startIndex: 0 }
  }

  const totalRows = state.currentNgramRows.length
  const totalPages = Math.ceil(totalRows / state.currentNgramPageSize)
  const currentNgramPage = Math.min(state.currentNgramPage, totalPages)
  const startIndex = (currentNgramPage - 1) * state.currentNgramPageSize

  return {
    pageRows: state.currentNgramRows.slice(startIndex, startIndex + state.currentNgramPageSize),
    currentNgramPage,
    totalPages,
    totalRows,
    startIndex
  }
}

export function renderNgramTable(state, dom, helpers) {
  const { pageRows, currentNgramPage, totalPages, totalRows, startIndex } = getCurrentNgramPageRows(state)

  if (totalRows === 0) {
    helpers.cancelTableRender(dom.ngramWrapper)
    dom.ngramTotalRowsInfo.textContent = '共 0 条结果'
    dom.ngramPageInfo.textContent = '第 0 / 0 页'
    dom.ngramPrevPageButton.disabled = true
    dom.ngramNextPageButton.disabled = true
    dom.ngramWrapper.innerHTML = '<div class="empty-tip">没有可显示的 Ngram 结果</div>'
    return { currentNgramPage: 1 }
  }

  const isShowingAllRows = dom.ngramPageSizeSelect.value === 'all'
  dom.ngramTotalRowsInfo.textContent = `共 ${totalRows} 条结果`
  dom.ngramPageInfo.textContent = isShowingAllRows ? '全部显示' : `第 ${currentNgramPage} / ${totalPages} 页`
  dom.ngramPrevPageButton.disabled = isShowingAllRows || currentNgramPage === 1
  dom.ngramNextPageButton.disabled = isShowingAllRows || currentNgramPage === totalPages

  helpers.renderTableInChunks({
    container: dom.ngramWrapper,
    rows: pageRows,
    tableClassName: 'fit-data-table',
    headerHtml: '<tr><th class="numeric-cell">Rank</th><th>Ngram</th><th class="numeric-cell">Freq</th></tr>',
    rowUnit: '结果',
    emptyHtml: '<div class="empty-tip">没有可显示的 Ngram 结果</div>',
    renderRow: (item, index) => `
      <tr>
        <td class="numeric-cell mono-readout">${helpers.formatCount(startIndex + index + 1)}</td>
        <td>${helpers.escapeHtml(item[0])}</td>
        <td class="numeric-cell mono-readout">${helpers.formatCount(item[1])}</td>
      </tr>
    `
  })

  return { currentNgramPage }
}

export function buildNgramRows(state) {
  const { pageRows, startIndex } = getCurrentNgramPageRows(state)
  if (pageRows.length === 0) return []

  const result = [['Rank', 'Ngram', 'Freq']]
  for (let index = 0; index < pageRows.length; index += 1) {
    const row = pageRows[index]
    result.push([startIndex + index + 1, row[0], row[1]])
  }
  return result
}

export function buildAllNgramRows(state) {
  if (state.currentNgramRows.length === 0) return []
  const result = [['Rank', 'Ngram', 'Freq']]
  for (let index = 0; index < state.currentNgramRows.length; index += 1) {
    const row = state.currentNgramRows[index]
    result.push([index + 1, row[0], row[1]])
  }
  return result
}
