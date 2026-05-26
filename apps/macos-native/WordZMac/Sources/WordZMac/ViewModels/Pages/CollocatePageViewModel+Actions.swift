import Foundation

extension CollocatePageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: CollocatePageAction) {
        switch action {
        case .run:
            return
        case .openKWIC:
            return
        case .applyPreset(let preset):
            applyPreset(preset)
        case .changeFocusMetric(let nextMetric):
            changeFocusMetric(nextMetric)
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

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {
        guard mutation == .sort else { return }
        invalidateSortedRowsCache()
    }

    func nextSortMode(
        for column: CollocateColumnKey,
        currentSortMode: CollocateSortMode
    ) -> CollocateSortMode? {
        switch column {
        case .rank:
            return .frequencyDescending
        case .word:
            return .alphabeticalAscending
        case .total:
            return currentSortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .logDice:
            return .logDiceDescending
        case .mutualInformation:
            return .mutualInformationDescending
        case .tScore:
            return .tScoreDescending
        case .rate:
            return .rateDescending
        case .left, .right, .wordFreq, .keywordFreq:
            return nil
        }
    }

    func changeFocusMetric(_ nextMetric: CollocateAssociationMetric) {
        guard focusMetric != nextMetric else { return }
        performPresentationMutation {
            focusMetric = nextMetric
            applyMetricPresentation(nextMetric)
        }
    }

    func applyPreset(_ preset: CollocatePreset) {
        let configuration = preset.configuration
        let shouldRebuildScene = focusMetric != configuration.metric
        performConfigurationMutation(rebuildScene: shouldRebuildScene) {
            leftWindow = configuration.leftWindow
            rightWindow = configuration.rightWindow
            minFreq = configuration.minFreq
            if focusMetric != configuration.metric {
                focusMetric = configuration.metric
                applyMetricPresentation(configuration.metric)
                currentPage = 1
            }
        }
    }
}
