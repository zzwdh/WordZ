import Foundation

extension CollocatePageViewModel {
    var currentRunConfiguration: CollocateRunConfiguration {
        CollocateRunConfiguration(
            query: normalizedKeyword,
            searchOptions: searchOptions,
            leftWindow: leftWindowValue,
            rightWindow: rightWindowValue,
            minFreq: minFreqValue
        )
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let revision = beginSceneBuildPass()
        let configuration = lastRunConfiguration ?? currentRunConfiguration
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.rows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let filteredRows = resolvedFilteredRows(for: result)
            let sortedRows = resolvedSortedRows(filteredRows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "collocate", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: configuration.query,
                    searchOptions: configuration.searchOptions,
                    stopwordFilter: stopwordFilter,
                    annotationState: annotationState,
                    focusMetric: focusMetric,
                    leftWindow: configuration.leftWindow,
                    rightWindow: configuration.rightWindow,
                    minFreq: configuration.minFreq,
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
            syncSelectedRow()
            return
        }

        let resultSnapshot = result
        let stopwordSnapshot = stopwordFilter
        let annotationStateSnapshot = annotationState
        let focusMetricSnapshot = focusMetric
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let configurationSnapshot = configuration

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "collocate", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let filteredRows = sceneBuilder.filterRows(
                    from: resultSnapshot.rows,
                    stopwordFilter: stopwordSnapshot
                )
                try Task.checkCancellation()
                let sortedRows = sceneBuilder.sortRows(filteredRows, mode: sortSnapshot)
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: configurationSnapshot.query,
                    searchOptions: configurationSnapshot.searchOptions,
                    stopwordFilter: stopwordSnapshot,
                    annotationState: annotationStateSnapshot,
                    focusMetric: focusMetricSnapshot,
                    leftWindow: configurationSnapshot.leftWindow,
                    rightWindow: configurationSnapshot.rightWindow,
                    minFreq: configurationSnapshot.minFreq,
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
                self.syncSelectedRow()
                return true
            }
        )
    }

    func syncSelectedRow() {
        guard let scene else {
            selectedRowID = nil
            return
        }
        if let selectedRowID,
           scene.rows.contains(where: { $0.id == selectedRowID }) {
            return
        }
        selectedRowID = scene.rows.first?.id
    }
}
