import Foundation

extension WordPageViewModel {
    func rebuildScene() {
        guard let result else {
            scene = nil
            sceneResultGeneration = resultGeneration
            onSceneChange?()
            return
        }

        let revision = beginSceneBuildPass()
        let resultGenerationSnapshot = resultGeneration
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.frequencyRows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let displayableRows = resolvedDisplayableRows(for: result)
            let filtered = resolvedFilteredRows(for: result)
            let sortedRows = resolvedSortedRows(filtered.rows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "word", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: AnalysisViewModelSupport.normalizedQuery(query),
                    searchOptions: searchOptions,
                    stopwordFilter: stopwordFilter,
                    annotationState: annotationState,
                    definition: definition,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    prefilteredDisplayableRows: displayableRows,
                    filteredRows: filtered.rows,
                    filteredError: filtered.error,
                    sortedRows: sortedRows
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            sceneResultGeneration = resultGenerationSnapshot
            onSceneChange?()
            return
        }

        let resultSnapshot = result
        let querySnapshot = AnalysisViewModelSupport.normalizedQuery(query)
        let optionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let annotationStateSnapshot = annotationState
        let definitionSnapshot = definition
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "word", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let displayableRows = sceneBuilder.displayableRows(from: resultSnapshot)
                try Task.checkCancellation()
                let filtered = sceneBuilder.filterRows(
                    from: displayableRows,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot
                )
                try Task.checkCancellation()
                let sortedRows = sceneBuilder.sortRows(
                    filtered.rows,
                    mode: sortSnapshot,
                    definition: definitionSnapshot
                )
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    annotationState: annotationStateSnapshot,
                    definition: definitionSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    prefilteredDisplayableRows: displayableRows,
                    filteredRows: filtered.rows,
                    filteredError: filtered.error,
                    sortedRows: sortedRows
                )
                return (
                    displayableRows,
                    filtered.rows,
                    filtered.error,
                    sortedRows,
                    nextScene
                )
            },
            apply: { payload in
                let (displayableRows, filteredRows, filteredError, sortedRows, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedDisplayableRows = displayableRows
                self.cachedFilteredRows = filteredRows
                self.cachedFilteredError = filteredError
                self.cachedFilterQuery = querySnapshot
                self.cachedFilterOptions = optionsSnapshot
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedSortedRows = sortedRows
                self.cachedSortMode = sortSnapshot
                self.cachedDefinition = definitionSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                self.sceneResultGeneration = resultGenerationSnapshot
                self.onSceneChange?()
                return true
            }
        )
    }
}
