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

    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {
        guard mutation == .sort else { return }
        invalidateSortedRowsCache()
    }

    func nextSortMode(
        for column: WordColumnKey,
        currentSortMode: WordSortMode
    ) -> WordSortMode? {
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
