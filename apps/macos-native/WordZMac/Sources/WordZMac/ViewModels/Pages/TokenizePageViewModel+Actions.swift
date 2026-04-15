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
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleVisibleColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectRow(rowID)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func sortByColumn(_ column: TokenizeColumnKey) {
        let nextSort: TokenizeSortMode
        switch column {
        case .sentence, .position:
            nextSort = sortMode == .sequenceAscending ? .sequenceDescending : .sequenceAscending
        case .original:
            nextSort = sortMode == .originalAscending ? .originalDescending : .originalAscending
        case .normalized:
            nextSort = sortMode == .normalizedAscending ? .normalizedDescending : .normalizedAscending
        case .lemma:
            nextSort = sortMode == .lemmaAscending ? .lemmaDescending : .lemmaAscending
        case .lexicalClass:
            nextSort = sortMode == .lexicalClassAscending ? .lexicalClassDescending : .lexicalClassAscending
        case .script:
            nextSort = sortMode == .scriptAscending ? .scriptDescending : .scriptAscending
        }
        applySortModeChange(nextSort)
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
