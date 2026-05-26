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
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .changeSize(let nextSize):
            let normalizedSize = max(2, nextSize)
            guard ngramSizeValue != normalizedSize else { return }
            ngramSize = "\(normalizedSize)"
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
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
        for column: NgramColumnKey,
        currentSortMode: NgramSortMode
    ) -> NgramSortMode? {
        switch column {
        case .rank:
            return .frequencyDescending
        case .phrase:
            return currentSortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count:
            return currentSortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        }
    }
}
