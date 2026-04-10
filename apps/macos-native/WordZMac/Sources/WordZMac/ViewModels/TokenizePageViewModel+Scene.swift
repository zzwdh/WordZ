import Foundation

extension TokenizePageViewModel {
    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let revision = beginSceneBuildPass()
        let querySnapshot = AnalysisViewModelSupport.normalizedQuery(query)
        let searchOptionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let languagePresetSnapshot = languagePreset
        let lemmaStrategySnapshot = lemmaStrategy
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.tokenCount

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let presetFilteredTokens = resolvedPresetFilteredTokens(for: result)
            let filtered = resolvedFilteredTokens(for: result)
            let sortedTokens = resolvedSortedTokens(filtered.rows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "tokenize", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    languagePreset: languagePresetSnapshot,
                    lemmaStrategy: lemmaStrategySnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    presetFilteredTokens: presetFilteredTokens,
                    filteredTokens: filtered.rows,
                    sortedTokens: sortedTokens,
                    searchError: filtered.error
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            syncSelectedRow(within: scene?.rows ?? [])
            return
        }

        let resultSnapshot = result

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "tokenize", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let presetFilteredTokens = sceneBuilder.filterPresetTokens(
                    from: resultSnapshot,
                    languagePreset: languagePresetSnapshot
                )
                let filtered = sceneBuilder.filterRows(
                    presetFilteredTokens,
                    query: querySnapshot,
                    options: searchOptionsSnapshot,
                    stopword: stopwordSnapshot,
                    lemmaStrategy: lemmaStrategySnapshot
                )
                let sortedTokens = sceneBuilder.sortRows(
                    filtered.rows,
                    mode: sortSnapshot,
                    lemmaStrategy: lemmaStrategySnapshot
                )
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    languagePreset: languagePresetSnapshot,
                    lemmaStrategy: lemmaStrategySnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    presetFilteredTokens: presetFilteredTokens,
                    filteredTokens: filtered.rows,
                    sortedTokens: sortedTokens,
                    searchError: filtered.error
                )
                return (presetFilteredTokens, filtered.rows, filtered.error, sortedTokens, nextScene)
            },
            apply: { payload in
                let (presetFilteredTokens, filteredTokens, filteredError, sortedTokens, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedPresetFilteredTokens = presetFilteredTokens
                self.cachedLanguagePreset = languagePresetSnapshot
                self.cachedFilteredTokens = filteredTokens
                self.cachedFilteredError = filteredError
                self.cachedFilterQuery = querySnapshot
                self.cachedFilterOptions = searchOptionsSnapshot
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedFilterLemmaStrategy = lemmaStrategySnapshot
                self.cachedSortedTokens = sortedTokens
                self.cachedSortMode = sortSnapshot
                self.cachedSortLemmaStrategy = lemmaStrategySnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                self.syncSelectedRow(within: nextScene.rows)
                return true
            }
        )
    }
}
