import Foundation

extension KeywordPageViewModel {
    var currentRunConfiguration: KeywordRunConfiguration {
        KeywordRunConfiguration(
            targetCorpusID: selectedTargetCorpusID,
            referenceCorpusID: selectedReferenceCorpusID,
            options: preprocessingOptions
        )
    }

    func normalizeSelections() {
        let validIDs = Set(availableCorpora.map(\.id))
        if let selectedTargetCorpusID, !validIDs.contains(selectedTargetCorpusID) {
            self.selectedTargetCorpusID = nil
        }
        if let selectedReferenceCorpusID, !validIDs.contains(selectedReferenceCorpusID) {
            self.selectedReferenceCorpusID = nil
        }

        if selectedTargetCorpusID == nil {
            selectedTargetCorpusID = availableCorpora.first?.id
        }

        if selectedReferenceCorpusID == selectedTargetCorpusID {
            selectedReferenceCorpusID = nil
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            selectedRowID = nil
            return
        }
        let revision = beginSceneBuildPass()
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let configuration = lastRunConfiguration ?? currentRunConfiguration
        let targetLabel = selectedTargetCorpusItem()?.name ?? result.targetCorpus.corpusName
        let referenceLabel = selectedReferenceCorpusItem()?.name ?? result.referenceCorpus.corpusName
        let rowCount = result.rows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let sortedRows = resolvedSortedRows(for: result)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "keyword", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    targetLabel: targetLabel,
                    referenceLabel: referenceLabel,
                    options: configuration.options,
                    hasPendingRunChanges: hasPendingRunChanges,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    sortedRows: sortedRows
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            syncSelectedRow()
            return
        }

        let resultSnapshot = result
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let optionsSnapshot = configuration.options
        let hasPendingRunChangesSnapshot = hasPendingRunChanges

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "keyword", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let sortedRows = sceneBuilder.sortRows(resultSnapshot.rows, mode: sortSnapshot)
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    targetLabel: targetLabel,
                    referenceLabel: referenceLabel,
                    options: optionsSnapshot,
                    hasPendingRunChanges: hasPendingRunChangesSnapshot,
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
                guard self.isCurrentSceneBuild(revision) else { return false }
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
        syncSelectedRow(within: scene?.rows ?? [])
    }
}
