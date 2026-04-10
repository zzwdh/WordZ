import Foundation

extension StatsPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.totalRows ?? result?.frequencyRows.count
    }

    func applyFrequencyMetricDefinition(_ definition: FrequencyMetricDefinition) {
        guard self.definition != definition else { return }
        self.definition = definition
        currentPage = 1
        invalidateSortedRowsCache()
        rebuildScene()
    }

    func handle(_ action: StatsPageAction) {
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
            toggleColumn(column)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func toggleColumn(_ column: StatsColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }

    func sortByColumn(_ column: StatsColumnKey) {
        let nextSort: StatsSortMode
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
