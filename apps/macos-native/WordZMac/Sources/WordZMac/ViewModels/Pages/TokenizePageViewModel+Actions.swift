import Foundation

extension TokenizePageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredTokens ?? result?.tokenCount
    }

    func handle(_ action: TokenizePageAction) {
        switch action {
        case .run, .exportText:
            return
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
        for column: TokenizeColumnKey,
        currentSortMode: TokenizeSortMode
    ) -> TokenizeSortMode? {
        switch column {
        case .sentence, .position:
            return currentSortMode == .sequenceAscending ? .sequenceDescending : .sequenceAscending
        case .original:
            return currentSortMode == .originalAscending ? .originalDescending : .originalAscending
        case .normalized:
            return currentSortMode == .normalizedAscending ? .normalizedDescending : .normalizedAscending
        case .lemma:
            return currentSortMode == .lemmaAscending ? .lemmaDescending : .lemmaAscending
        case .lexicalClass:
            return currentSortMode == .lexicalClassAscending ? .lexicalClassDescending : .lexicalClassAscending
        case .script:
            return currentSortMode == .scriptAscending ? .scriptDescending : .scriptAscending
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
