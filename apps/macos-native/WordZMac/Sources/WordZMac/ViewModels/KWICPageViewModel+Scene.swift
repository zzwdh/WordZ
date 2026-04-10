import Foundation

extension KWICPageViewModel {
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
            let filteredRows = resolvedFilteredRows(for: result)
            let sortedRows = resolvedSortedRows(filteredRows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "kwic", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: normalizedKeyword,
                    searchOptions: searchOptions,
                    stopwordFilter: stopwordFilter,
                    leftWindow: leftWindowValue,
                    rightWindow: rightWindowValue,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    filteredRows: filteredRows,
                    sortedRows: sortedRows
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            syncSelectedRow(within: scene?.rows ?? [])
            return
        }

        let resultSnapshot = result
        let keywordSnapshot = normalizedKeyword
        let searchOptionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let leftWindowSnapshot = leftWindowValue
        let rightWindowSnapshot = rightWindowValue
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "kwic", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let filteredRows = sceneBuilder.filterRows(
                    from: resultSnapshot.rows,
                    stopwordFilter: stopwordSnapshot
                )
                let sortedRows = sceneBuilder.sortRows(filteredRows, mode: sortSnapshot)
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: keywordSnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    leftWindow: leftWindowSnapshot,
                    rightWindow: rightWindowSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    filteredRows: filteredRows,
                    sortedRows: sortedRows
                )
                return (filteredRows, sortedRows, nextScene)
            },
            apply: { payload in
                let (filteredRows, sortedRows, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedFilteredRows = filteredRows
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedSortedRows = sortedRows
                self.cachedSortMode = sortSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                self.syncSelectedRow(within: nextScene.rows)
                return true
            }
        )
    }
}
