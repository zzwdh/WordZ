import Foundation

extension ComparePageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: ComparePageAction) {
        switch action {
        case .run:
            return
        case .openKWIC, .openCollocate, .openSentiment, .openSentimentExemplar, .openSentimentSourceReader, .openTopics, .saveCorpusSet:
            return
        case .analyzeInKeywordSuite:
            return
        case .toggleCorpusSelection(let corpusID):
            toggleCorpusSelection(corpusID)
        case .changeReferenceCorpus(let corpusID):
            changeReferenceCorpus(corpusID)
        case .changeSort(let nextSort):
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
        case .copyCurrent, .copyVisible, .copyMethodSummary, .exportCurrent, .exportVisible:
            return
        case .previousPage:
            goToPreviousTablePage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextTablePage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func toggleCorpusSelection(_ corpusID: String) {
        let isSelected = selectedCorpusIDs.contains(corpusID)
        guard !isSelected || selectedCorpusIDs.count > 2 else { return }

        performSelectionMutation(resetResult: true, rebuildScene: false) {
            if isSelected {
                selectedCorpusIDs.remove(corpusID)
            } else {
                selectedCorpusIDs.insert(corpusID)
            }
        }
    }

    func changeReferenceCorpus(_ corpusID: String?) {
        let nextSelection = CompareReferenceSelection(optionID: corpusID)
        guard selectedReferenceSelection != nextSelection else { return }

        performSelectionMutation(rebuildScene: true) {
            selectedReferenceSelection = nextSelection
        }
    }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {
        guard mutation == .sort else { return }
        invalidateSortedRowsCache()
    }

    func nextSortMode(
        for column: CompareColumnKey,
        currentSortMode: CompareSortMode
    ) -> CompareSortMode? {
        switch column {
        case .word:
            return .alphabeticalAscending
        case .keyness:
            return .keynessDescending
        case .effect:
            return .effectDescending
        case .spread:
            return .spreadDescending
        case .total:
            return .totalDescending
        case .range:
            return .rangeDescending
        case .dominantCorpus, .distribution:
            return nil
        }
    }
}
