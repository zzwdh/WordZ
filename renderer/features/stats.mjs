import { buildPaginationDisplayState } from '../viewModels/paginationState.mjs'

export function renderWorkspaceOverview(state, dom, { formatCount }) {
  if (!state.currentCorpusDisplayName) {
    dom.workspaceCorpusValue.textContent = '未载入'
    dom.workspaceCorpusNote.textContent = '导入语料后会在这里显示当前分析对象。'
    dom.workspaceModeValue.textContent = '待载入'
    dom.workspaceModeNote.textContent = '目前还没有可分析的语料。'
    dom.workspaceTokenValue.textContent = '0 / 0'
    dom.workspaceTokenNote.textContent = '点击“开始统计”后会同步更新摘要。'
    dom.workspaceMetricValue.textContent = '--'
    dom.workspaceMetricNote.textContent = 'TTR / STTR 待计算。'
    return
  }

  const hasStats = state.currentTokenCount > 0 || state.currentFreqRows.length > 0
  const segmentedMode = state.currentAnalysisMode === 'segmented'
  const selectedCount = Array.isArray(state.currentSelectedCorpora) ? state.currentSelectedCorpora.length : 0
  const corpusModeLabel =
    state.currentCorpusMode === 'saved-multi'
      ? '多语料工作区'
      : state.currentCorpusMode === 'saved'
        ? '已保存语料'
        : 'Quick Corpus'
  const folderLabel =
    state.currentCorpusMode === 'saved' || state.currentCorpusMode === 'saved-multi'
      ? (state.currentCorpusFolderName || '未分类')
      : '临时工作区'
  const tokenCount = state.currentTokenCount > 0 ? state.currentTokenCount : state.currentTokens.length
  const typeValue = hasStats ? formatCount(state.currentTypeCount) : '--'

  dom.workspaceCorpusValue.textContent = state.currentCorpusDisplayName
  dom.workspaceCorpusNote.textContent =
    state.currentCorpusMode === 'saved-multi'
      ? `${corpusModeLabel} · 已选 ${formatCount(selectedCount)} 条 · ${folderLabel}`
      : `${corpusModeLabel} · ${folderLabel}`

  dom.workspaceModeValue.textContent = segmentedMode
    ? '分段分析'
    : hasStats
      ? '分析就绪'
      : '语料已载入'
  dom.workspaceModeNote.textContent = segmentedMode
    ? '已启用超大语料内存保护：统计与 Ngram 可用，KWIC / Collocate 暂不可用。'
    : hasStats
      ? '当前语料已经完成统计，可继续做 KWIC / Collocate / 定位。'
      : '可以先点击“开始统计”，再进入更细的检索与搭配分析。'

  dom.workspaceTokenValue.textContent = `${formatCount(tokenCount)} / ${typeValue}`
  dom.workspaceTokenNote.textContent = hasStats
    ? segmentedMode
      ? `Token ${formatCount(tokenCount)} · Type ${formatCount(state.currentTypeCount)}（分段统计）`
      : `Token ${formatCount(tokenCount)} · Type ${formatCount(state.currentTypeCount)}`
    : `Token ${formatCount(tokenCount)} · Type 待统计`

  if (hasStats) {
    dom.workspaceMetricValue.textContent = `${state.currentTTR.toFixed(4)} / ${state.currentSTTR.toFixed(4)}`
    dom.workspaceMetricNote.textContent = 'TTR / STTR（1000词）'
  } else {
    dom.workspaceMetricValue.textContent = '--'
    dom.workspaceMetricNote.textContent = '点击“开始统计”后生成词汇丰富度指标。'
  }
}

function buildStatsSummaryHtml(state, formatCount) {
  return `
    <div class="stats-readout-grid">
      <div class="stats-readout-card">
        <div class="stats-readout-label">总词数 Token</div>
        <div class="stats-readout-value mono-readout">${formatCount(state.currentTokenCount)}</div>
        <div class="stats-readout-note">语料中的全部词项数量</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">不重复词数 Type</div>
        <div class="stats-readout-value mono-readout">${formatCount(state.currentTypeCount)}</div>
        <div class="stats-readout-note">去重后的词汇条目数量</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">TTR</div>
        <div class="stats-readout-value mono-readout">${state.currentTTR.toFixed(4)}</div>
        <div class="stats-readout-note">Type / Token 比率</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">STTR（1000词）</div>
        <div class="stats-readout-value mono-readout">${state.currentSTTR.toFixed(4)}</div>
        <div class="stats-readout-note">按 1000 词分块的平均 TTR</div>
      </div>
    </div>
  `
}

export function renderStatsSummary(state, dom, helpers) {
  dom.statsSummaryWrapper.innerHTML = buildStatsSummaryHtml(state, helpers.formatCount)
  renderWorkspaceOverview(state, dom, helpers)
}

export function renderWordCloud(state, dom, helpers) {
  if (!dom.wordCloudMeta || !dom.wordCloudWrapper) return
  const stopwordSummary = state.currentStopwordFilter?.enabled ? ` ｜ ${state.currentStopwordSummary}` : ''

  if (state.currentSearchError) {
    dom.wordCloudMeta.textContent = `SearchQuery 当前无效。${stopwordSummary}`.trim()
    dom.wordCloudWrapper.innerHTML = `<div class="empty-tip">${helpers.escapeHtml(state.currentSearchError)}</div>`
    return
  }

  const rows = (state.currentDisplayedFreqRows || []).slice(0, 80)
  if (rows.length === 0) {
    dom.wordCloudMeta.textContent = '开始统计后会根据高频词生成词云。'
    dom.wordCloudWrapper.innerHTML = '<div class="empty-tip">这里会显示当前语料的高频词云。</div>'
    return
  }

  const maxCount = rows[0][1]
  const minCount = rows[rows.length - 1][1]
  const scaleRange = Math.max(maxCount - minCount, 1)
  const cloudHtml = rows
    .map(([word, count], index) => {
      const ratio = (count - minCount) / scaleRange
      const fontSize = 14 + ratio * 28
      const fontWeight = 520 + Math.round(ratio * 260)
      const accentClass = index < 12 ? ' is-accent' : ''
      return `<button class="word-cloud-item${accentClass}" type="button" data-word-cloud-term="${helpers.escapeHtml(word)}" style="font-size:${fontSize.toFixed(1)}px;font-weight:${fontWeight};" title="${helpers.escapeHtml(word)} · ${helpers.formatCount(count)}">${helpers.escapeHtml(word)}</button>`
    })
    .join('')

  dom.wordCloudMeta.textContent = state.currentSearchQuery
    ? `基于当前 SearchQuery 展示前 ${helpers.formatCount(rows.length)} 个词。点击任一词可继续检索。${stopwordSummary}`
    : `展示当前语料中前 ${helpers.formatCount(rows.length)} 个高频词。点击任一词可继续检索。${stopwordSummary}`
  dom.wordCloudWrapper.innerHTML = `<div class="word-cloud-grid">${cloudHtml}</div>`
}

function getCurrentFrequencyPageRows({ currentDisplayedFreqRows, currentPage, pageSize }) {
  const rows = Array.isArray(currentDisplayedFreqRows) ? currentDisplayedFreqRows : []
  const totalRows = rows.length
  if (totalRows === 0) {
    return { pageRows: [], currentPage: 1, totalPages: 0, totalRows }
  }
  const totalPages = Math.ceil(totalRows / pageSize)
  const safePage = Math.min(currentPage, totalPages)
  const startIndex = (safePage - 1) * pageSize
  return {
    pageRows: rows.slice(startIndex, startIndex + pageSize),
    currentPage: safePage,
    totalPages,
    totalRows
  }
}

export function renderFrequencyTable(state, dom, helpers) {
  const { pageRows, currentPage, totalPages, totalRows } = getCurrentFrequencyPageRows(state)
  const hasFilter = Boolean(String(state.currentSearchQuery || '').trim())
  const allRowsCount = Array.isArray(state.currentFreqRows) ? state.currentFreqRows.length : 0
  const emptyMessage = hasFilter
    ? `没有匹配“${helpers.escapeHtml(state.currentSearchQuery)}”的词频结果`
    : '没有可显示的词频结果'

  if (totalRows === 0) {
    const paginationState = buildPaginationDisplayState({
      totalRows,
      currentPage: 1,
      totalPages: 0
    })
    helpers.cancelTableRender(dom.tableWrapper)
    dom.tableWrapper.classList.remove('show-all-results')
    if (state.currentSearchError) {
      dom.totalRowsInfo.textContent = 'SearchQuery 无效'
    } else {
      dom.totalRowsInfo.textContent = hasFilter ? `共 ${allRowsCount} 个单词（匹配 0 个）` : '共 0 个单词'
    }
    dom.pageInfo.textContent = paginationState.pageLabel
    dom.prevPageButton.disabled = paginationState.previousDisabled
    dom.nextPageButton.disabled = paginationState.nextDisabled
    dom.tableWrapper.innerHTML = `<div class="empty-tip">${state.currentSearchError ? helpers.escapeHtml(state.currentSearchError) : emptyMessage}</div>`
    return { currentPage: 1 }
  }

  const isShowingAllRows = dom.pageSizeSelect.value === 'all'
  const paginationState = buildPaginationDisplayState({
    totalRows,
    currentPage,
    totalPages,
    showAll: isShowingAllRows
  })
  dom.tableWrapper.classList.toggle('show-all-results', isShowingAllRows)
  dom.totalRowsInfo.textContent = hasFilter
    ? `共 ${allRowsCount} 个单词（匹配 ${totalRows} 个）`
    : `共 ${totalRows} 个单词`
  dom.pageInfo.textContent = paginationState.pageLabel
  dom.prevPageButton.disabled = paginationState.previousDisabled
  dom.nextPageButton.disabled = paginationState.nextDisabled
  helpers.renderTableInChunks({
    container: dom.tableWrapper,
    rows: pageRows,
    tableClassName: 'fit-data-table',
    headerHtml: '<tr><th>词</th><th class="numeric-cell">频次</th><th class="numeric-cell">相对频率</th></tr>',
    rowUnit: '词条',
    virtualize: !isShowingAllRows,
    emptyHtml: `<div class="empty-tip">${emptyMessage}</div>`,
    renderRow: ([word, count]) => {
      const relativeFreq = ((count / state.currentTokens.length) * 100).toFixed(2) + '%'
      return `<tr><td>${helpers.escapeHtml(word)}</td><td class="numeric-cell mono-readout">${helpers.formatCount(count)}</td><td class="numeric-cell mono-readout">${relativeFreq}</td></tr>`
    }
  })

  return { currentPage }
}

export function buildStatsRows(state) {
  return [['指标', '数值'], ['总词数（Token）', state.currentTokenCount], ['不重复词数（Type）', state.currentTypeCount], ['TTR', state.currentTTR.toFixed(4)], ['STTR（1000词）', state.currentSTTR.toFixed(4)]]
}

export function buildFrequencyRows(state) {
  const { pageRows } = getCurrentFrequencyPageRows(state)
  if (pageRows.length === 0) return []
  const result = [['词', '频次', '相对频率']]
  for (const [word, count] of pageRows) {
    result.push([word, count, ((count / state.currentTokens.length) * 100).toFixed(2) + '%'])
  }
  return result
}

export function buildAllFrequencyRows(state) {
  if (state.currentDisplayedFreqRows.length === 0) return []
  const result = [['词', '频次', '相对频率']]
  for (const [word, count] of state.currentDisplayedFreqRows) {
    result.push([word, count, ((count / state.currentTokens.length) * 100).toFixed(2) + '%'])
  }
  return result
}
