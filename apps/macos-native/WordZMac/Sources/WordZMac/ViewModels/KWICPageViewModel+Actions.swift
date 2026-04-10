import Foundation

extension KWICPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: KWICPageAction) {
        switch action {
        case .run:
            return
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleColumn(column)
        case .selectRow(let rowID):
            selectRow(rowID)
        case .activateRow(let rowID):
            selectRow(rowID)
        case .copyCurrent, .copyVisible, .exportCurrent, .exportVisible:
            return
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func sortByColumn(_ column: KWICColumnKey) {
        let nextSort: KWICSortMode
        switch column {
        case .sentenceIndex:
            nextSort = sortMode == .sentenceAscending ? .original : .sentenceAscending
        case .leftContext:
            nextSort = sortMode == .leftContextAscending ? .original : .leftContextAscending
        case .keyword:
            nextSort = sortMode == .keywordAscending ? .original : .keywordAscending
        case .rightContext:
            nextSort = sortMode == .rightContextAscending ? .original : .rightContextAscending
        }
        applySortModeChange(nextSort)
    }

    func toggleColumn(_ column: KWICColumnKey) {
        toggleVisibleColumnAndRebuild(column)
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
