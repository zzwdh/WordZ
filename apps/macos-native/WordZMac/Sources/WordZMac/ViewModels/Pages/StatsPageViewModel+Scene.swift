import Foundation

extension StatsPageViewModel {
    func rebuildScene() {
        guard let result else {
            scene = nil
            sceneResultGeneration = resultGeneration
            onSceneChange?()
            return
        }
        sceneBuildRevision += 1
        let revision = sceneBuildRevision
        let resultGenerationSnapshot = resultGeneration
        let resultSnapshot = result
        let definitionSnapshot = definition
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.frequencyRows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let sortedRows = resolvedSortedRows(for: result)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "stats", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    definition: definition,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    sortedRows: sortedRows
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            sceneResultGeneration = resultGenerationSnapshot
            onSceneChange?()
            return
        }

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "stats", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let sortedRows = sceneBuilder.sortedRows(
                    from: resultSnapshot.frequencyRows,
                    mode: sortSnapshot,
                    definition: definitionSnapshot
                )
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    definition: definitionSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    sortedRows: sortedRows
                )
                return (sortedRows, nextScene)
            },
            apply: { payload in
                let (sortedRows, nextScene) = payload
                guard revision == self.sceneBuildRevision else { return false }
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

    func resolvedSortedRows(for result: StatsResult) -> [FrequencyRow] {
        if let cachedSortedRows,
           cachedSortMode == sortMode,
           cachedDefinition == definition {
            return cachedSortedRows
        }
        let sortedRows = sceneBuilder.sortedRows(
            from: result.frequencyRows,
            mode: sortMode,
            definition: definition
        )
        cachedSortedRows = sortedRows
        cachedSortMode = sortMode
        cachedDefinition = definition
        return sortedRows
    }

    func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
        cachedDefinition = nil
    }
}
