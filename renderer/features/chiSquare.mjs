function formatDecimal(value, digits = 4) {
  if (!Number.isFinite(value)) return '--'
  return Number(value).toFixed(digits)
}

function formatPValue(value) {
  if (!Number.isFinite(value)) return '--'
  if (value < 0.000001) return '< 0.000001'
  return value.toFixed(6)
}

function formatOddsRatio(value) {
  if (Number.isNaN(value)) return '不可计算'
  if (!Number.isFinite(value)) return '∞'
  return value.toFixed(6)
}

function getSignificanceLabel(result) {
  if (result.pValue < 0.001) return '差异极显著（p < 0.001）'
  if (result.pValue < 0.01) return '差异显著（p < 0.01）'
  if (result.pValue < 0.05) return '差异显著（p < 0.05）'
  return '未达到显著差异（p ≥ 0.05）'
}

function buildObservedTable(result, helpers) {
  return `
    <table class="data-table fit-data-table chi-square-table">
      <thead>
        <tr>
          <th>观察频数（Observed）</th>
          <th class="numeric-cell">目标词</th>
          <th class="numeric-cell">非目标词</th>
          <th class="numeric-cell">行合计</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>语料 A</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.observed[0][0])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.observed[0][1])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.rowTotals[0])}</td>
        </tr>
        <tr>
          <td>语料 B</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.observed[1][0])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.observed[1][1])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.rowTotals[1])}</td>
        </tr>
        <tr>
          <td>列合计</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.colTotals[0])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.colTotals[1])}</td>
          <td class="numeric-cell mono-readout">${helpers.formatCount(result.total)}</td>
        </tr>
      </tbody>
    </table>
  `
}

function buildExpectedTable(result) {
  return `
    <table class="data-table fit-data-table chi-square-table">
      <thead>
        <tr>
          <th>期望频数（Expected）</th>
          <th class="numeric-cell">目标词</th>
          <th class="numeric-cell">非目标词</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>语料 A</td>
          <td class="numeric-cell mono-readout">${formatDecimal(result.expected[0][0], 4)}</td>
          <td class="numeric-cell mono-readout">${formatDecimal(result.expected[0][1], 4)}</td>
        </tr>
        <tr>
          <td>语料 B</td>
          <td class="numeric-cell mono-readout">${formatDecimal(result.expected[1][0], 4)}</td>
          <td class="numeric-cell mono-readout">${formatDecimal(result.expected[1][1], 4)}</td>
        </tr>
      </tbody>
    </table>
  `
}

function buildWarningsHtml(result, helpers) {
  if (!Array.isArray(result.warnings) || result.warnings.length === 0) return ''
  return `
    <div class="chi-square-warning-list">
      ${result.warnings.map(item => `<div class="chi-square-warning-item">${helpers.escapeHtml(item)}</div>`).join('')}
    </div>
  `
}

export function renderChiSquareResult(state, dom, helpers) {
  if (!dom.chiSquareMeta || !dom.chiSquareResultWrapper) return

  const result = state.currentChiSquareResult
  if (!result) {
    dom.chiSquareMeta.textContent = '请输入 2×2 列联表的四个频数，然后点击“计算卡方”。'
    dom.chiSquareResultWrapper.innerHTML = '<div class="empty-tip">这里会显示卡方检验统计量、显著性结论、效应量和观察/期望频数表。</div>'
    return
  }

  dom.chiSquareMeta.textContent = `卡方检验完成：${getSignificanceLabel(result)}${result.yatesCorrection ? '（已使用 Yates 连续性校正）' : ''}`
  dom.chiSquareResultWrapper.innerHTML = `
    <div class="chi-square-result-grid">
      <div class="stats-readout-card">
        <div class="stats-readout-label">Chi-Square</div>
        <div class="stats-readout-value mono-readout">${formatDecimal(result.chiSquare, 6)}</div>
        <div class="stats-readout-note">自由度 df = ${helpers.escapeHtml(String(result.degreesOfFreedom || 1))}</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">P Value</div>
        <div class="stats-readout-value mono-readout">${helpers.escapeHtml(formatPValue(result.pValue))}</div>
        <div class="stats-readout-note">${helpers.escapeHtml(getSignificanceLabel(result))}</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">Effect Size (Phi)</div>
        <div class="stats-readout-value mono-readout">${formatDecimal(result.phi, 6)}</div>
        <div class="stats-readout-note">2×2 列联表效应量</div>
      </div>
      <div class="stats-readout-card">
        <div class="stats-readout-label">Odds Ratio</div>
        <div class="stats-readout-value mono-readout">${helpers.escapeHtml(formatOddsRatio(result.oddsRatio))}</div>
        <div class="stats-readout-note">A×D / B×C</div>
      </div>
    </div>
    <div class="chi-square-table-grid">
      ${buildObservedTable(result, helpers)}
      ${buildExpectedTable(result)}
    </div>
    ${buildWarningsHtml(result, helpers)}
  `
}
