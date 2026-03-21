function getSentenceHighlightInfo(sentence, currentHighlight) {
  if (!currentHighlight || currentHighlight.sentenceId !== sentence.id) {
    return { leftWords: '', nodeWord: '', rightWords: '', status: '' }
  }
  return {
    leftWords: sentence.normalizedTokens.slice(currentHighlight.leftStart, currentHighlight.nodeIndex).join(' '),
    nodeWord: sentence.normalizedTokens[currentHighlight.nodeIndex] || '',
    rightWords: sentence.normalizedTokens.slice(currentHighlight.nodeIndex + 1, currentHighlight.rightEnd + 1).join(' '),
    status: '当前定位'
  }
}

function renderSentenceText(sentence, currentHighlight, escapeHtml) {
  let html = ''
  for (const part of sentence.parts) {
    const safeText = escapeHtml(part.text)
    if (!part.isWord) {
      html += safeText
      continue
    }
    let highlightClass = ''
    if (currentHighlight && currentHighlight.sentenceId === sentence.id) {
      if (part.wordIndex === currentHighlight.nodeIndex) highlightClass = 'highlight-node'
      else if (part.wordIndex >= currentHighlight.leftStart && part.wordIndex <= currentHighlight.leftEnd) highlightClass = 'highlight-left'
      else if (part.wordIndex >= currentHighlight.rightStart && part.wordIndex <= currentHighlight.rightEnd) highlightClass = 'highlight-right'
    }
    html += highlightClass ? `<span class="token-highlight ${highlightClass}">${safeText}</span>` : safeText
  }
  return html
}

export function renderSentenceViewer(state, dom, helpers) {
  if (state.currentSentenceObjects.length === 0) {
    helpers.cancelTableRender(dom.sentenceViewer)
    dom.sentenceViewer.innerHTML = '<div class="empty-tip">这里会显示原文定位表</div>'
    return { locatorNeedsRender: false }
  }

  helpers.renderTableInChunks({
    container: dom.sentenceViewer,
    rows: state.currentSentenceObjects,
    headerHtml: '<tr><th class="numeric-cell">句号</th><th>原句</th><th>左窗口词</th><th>节点词</th><th>右窗口词</th><th>状态</th></tr>',
    rowUnit: '句',
    virtualize: false,
    emptyHtml: '<div class="empty-tip">这里会显示原文定位表</div>',
    renderRow: sentence => {
      const info = getSentenceHighlightInfo(sentence, state.currentHighlight)
      const activeClass = sentence.id === state.activeSentenceId ? 'active' : ''
      return `<tr class="locator-row ${activeClass}" id="sentence-${sentence.id}" data-sentence-id="${sentence.id}">
        <td class="numeric-cell mono-readout">${helpers.formatCount(sentence.id + 1)}</td>
        <td>${renderSentenceText(sentence, state.currentHighlight, helpers.escapeHtml)}</td>
        <td>${helpers.escapeHtml(info.leftWords)}</td>
        <td>${helpers.escapeHtml(info.nodeWord)}</td>
        <td>${helpers.escapeHtml(info.rightWords)}</td>
        <td>${helpers.escapeHtml(info.status)}</td>
      </tr>`
    },
    onChunkRendered: () => {
      if (state.pendingLocatorScrollSentenceId === null) return
      const target = document.getElementById(`sentence-${state.pendingLocatorScrollSentenceId}`)
      if (!target) return
      helpers.onSentenceVisible(target)
    }
  })

  return { locatorNeedsRender: false }
}

export function buildLocatorHighlight(sentenceId, nodeIndex, leftWindowSize, rightWindowSize) {
  return {
    sentenceId,
    nodeIndex,
    leftStart: Math.max(0, nodeIndex - leftWindowSize),
    leftEnd: nodeIndex - 1,
    rightStart: nodeIndex + 1,
    rightEnd: nodeIndex + rightWindowSize
  }
}

export function buildLocatorRows(state) {
  if (state.currentSentenceObjects.length === 0) return []
  const result = [['句号', '原句', '左窗口词', '节点词', '右窗口词', '状态']]
  for (const sentence of state.currentSentenceObjects) {
    const info = getSentenceHighlightInfo(sentence, state.currentHighlight)
    result.push([sentence.id + 1, sentence.text, info.leftWords, info.nodeWord, info.rightWords, info.status])
  }
  return result
}
