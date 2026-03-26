import { buildPaginationDisplayState } from '../viewModels/paginationState.mjs'

function getCurrentNgramPageRows(state) {
  const rows = Array.isArray(state.currentDisplayedNgramRows) ? state.currentDisplayedNgramRows : []
  if (rows.length === 0) {
    return { pageRows: [], currentNgramPage: 1, totalPages: 0, totalRows: 0, startIndex: 0 }
  }

  const totalRows = rows.length
  const totalPages = Math.ceil(totalRows / state.currentNgramPageSize)
  const currentNgramPage = Math.min(state.currentNgramPage, totalPages)
  const startIndex = (currentNgramPage - 1) * state.currentNgramPageSize

  return {
    pageRows: rows.slice(startIndex, startIndex + state.currentNgramPageSize),
    currentNgramPage,
    totalPages,
    totalRows,
    startIndex
  }
}

export function renderNgramTable(state, dom, helpers) {
  const { pageRows, currentNgramPage, totalPages, totalRows, startIndex } = getCurrentNgramPageRows(state)
  const allRowsCount = Array.isArray(state.currentNgramRows) ? state.currentNgramRows.length : 0
  const hasFilter = Boolean(String(state.currentSearchQuery || '').trim())

  if (totalRows === 0) {
    const paginationState = buildPaginationDisplayState({
      totalRows,
      currentPage: 1,
      totalPages: 0
    })
    helpers.cancelTableRender(dom.ngramWrapper)
    dom.ngramWrapper.classList.remove('show-all-results')
    dom.ngramTotalRowsInfo.textContent = state.currentSearchError
      ? 'SearchQuery 无效'
      : hasFilter
        ? `共 ${allRowsCount} 条结果（匹配 0 条）`
        : '共 0 条结果'
    dom.ngramPageInfo.textContent = paginationState.pageLabel
    dom.ngramPrevPageButton.disabled = paginationState.previousDisabled
    dom.ngramNextPageButton.disabled = paginationState.nextDisabled
    dom.ngramWrapper.innerHTML = `<div class="empty-tip">${
      state.currentSearchError
        ? helpers.escapeHtml(state.currentSearchError)
        : hasFilter
          ? `没有匹配“${helpers.escapeHtml(state.currentSearchQuery)}”的 Ngram 结果`
          : '没有可显示的 Ngram 结果'
    }</div>`
    return { currentNgramPage: 1 }
  }

  const isShowingAllRows = dom.ngramPageSizeSelect.value === 'all'
  const paginationState = buildPaginationDisplayState({
    totalRows,
    currentPage: currentNgramPage,
    totalPages,
    showAll: isShowingAllRows
  })
  dom.ngramWrapper.classList.toggle('show-all-results', isShowingAllRows)
  dom.ngramTotalRowsInfo.textContent = hasFilter
    ? `共 ${allRowsCount} 条结果（匹配 ${totalRows} 条）`
    : `共 ${totalRows} 条结果`
  dom.ngramPageInfo.textContent = paginationState.pageLabel
  dom.ngramPrevPageButton.disabled = paginationState.previousDisabled
  dom.ngramNextPageButton.disabled = paginationState.nextDisabled

  helpers.renderTableInChunks({
    container: dom.ngramWrapper,
    rows: pageRows,
    tableClassName: 'fit-data-table',
    headerHtml: '<tr><th class="numeric-cell">Rank</th><th>Ngram</th><th class="numeric-cell">Freq</th></tr>',
    rowUnit: '结果',
    virtualize: !isShowingAllRows,
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
  const rows = Array.isArray(state.currentDisplayedNgramRows) ? state.currentDisplayedNgramRows : []
  if (rows.length === 0) return []
  const result = [['Rank', 'Ngram', 'Freq']]
  for (let index = 0; index < rows.length; index += 1) {
    const row = rows[index]
    result.push([index + 1, row[0], row[1]])
  }
  return result
}
