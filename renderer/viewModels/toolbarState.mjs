function buildCancelButtonState(isActive, isCancelling, defaultLabel) {
  return {
    hidden: !isActive,
    disabled: !isActive || isCancelling,
    label: isCancelling ? '正在取消...' : defaultLabel
  }
}

export function buildAnalysisActionButtonState({
  isCorpusLoading = false,
  activeCancelableAnalysis = '',
  cancellingAnalysis = '',
  currentAnalysisMode = 'full'
} = {}) {
  const disablePrimaryActions = isCorpusLoading || Boolean(activeCancelableAnalysis)
  const segmentedSearchDisabled = currentAnalysisMode === 'segmented'
  const segmentedSearchTitle = segmentedSearchDisabled
    ? '分段分析模式下为保证稳定性，KWIC 暂不可用'
    : ''

  return {
    primaryActionsDisabled: disablePrimaryActions,
    segmentedSearchDisabled,
    buttons: {
      count: {
        disabled: disablePrimaryActions
      },
      ngram: {
        disabled: disablePrimaryActions
      },
      kwic: {
        disabled: disablePrimaryActions || segmentedSearchDisabled,
        title: segmentedSearchTitle
      },
      collocate: {
        disabled: disablePrimaryActions || segmentedSearchDisabled,
        title: segmentedSearchTitle
      },
      cancelStats: buildCancelButtonState(
        activeCancelableAnalysis === 'stats',
        cancellingAnalysis === 'stats',
        '取消统计'
      ),
      cancelKwic: buildCancelButtonState(
        activeCancelableAnalysis === 'kwic',
        cancellingAnalysis === 'kwic',
        '取消 KWIC'
      ),
      cancelCollocate: buildCancelButtonState(
        activeCancelableAnalysis === 'collocate',
        cancellingAnalysis === 'collocate',
        '取消 Collocate'
      )
    }
  }
}

export function buildLoadSelectedCorporaButtonState(selectedCount = 0) {
  const safeCount = Math.max(0, Number(selectedCount) || 0)
  return {
    disabled: safeCount === 0,
    label: safeCount > 0 ? `载入选中语料（${safeCount}）` : '载入选中语料'
  }
}
