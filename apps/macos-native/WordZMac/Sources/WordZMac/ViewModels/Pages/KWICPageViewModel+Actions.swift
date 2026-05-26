import Foundation

extension KWICPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: KWICPageAction) {
        switch action {
        case .run:
            return
        case .saveCorpusSet, .addCurrentRowToEvidenceWorkbench, .setEvidenceReviewStatus, .saveSelectedEvidenceNote, .deleteEvidenceItem, .saveCurrentHitSet, .saveVisibleHitSet, .saveFilteredSavedSet, .saveSelectedSavedSetNotes, .importSavedSetsJSON, .refreshSavedSets, .loadSelectedSavedSet, .deleteSavedSet, .exportSelectedSavedSetJSON:
            return
        case .selectSavedSet(let setID):
            selectedSavedSetID = setID
            normalizeSavedSetSelection()
        case .changeSort(let nextSort):
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectRow(rowID)
        case .activateRow(let rowID):
            selectRow(rowID)
        case .openSourceReader, .copyCurrent, .copyVisible, .exportCurrent, .exportVisible:
            return
        case .previousPage:
            goToPreviousTablePage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextTablePage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {
        guard mutation == .sort else { return }
        invalidateSortedRowsCache()
    }

    func nextSortMode(
        for column: KWICColumnKey,
        currentSortMode: KWICSortMode
    ) -> KWICSortMode? {
        switch column {
        case .sentenceIndex:
            return currentSortMode == .sentenceAscending ? .original : .sentenceAscending
        case .leftContext:
            return currentSortMode == .leftContextAscending ? .original : .leftContextAscending
        case .keyword:
            return currentSortMode == .keywordAscending ? .original : .keywordAscending
        case .rightContext:
            return currentSortMode == .rightContextAscending ? .original : .rightContextAscending
        }
    }

    func selectRow(_ rowID: String?) {
        guard let scene else {
            selectedRowID = nil
            return
        }
        guard let rowID else {
            selectedRowID = scene.rows.first?.id
            return
        }
        if scene.rows.contains(where: { $0.id == rowID }) {
            selectedRowID = rowID
        }
    }
}
