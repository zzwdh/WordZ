import Foundation

extension ComparePageViewModel {
    var normalizedQuery: String {
        AnalysisViewModelSupport.normalizedQuery(query)
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            selectedRowID = nil
            return
        }
        let revision = beginSceneBuildPass()
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.rows.count

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let filtered = resolvedFilteredRows(for: result)
            let derivedRows = resolvedDerivedRows(filtered.rows, languageMode: languageModeSnapshot)
            let sortedRows = resolvedSortedRows(derivedRows)
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "compare", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    selection: selectionItems,
                    from: result,
                    query: normalizedQuery,
                    searchOptions: searchOptions,
                    stopwordFilter: stopwordFilter,
                    referenceSelection: selectedReferenceSelection,
                    referenceCorpusSets: availableCorpusSets,
                    sortMode: sortMode,
                    pageSize: pageSize,
                    currentPage: currentPage,
                    visibleColumns: visibleColumns,
                    languageMode: languageModeSnapshot,
                    filteredRows: filtered.rows,
                    derivedRows: derivedRows,
                    sortedRows: sortedRows,
                    searchError: filtered.error
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            syncSelectedRow()
            return
        }

        let selectionSnapshot = selectionItems
        let resultSnapshot = result
        let querySnapshot = normalizedQuery
        let optionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let referenceSelectionSnapshot = selectedReferenceSelection
        let referenceCorpusSetsSnapshot = availableCorpusSets

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "compare", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let filtered = sceneBuilder.filterRows(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot
                )
                let derivedRows = sceneBuilder.buildDerivedRows(
                    from: filtered.rows,
                    referenceSelection: referenceSelectionSnapshot,
                    referenceCorpusSets: referenceCorpusSetsSnapshot,
                    languageMode: languageModeSnapshot
                )
                let sortedRows = sceneBuilder.sortRows(derivedRows, mode: sortSnapshot)
                let nextScene = sceneBuilder.build(
                    selection: selectionSnapshot,
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: optionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    referenceSelection: referenceSelectionSnapshot,
                    referenceCorpusSets: referenceCorpusSetsSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    filteredRows: filtered.rows,
                    derivedRows: derivedRows,
                    sortedRows: sortedRows,
                    searchError: filtered.error
                )
                return (filtered.rows, filtered.error, derivedRows, sortedRows, nextScene)
            },
            apply: { payload in
                let (filteredRows, filteredError, derivedRows, sortedRows, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedFilteredRows = filteredRows
                self.cachedFilteredError = filteredError
                self.cachedFilterQuery = querySnapshot
                self.cachedFilterOptions = optionsSnapshot
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedDerivedRows = derivedRows
                self.cachedDerivedReferenceSelection = referenceSelectionSnapshot
                self.cachedDerivedReferenceCorpusSets = referenceCorpusSetsSnapshot
                self.cachedDerivedLanguageMode = languageModeSnapshot
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

    func normalizeReferenceSelection() {
        switch selectedReferenceSelection {
        case .automatic:
            return
        case .corpus(let corpusID):
            guard selectedCorpusIDs.contains(corpusID) else {
                selectedReferenceSelection = .automatic
                return
            }
        case .corpusSet(let corpusSetID):
            guard availableCorpusSets.contains(where: { $0.id == corpusSetID }) else {
                selectedReferenceSelection = .automatic
                return
            }
        }
    }

    func rebuildReferenceOptions() {
        let automatic = CompareReferenceOptionSceneItem(
            id: Self.automaticReferenceOptionID,
            title: wordZText("自动选择主导语料", "Automatic: dominant corpus per word", mode: WordZLocalization.shared.effectiveMode)
        )
        let manualCorpusOptions = selectionItems
            .filter(\.isSelected)
            .map { item in
                CompareReferenceOptionSceneItem(
                    id: item.id,
                    title: wordZText("参考语料：", "Reference: ", mode: WordZLocalization.shared.effectiveMode) + item.title
                )
            }
        let manualSetOptions = availableCorpusSets.map { corpusSet in
            CompareReferenceOptionSceneItem(
                id: CompareReferenceSelection.corpusSet(corpusSet.id).optionID,
                title: wordZText("参考语料集：", "Reference Set: ", mode: WordZLocalization.shared.effectiveMode) + corpusSet.name
            )
        }
        referenceOptions = [automatic] + manualCorpusOptions + manualSetOptions
    }
}
