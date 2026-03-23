export function createSearchTabsController({
  dom,
  normalizeSearchOptions,
  getCurrentSearchQuery,
  setCurrentSearchQuery,
  getCurrentSearchOptions,
  setCurrentSearchOptions,
  setCurrentTab,
  getCurrentFreqRowsLength,
  getCurrentCompareRowsLength,
  getVisibleFrequencyRows,
  getVisibleCompareRows,
  invalidateSearchCaches,
  renderFrequencyTable,
  renderCompareSection,
  renderWordCloud,
  renderSentenceViewer,
  getLocatorNeedsRender,
  requestWorkspaceSnapshotSave,
  resetSearchDrivenPagination
}) {
  const {
    searchQueryInputs,
    searchOptionInputs,
    tabButtons,
    statsSection,
    compareSection,
    chiSquareSection,
    wordCloudSection,
    ngramSection,
    kwicSection,
    collocateSection,
    locatorSection
  } = dom

  function getTabLabel(tabName) {
    if (tabName === 'compare') return '对比分析'
    if (tabName === 'chi-square') return '卡方检验'
    if (tabName === 'word-cloud') return '词云'
    if (tabName === 'ngram') return 'Ngram'
    if (tabName === 'kwic') return 'KWIC 检索'
    if (tabName === 'collocate') return 'Collocate 统计'
    if (tabName === 'locator') return '原文定位'
    return '统计结果'
  }

  function syncSharedSearchInputs() {
    const query = String(getCurrentSearchQuery() || '')
    for (const input of searchQueryInputs || []) {
      if (input && input.value !== query) {
        input.value = query
      }
    }
  }

  function syncSearchOptionInputs() {
    const currentSearchOptions = getCurrentSearchOptions()
    for (const input of searchOptionInputs || []) {
      if (!(input instanceof HTMLInputElement)) continue
      const optionName = input.dataset.searchOption || ''
      const checked =
        optionName === 'words'
          ? currentSearchOptions.words
          : optionName === 'case'
            ? currentSearchOptions.caseSensitive
            : currentSearchOptions.regex
      input.checked = Boolean(checked)
    }
  }

  function getSearchOptionsSummary() {
    const currentSearchOptions = getCurrentSearchOptions()
    const enabled = []
    if (currentSearchOptions.words) enabled.push('Words')
    if (currentSearchOptions.caseSensitive) enabled.push('Case')
    if (currentSearchOptions.regex) enabled.push('Regex')
    return enabled.length > 0 ? enabled.join(' / ') : '默认匹配'
  }

  function rerenderSearchDrivenViews() {
    if (getCurrentFreqRowsLength() === 0 && getCurrentCompareRowsLength() === 0) {
      renderCompareSection()
      renderWordCloud()
      return
    }
    resetSearchDrivenPagination({
      visibleFrequencyCount: getVisibleFrequencyRows().length,
      visibleCompareCount: getVisibleCompareRows().length
    })
    renderFrequencyTable()
    renderCompareSection()
    renderWordCloud()
  }

  function setSharedSearchQuery(value, { rerender = true } = {}) {
    setCurrentSearchQuery(String(value || ''))
    invalidateSearchCaches({ invalidateSearchContext: true })
    syncSharedSearchInputs()
    requestWorkspaceSnapshotSave()
    if (rerender) {
      rerenderSearchDrivenViews()
    }
  }

  function setSharedSearchOption(optionName, checked, { rerender = true } = {}) {
    const nextOptions = { ...getCurrentSearchOptions() }
    if (optionName === 'words') nextOptions.words = Boolean(checked)
    else if (optionName === 'case') nextOptions.caseSensitive = Boolean(checked)
    else if (optionName === 'regex') nextOptions.regex = Boolean(checked)
    setCurrentSearchOptions(normalizeSearchOptions(nextOptions))
    invalidateSearchCaches({ invalidateSearchContext: true })
    syncSearchOptionInputs()
    requestWorkspaceSnapshotSave()
    if (rerender) {
      rerenderSearchDrivenViews()
    }
  }

  function switchTab(tabName) {
    const nextTab = tabName || 'stats'
    setCurrentTab(nextTab)
    statsSection.classList.add('hidden')
    compareSection.classList.add('hidden')
    chiSquareSection.classList.add('hidden')
    wordCloudSection.classList.add('hidden')
    ngramSection.classList.add('hidden')
    kwicSection.classList.add('hidden')
    collocateSection.classList.add('hidden')
    locatorSection.classList.add('hidden')
    tabButtons.forEach(button => button.classList.remove('active'))
    if (nextTab === 'stats') statsSection.classList.remove('hidden')
    else if (nextTab === 'compare') compareSection.classList.remove('hidden')
    else if (nextTab === 'chi-square') chiSquareSection.classList.remove('hidden')
    else if (nextTab === 'word-cloud') wordCloudSection.classList.remove('hidden')
    else if (nextTab === 'ngram') ngramSection.classList.remove('hidden')
    else if (nextTab === 'kwic') kwicSection.classList.remove('hidden')
    else if (nextTab === 'collocate') collocateSection.classList.remove('hidden')
    else if (nextTab === 'locator') {
      locatorSection.classList.remove('hidden')
      if (getLocatorNeedsRender()) renderSentenceViewer()
    }
    const activeButton = document.querySelector(`.tab-button[data-tab="${nextTab}"]`)
    if (activeButton) activeButton.classList.add('active')
    requestWorkspaceSnapshotSave()
  }

  function bindSearchAndTabEvents() {
    tabButtons.forEach(button => {
      button.addEventListener('click', () => switchTab(button.dataset.tab))
    })

    for (const input of searchQueryInputs || []) {
      input.addEventListener('input', () => {
        setSharedSearchQuery(input.value)
      })
    }

    for (const input of searchOptionInputs || []) {
      input.addEventListener('change', () => {
        const optionName = input.dataset.searchOption || ''
        setSharedSearchOption(optionName, input.checked)
      })
    }
  }

  return {
    bindSearchAndTabEvents,
    getSearchOptionsSummary,
    getTabLabel,
    setSharedSearchOption,
    setSharedSearchQuery,
    switchTab,
    syncSearchOptionInputs,
    syncSharedSearchInputs
  }
}
