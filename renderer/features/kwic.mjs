export function getKWICSortLabel(mode) {
  if (mode === 'left-near') return '按左一词排序'
  if (mode === 'right-near') return '按右一词排序'
  if (mode === 'left-then-right') return '按左一词→右一词'
  if (mode === 'right-then-left') return '按右一词→左一词'
  return '原始顺序'
}

function hasCorpusColumns(state) {
  return state.currentKWICScope && state.currentKWICScope !== 'current'
}

function getKWICScopeLabel(state) {
  return state.currentKWICScopeLabel || '当前语料'
}

function getSortedKWICResults(state, sortResults) {
  if (state.currentKWICSortCache.source === state.currentKWICResults && state.currentKWICSortCache.mode === state.currentKWICSortMode) {
    return {
      rows: state.currentKWICSortCache.rows,
      cache: state.currentKWICSortCache
    }
  }

  const rows = sortResults(state.currentKWICResults, state.currentKWICSortMode)
  return {
    rows,
    cache: { source: state.currentKWICResults, mode: state.currentKWICSortMode, rows }
  }
}

function getCurrentKWICPageRows(state, sortResults) {
  const { rows, cache } = getSortedKWICResults(state, sortResults)
  const totalRows = rows.length
  if (totalRows === 0) {
    return { sortedRows: [], pageRows: [], currentKWICPage: 1, totalPages: 0, totalRows, cache }
  }
  const totalPages = Math.ceil(totalRows / state.currentKWICPageSize)
  const currentKWICPage = Math.min(state.currentKWICPage, totalPages)
  const startIndex = (currentKWICPage - 1) * state.currentKWICPageSize
  return {
    sortedRows: rows,
    pageRows: rows.slice(startIndex, startIndex + state.currentKWICPageSize),
    currentKWICPage,
    totalPages,
    totalRows,
    cache
  }
}

function buildKWICMetaHtml(state, escapeHtml) {
  const searchOptions = []
  if (state.currentSearchOptions?.words) searchOptions.push('Words')
  if (state.currentSearchOptions?.caseSensitive) searchOptions.push('Case')
  if (state.currentSearchOptions?.regex) searchOptions.push('Regex')
  const searchQueryLabel = searchOptions.length > 0 ? searchOptions.join(' / ') : '默认匹配'
  if (!state.currentKWICKeyword) {
    return '请先输入一个检索词，并选择检索范围。<br />支持当前语料、当前文件夹和全部本地语料；点击任一 KWIC 结果行可定位原句。'
  }
  const scopeLabel = escapeHtml(getKWICScopeLabel(state))
  const searchedCorpusCount = Number(state.currentKWICSearchedCorpusCount || 0)
  const corpusSummary = hasCorpusColumns(state) ? ` ｜ 语料数：${searchedCorpusCount}` : ''
  const clickHint = hasCorpusColumns(state) ? '点击任一结果行会自动打开对应语料并定位原句。' : '点击任一结果行可定位原句。'
  return `检索范围：${scopeLabel}${corpusSummary} ｜ 检索词：${escapeHtml(state.currentKWICKeyword)} ｜ SearchQuery：${escapeHtml(searchQueryLabel)} ｜ 命中次数：${state.currentKWICResults.length} ｜ 范围：${state.currentKWICLeftWindow}L ${state.currentKWICRightWindow}R ｜ 排序：${getKWICSortLabel(state.currentKWICSortMode)}<br />${clickHint}`
}

export function renderKWICTable(state, dom, helpers) {
  const { sortedRows, pageRows, currentKWICPage, totalPages, totalRows, cache } = getCurrentKWICPageRows(state, helpers.sortResults)
  const includeCorpusColumns = hasCorpusColumns(state)

  if (totalRows === 0) {
    helpers.cancelTableRender(dom.kwicWrapper)
    dom.kwicTotalRowsInfo.textContent = '共 0 条结果'
    dom.kwicPageInfo.textContent = '第 0 / 0 页'
    dom.kwicPrevPageButton.disabled = true
    dom.kwicNextPageButton.disabled = true
    dom.kwicWrapper.innerHTML = '<div class="empty-tip">没有找到匹配结果</div>'
    dom.kwicMeta.innerHTML = buildKWICMetaHtml(state, helpers.escapeHtml)
    return { currentKWICPage: 1, currentKWICSortCache: cache }
  }

  const isShowingAllRows = dom.kwicPageSizeSelect.value === 'all'
  dom.kwicTotalRowsInfo.textContent = `共 ${totalRows} 条结果`
  dom.kwicPageInfo.textContent = isShowingAllRows ? '全部显示' : `第 ${currentKWICPage} / ${totalPages} 页`
  dom.kwicPrevPageButton.disabled = isShowingAllRows || currentKWICPage === 1
  dom.kwicNextPageButton.disabled = isShowingAllRows || currentKWICPage === totalPages
  helpers.renderTableInChunks({
    container: dom.kwicWrapper,
    rows: pageRows,
    tableClassName: 'kwic-table',
    headerHtml: includeCorpusColumns
      ? '<tr><th class="library-name-cell">语料</th><th class="library-folder-cell">分类</th><th>左侧上下文</th><th>节点词</th><th>右侧上下文</th><th class="numeric-cell">文件内句号</th></tr>'
      : '<tr><th>左侧上下文</th><th>节点词</th><th>右侧上下文</th><th class="numeric-cell">句号</th></tr>',
    rowUnit: '结果',
    emptyHtml: '<div class="empty-tip">没有找到匹配结果</div>',
    renderRow: item => `
      <tr data-sentence-id="${item.sentenceId}" data-node-index="${item.sentenceTokenIndex}" data-left-window="${item.leftWindowSize}" data-right-window="${item.rightWindowSize}"${item.corpusId ? ` data-corpus-id="${helpers.escapeHtml(item.corpusId)}"` : ''}>
        ${includeCorpusColumns ? `<td>${helpers.escapeHtml(item.corpusName || '')}</td><td class="library-folder-cell">${helpers.escapeHtml(item.folderName || '')}</td>` : ''}
        <td class="kwic-left">${helpers.escapeHtml(item.left)}</td>
        <td class="kwic-node">${helpers.escapeHtml(item.node)}</td>
        <td class="kwic-right">${helpers.escapeHtml(item.right)}</td>
        <td class="numeric-cell mono-readout">${helpers.formatCount(item.sentenceId + 1)}</td>
      </tr>
    `
  })
  dom.kwicMeta.innerHTML = buildKWICMetaHtml(state, helpers.escapeHtml)

  return { currentKWICPage, currentKWICSortCache: cache, sortedRows }
}

export function buildKWICRows(state, sortResults) {
  const includeCorpusColumns = hasCorpusColumns(state)
  const { pageRows, cache } = getCurrentKWICPageRows(state, sortResults)
  if (pageRows.length === 0) return { rows: [], cache }
  const rows = [
    includeCorpusColumns
      ? ['语料', '分类', '左侧上下文', '节点词', '右侧上下文', '文件内句号']
      : ['左侧上下文', '节点词', '右侧上下文', '句号']
  ]
  for (const item of pageRows) {
    rows.push(
      includeCorpusColumns
        ? [item.corpusName || '', item.folderName || '', item.left, item.node, item.right, item.sentenceId + 1]
        : [item.left, item.node, item.right, item.sentenceId + 1]
    )
  }
  return { rows, cache }
}

export function buildAllKWICRows(state, sortResults) {
  const includeCorpusColumns = hasCorpusColumns(state)
  const { sortedRows, cache } = getCurrentKWICPageRows({
    ...state,
    currentKWICPage: 1,
    currentKWICPageSize: Math.max(state.currentKWICResults.length, 1)
  }, sortResults)
  if (sortedRows.length === 0) return { rows: [], cache }
  const rows = [
    includeCorpusColumns
      ? ['语料', '分类', '左侧上下文', '节点词', '右侧上下文', '文件内句号']
      : ['左侧上下文', '节点词', '右侧上下文', '句号']
  ]
  for (const item of sortedRows) {
    rows.push(
      includeCorpusColumns
        ? [item.corpusName || '', item.folderName || '', item.left, item.node, item.right, item.sentenceId + 1]
        : [item.left, item.node, item.right, item.sentenceId + 1]
    )
  }
  return { rows, cache }
}
