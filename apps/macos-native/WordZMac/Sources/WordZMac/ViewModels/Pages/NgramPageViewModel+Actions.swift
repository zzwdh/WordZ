import Foundation

extension NgramPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: NgramPageAction) {
        switch action {
        case .run:
            return
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .changeSize(let nextSize):
            let normalizedSize = max(2, nextSize)
            guard ngramSizeValue != normalizedSize else { return }
            ngramSize = "\(normalizedSize)"
        case .toggleColumn(let column):
            toggleColumn(column)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func toggleColumn(_ column: NgramColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }

    func sortByColumn(_ column: NgramColumnKey) {
        let nextSort: NgramSortMode
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .phrase:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        }
        applySortModeChange(nextSort)
    }
}
