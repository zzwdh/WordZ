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
  const corpusModeLabel = state.currentCorpusMode === 'saved' ? '已保存语料' : 'Quick Corpus'
  const folderLabel = state.currentCorpusMode === 'saved' ? (state.currentCorpusFolderName || '未分类') : '临时工作区'
  const tokenCount = state.currentTokenCount > 0 ? state.currentTokenCount : state.currentTokens.length
  const typeValue = hasStats ? formatCount(state.currentTypeCount) : '--'

  dom.workspaceCorpusValue.textContent = state.currentCorpusDisplayName
  dom.workspaceCorpusNote.textContent = `${corpusModeLabel} · ${folderLabel}`

  dom.workspaceModeValue.textContent = hasStats ? '分析就绪' : '语料已载入'
  dom.workspaceModeNote.textContent = hasStats
    ? '当前语料已经完成统计，可继续做 KWIC / Collocate / 定位。'
    : '可以先点击“开始统计”，再进入更细的检索与搭配分析。'

  dom.workspaceTokenValue.textContent = `${formatCount(tokenCount)} / ${typeValue}`
  dom.workspaceTokenNote.textContent = hasStats
    ? `Token ${formatCount(tokenCount)} · Type ${formatCount(state.currentTypeCount)}`
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

function getCurrentFrequencyPageRows({ currentFreqRows, currentPage, pageSize }) {
  const totalRows = currentFreqRows.length
  if (totalRows === 0) {
    return { pageRows: [], currentPage: 1, totalPages: 0, totalRows }
  }
  const totalPages = Math.ceil(totalRows / pageSize)
  const safePage = Math.min(currentPage, totalPages)
  const startIndex = (safePage - 1) * pageSize
  return {
    pageRows: currentFreqRows.slice(startIndex, startIndex + pageSize),
    currentPage: safePage,
    totalPages,
    totalRows
  }
}

export function renderFrequencyTable(state, dom, helpers) {
  const { pageRows, currentPage, totalPages, totalRows } = getCurrentFrequencyPageRows(state)

  if (totalRows === 0) {
    helpers.cancelTableRender(dom.tableWrapper)
    dom.totalRowsInfo.textContent = '共 0 个单词'
    dom.pageInfo.textContent = '第 0 / 0 页'
    dom.prevPageButton.disabled = true
    dom.nextPageButton.disabled = true
    dom.tableWrapper.innerHTML = '<div class="empty-tip">没有可显示的词频结果</div>'
    return { currentPage: 1 }
  }

  const isShowingAllRows = dom.pageSizeSelect.value === 'all'
  dom.totalRowsInfo.textContent = `共 ${totalRows} 个单词`
  dom.pageInfo.textContent = isShowingAllRows ? '全部显示' : `第 ${currentPage} / ${totalPages} 页`
  dom.prevPageButton.disabled = isShowingAllRows || currentPage === 1
  dom.nextPageButton.disabled = isShowingAllRows || currentPage === totalPages
  helpers.renderTableInChunks({
    container: dom.tableWrapper,
    rows: pageRows,
    headerHtml: '<tr><th>词</th><th class="numeric-cell">频次</th><th class="numeric-cell">相对频率</th></tr>',
    rowUnit: '词条',
    emptyHtml: '<div class="empty-tip">没有可显示的词频结果</div>',
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
  if (state.currentFreqRows.length === 0) return []
  const result = [['词', '频次', '相对频率']]
  for (const [word, count] of state.currentFreqRows) {
    result.push([word, count, ((count / state.currentTokens.length) * 100).toFixed(2) + '%'])
  }
  return result
}
