import Foundation

extension WordPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.frequencyRows.count
    }

    func handle(_ action: WordPageAction) {
        switch action {
        case .run:
            return
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changeNormalizationUnit(let unit):
            applyFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: definition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            applyFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: definition.normalizationUnit,
                    rangeMode: mode
                )
            )
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleVisibleColumnAndRebuild(column)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func sortByColumn(_ column: WordColumnKey) {
        let nextSort: WordSortMode
        switch column {
        case .rank:
            nextSort = sortMode == .rankAscending ? .rankDescending : .rankAscending
        case .word:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count, .normFrequency:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .range, .normRange:
            nextSort = sortMode == .rangeDescending ? .rangeAscending : .rangeDescending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        invalidateSortedRowsCache()
        rebuildScene()
    }
}
