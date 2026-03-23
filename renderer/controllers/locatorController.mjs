import {
  buildLocatorHighlight,
  renderSentenceViewer as renderSentenceViewerSection
} from '../features/locator.mjs'

export function createLocatorController({
  dom,
  electronAPI,
  cancelTableRender,
  escapeHtml,
  formatCount,
  renderTableInChunks,
  getLocatorState,
  getCurrentCorpusId,
  loadCorpusResult,
  showAlert,
  switchTab,
  setActiveSentenceId,
  setCurrentHighlight,
  setPendingLocatorScrollSentenceId,
  setLocatorNeedsRender
}) {
  const {
    kwicWrapper,
    sentenceViewer,
    locatorMeta
  } = dom

  function renderSentenceViewer() {
    const result = renderSentenceViewerSection(getLocatorState(), dom, {
      cancelTableRender,
      escapeHtml,
      formatCount,
      onSentenceVisible: target => {
        setPendingLocatorScrollSentenceId(null)
        requestAnimationFrame(() => {
          target.scrollIntoView({ behavior: 'smooth', block: 'center' })
        })
      },
      renderTableInChunks
    })
    setLocatorNeedsRender(result.locatorNeedsRender)
  }

  function locateSentence(sentenceId, nodeIndex, leftWindowSize, rightWindowSize) {
    setActiveSentenceId(sentenceId)
    setPendingLocatorScrollSentenceId(sentenceId)
    setCurrentHighlight(buildLocatorHighlight(sentenceId, nodeIndex, leftWindowSize, rightWindowSize))
    renderSentenceViewer()
    if (locatorMeta) {
      locatorMeta.textContent = `已定位到第 ${sentenceId + 1} 句。节点词为黄色，左侧上下文为蓝色，右侧上下文为绿色。`
    }
  }

  function bindLocatorEvents() {
    kwicWrapper?.addEventListener('click', async event => {
      const row = event.target.closest('tr[data-sentence-id]')
      if (!row) return
      const corpusId = row.dataset.corpusId || ''
      if (corpusId && corpusId !== getCurrentCorpusId()) {
        const result = await electronAPI.openSavedCorpus(corpusId)
        if (!result?.success) {
          await showAlert({
            title: '打开命中语料失败',
            message: result?.message || '无法打开对应语料'
          })
          return
        }
        await loadCorpusResult(result)
      }
      const sentenceId = Number(row.dataset.sentenceId)
      const nodeIndex = Number(row.dataset.nodeIndex)
      const leftWindowSize = Number(row.dataset.leftWindow)
      const rightWindowSize = Number(row.dataset.rightWindow)
      locateSentence(sentenceId, nodeIndex, leftWindowSize, rightWindowSize)
      switchTab('locator')
    })

    sentenceViewer?.addEventListener('click', event => {
      const row = event.target.closest('tr[data-sentence-id]')
      if (!row) return
      const sentenceId = Number(row.dataset.sentenceId)
      setActiveSentenceId(sentenceId)
      setCurrentHighlight(null)
      renderSentenceViewer()
      if (locatorMeta) {
        locatorMeta.textContent = `已定位到第 ${sentenceId + 1} 句。`
      }
    })
  }

  return {
    bindLocatorEvents,
    locateSentence,
    renderSentenceViewer
  }
}
