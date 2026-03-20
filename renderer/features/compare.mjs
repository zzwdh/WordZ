function getCurrentComparePageRows(state) {
  const rows = Array.isArray(state.currentDisplayedCompareRows) ? state.currentDisplayedCompareRows : []
  const totalRows = rows.length

  if (totalRows === 0) {
    return { pageRows: [], currentComparePage: 1, totalPages: 0, totalRows, startIndex: 0 }
  }

  const totalPages = Math.ceil(totalRows / state.currentComparePageSize)
  const currentComparePage = Math.min(state.currentComparePage, totalPages)
  const startIndex = (currentComparePage - 1) * state.currentComparePageSize

  return {
    pageRows: rows.slice(startIndex, startIndex + state.currentComparePageSize),
    currentComparePage,
    totalPages,
    totalRows,
    startIndex
  }
}

function buildCompareSummaryHtml(state, helpers) {
  const corpora = Array.isArray(state.currentComparisonCorpora) ? state.currentComparisonCorpora : []
  if (corpora.length === 0) {
    if (!state.comparisonEligible) {
      return '<div class="empty-tip">载入两条以上已保存语料后，这里会显示多语料对比摘要。</div>'
    }
    return '<div class="empty-tip">当前工作区已具备多语料条件。点击“开始统计”后生成对比摘要。</div>'
  }

  return `
    <div class="stats-readout-grid compare-summary-grid">
      ${corpora.map(corpus => `
        <div class="stats-readout-card compare-summary-card">
          <div class="stats-readout-label">${helpers.escapeHtml(corpus.corpusName)}</div>
          <div class="stats-readout-value mono-readout">${helpers.formatCount(corpus.tokenCount)} / ${helpers.formatCount(corpus.typeCount)}</div>
          <div class="stats-readout-note">${helpers.escapeHtml(corpus.folderName || '未分类')} · Token / Type</div>
          <div class="compare-summary-metrics">
            <span>TTR ${corpus.ttr.toFixed(4)}</span>
            <span>STTR ${corpus.sttr.toFixed(4)}</span>
            <span>高频词 ${helpers.escapeHtml(corpus.topWord || '--')} (${helpers.formatCount(corpus.topWordCount || 0)})</span>
          </div>
        </div>
      `).join('')}
    </div>
  `
}

function buildCompareMetaText(state, helpers, totalRows, visibleRows) {
  const corpusCount = Array.isArray(state.currentComparisonCorpora) ? state.currentComparisonCorpora.length : 0
  const allRowsCount = Array.isArray(state.currentComparisonRows) ? state.currentComparisonRows.length : 0

  if (!state.comparisonEligible) {
    return '这里会在载入两条以上已保存语料后显示“多语料对比分析”。建议先在“本地语料库”里勾选多条语料，再载入当前工作区。'
  }

  if (!state.hasStats) {
    return `当前已载入 ${helpers.formatCount(state.currentSelectedCorpora.length)} 条语料。点击“开始统计”后，会生成每条语料的摘要和跨语料词频对比表。`
  }

  if (state.currentSearchError) {
    return 'SearchQuery 当前无效。请先修正正则或匹配选项。'
  }

  const searchSummary = state.currentSearchQuery
    ? ` ｜ SearchQuery：${helpers.escapeHtml(state.currentSearchQuery)}`
    : ''
  const matchSummary = state.currentSearchQuery
    ? ` ｜ 匹配 ${helpers.formatCount(visibleRows)} / ${helpers.formatCount(allRowsCount)} 个词条`
    : ` ｜ 共 ${helpers.formatCount(totalRows)} 个词条`

  return `已对比 ${helpers.formatCount(corpusCount)} 条语料${matchSummary}${searchSummary}。表格中的差异值按“每万词频率”计算，主导语料表示当前词在相对频率上最突出的语料。`
}

function buildCompareHeaderHtml(state, helpers) {
  const dynamicHeaders = (state.currentComparisonCorpora || [])
    .map(corpus => `
      <th class="numeric-cell compare-corpus-head">
        <div>${helpers.escapeHtml(corpus.corpusName)}</div>
        <small>${helpers.formatCount(corpus.tokenCount)} Token</small>
      </th>
    `)
    .join('')

  return `<tr><th class="numeric-cell">Rank</th><th>词</th><th class="numeric-cell">覆盖语料</th><th class="numeric-cell">总频次</th><th class="numeric-cell">差异值 / 万词</th><th>主导语料</th>${dynamicHeaders}</tr>`
}

function buildCompareRowHtml(item, index, startIndex, state, helpers) {
  const corpusCount = (state.currentComparisonCorpora || []).length
  const perCorpusCells = (item.perCorpus || [])
    .map(entry => {
      const dominantClass = entry.corpusId === item.dominantCorpusId ? ' is-dominant' : ''
      return `
        <td class="numeric-cell compare-corpus-cell${dominantClass}">
          <div class="mono-readout">${helpers.formatCount(entry.count)}</div>
          <div class="compare-cell-note">${entry.normFreq.toFixed(1)}/万</div>
        </td>
      `
    })
    .join('')

  return `
    <tr>
      <td class="numeric-cell mono-readout">${helpers.formatCount(startIndex + index + 1)}</td>
      <td>${helpers.escapeHtml(item.word)}</td>
      <td class="numeric-cell mono-readout">${helpers.formatCount(item.spread)} / ${helpers.formatCount(corpusCount)}</td>
      <td class="numeric-cell mono-readout">${helpers.formatCount(item.total)}</td>
      <td class="numeric-cell mono-readout">${item.range.toFixed(2)}</td>
      <td>${helpers.escapeHtml(item.dominantCorpusName || '--')}</td>
      ${perCorpusCells}
    </tr>
  `
}

function buildExportHeaderRow(state) {
  const dynamicHeaders = []
  for (const corpus of state.currentComparisonCorpora || []) {
    dynamicHeaders.push(`${corpus.corpusName} 频次`, `${corpus.corpusName} 每万词`)
  }

  return ['Rank', '词', '覆盖语料', '总频次', '差异值（每万词）', '主导语料', ...dynamicHeaders]
}

function buildExportRows(rows, state, startIndex) {
  if (!Array.isArray(rows) || rows.length === 0) return []
  const corpusCount = (state.currentComparisonCorpora || []).length
  const result = [buildExportHeaderRow(state)]

  for (let index = 0; index < rows.length; index += 1) {
    const item = rows[index]
    const row = [
      startIndex + index + 1,
      item.word,
      `${item.spread} / ${corpusCount}`,
      item.total,
      item.range.toFixed(4),
      item.dominantCorpusName || ''
    ]

    for (const entry of item.perCorpus || []) {
      row.push(entry.count, entry.normFreq.toFixed(4))
    }

    result.push(row)
  }

  return result
}

export function renderCompareSection(state, dom, helpers) {
  if (dom.compareSummaryWrapper) {
    dom.compareSummaryWrapper.innerHTML = buildCompareSummaryHtml(state, helpers)
  }

  const { pageRows, currentComparePage, totalPages, totalRows, startIndex } = getCurrentComparePageRows(state)
  const visibleRows = Array.isArray(state.currentDisplayedCompareRows) ? state.currentDisplayedCompareRows.length : 0

  dom.compareMeta.textContent = buildCompareMetaText(state, helpers, totalRows, visibleRows)

  if (!state.comparisonEligible || !state.hasStats) {
    helpers.cancelTableRender(dom.compareWrapper)
    dom.compareTotalRowsInfo.textContent = !state.comparisonEligible ? '至少需要 2 条语料' : '等待统计结果'
    dom.comparePageInfo.textContent = '第 0 / 0 页'
    dom.comparePrevPageButton.disabled = true
    dom.compareNextPageButton.disabled = true
    dom.compareWrapper.innerHTML = `<div class="empty-tip">${
      !state.comparisonEligible
        ? '载入两条以上已保存语料后，这里会显示多语料词频对比表。'
        : '当前工作区已就绪。点击“开始统计”后生成多语料对比结果。'
    }</div>`
    return { currentComparePage: 1 }
  }

  if (state.currentSearchError) {
    helpers.cancelTableRender(dom.compareWrapper)
    dom.compareTotalRowsInfo.textContent = 'SearchQuery 无效'
    dom.comparePageInfo.textContent = '第 0 / 0 页'
    dom.comparePrevPageButton.disabled = true
    dom.compareNextPageButton.disabled = true
    dom.compareWrapper.innerHTML = `<div class="empty-tip">${helpers.escapeHtml(state.currentSearchError)}</div>`
    return { currentComparePage: 1 }
  }

  if (totalRows === 0) {
    helpers.cancelTableRender(dom.compareWrapper)
    dom.compareTotalRowsInfo.textContent = state.currentSearchQuery ? '匹配 0 个词条' : '共 0 个词条'
    dom.comparePageInfo.textContent = '第 0 / 0 页'
    dom.comparePrevPageButton.disabled = true
    dom.compareNextPageButton.disabled = true
    dom.compareWrapper.innerHTML = `<div class="empty-tip">${
      state.currentSearchQuery
        ? `没有匹配“${helpers.escapeHtml(state.currentSearchQuery)}”的对比结果`
        : '当前多语料工作区还没有可显示的对比结果'
    }</div>`
    return { currentComparePage: 1 }
  }

  const isShowingAllRows = dom.comparePageSizeSelect.value === 'all'
  dom.compareTotalRowsInfo.textContent = state.currentSearchQuery
    ? `共 ${helpers.formatCount(state.currentComparisonRows.length)} 个词条（匹配 ${helpers.formatCount(totalRows)} 个）`
    : `共 ${helpers.formatCount(totalRows)} 个词条`
  dom.comparePageInfo.textContent = isShowingAllRows ? '全部显示' : `第 ${currentComparePage} / ${totalPages} 页`
  dom.comparePrevPageButton.disabled = isShowingAllRows || currentComparePage === 1
  dom.compareNextPageButton.disabled = isShowingAllRows || currentComparePage === totalPages

  helpers.renderTableInChunks({
    container: dom.compareWrapper,
    rows: pageRows,
    tableClassName: 'fit-data-table compare-table',
    headerHtml: buildCompareHeaderHtml(state, helpers),
    rowUnit: '词条',
    emptyHtml: '<div class="empty-tip">当前多语料工作区还没有可显示的对比结果</div>',
    renderRow: (item, index) => buildCompareRowHtml(item, index, startIndex, state, helpers)
  })

  return { currentComparePage }
}

export function buildCompareRows(state) {
  const { pageRows, startIndex } = getCurrentComparePageRows(state)
  return buildExportRows(pageRows, state, startIndex)
}

export function buildAllCompareRows(state) {
  const rows = Array.isArray(state.currentDisplayedCompareRows) ? state.currentDisplayedCompareRows : []
  return buildExportRows(rows, state, 0)
}
