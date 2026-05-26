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
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
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
            applyTablePageSizeChange(nextPageSize)
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
        for column: StatsColumnKey,
        currentSortMode: StatsSortMode
    ) -> StatsSortMode? {
        switch column {
        case .rank:
            return currentSortMode == .rankAscending ? .rankDescending : .rankAscending
        case .word:
            return currentSortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count, .normFrequency:
            return currentSortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .range, .normRange:
            return currentSortMode == .rangeDescending ? .rangeAscending : .rangeDescending
        }
    }
}
