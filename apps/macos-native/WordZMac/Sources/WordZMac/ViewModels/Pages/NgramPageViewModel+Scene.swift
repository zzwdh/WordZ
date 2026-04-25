import Foundation

extension NgramPageViewModel {
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
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.rows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let filtered = resolvedFilteredRows(for: result)
            let sortedRows = resolvedSortedRows(filtered.rows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "ngram", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: normalizedQuery,
                    searchOptions: searchOptions,
                    stopwordFilter: stopwordFilter,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    filteredRows: filtered.rows,
                    sortedRows: sortedRows,
                    searchError: filtered.error
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            return
        }

        let resultSnapshot = result
        let querySnapshot = normalizedQuery
        let optionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "ngram", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let filtered = sceneBuilder.filterRows(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot
                )
                try Task.checkCancellation()
                let sortedRows = sceneBuilder.sortRows(filtered.rows, mode: sortSnapshot)
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    filteredRows: filtered.rows,
                    sortedRows: sortedRows,
                    searchError: filtered.error
                )
                return (filtered.rows, filtered.error, sortedRows, nextScene)
            },
            apply: { payload in
                let (filteredRows, filteredError, sortedRows, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedFilteredRows = filteredRows
                self.cachedFilteredError = filteredError
                self.cachedFilterQuery = querySnapshot
                self.cachedFilterOptions = optionsSnapshot
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedSortedRows = sortedRows
                self.cachedSortMode = sortSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                return true
            }
        )
    }
}
