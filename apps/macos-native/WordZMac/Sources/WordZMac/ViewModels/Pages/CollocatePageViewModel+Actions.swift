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
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleColumn(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
        case .copyCurrent, .copyVisible, .copyMethodSummary, .exportCurrent, .exportVisible:
            return
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

    func sortByColumn(_ column: CollocateColumnKey) {
        let nextSort: CollocateSortMode?
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .word:
            nextSort = .alphabeticalAscending
        case .total:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .logDice:
            nextSort = .logDiceDescending
        case .mutualInformation:
            nextSort = .mutualInformationDescending
        case .tScore:
            nextSort = .tScoreDescending
        case .rate:
            nextSort = .rateDescending
        case .left, .right, .wordFreq, .keywordFreq:
            nextSort = nil
        }
        guard let nextSort, sortMode != nextSort else { return }
        sortMode = nextSort
        resetToFirstPageAndRebuild()
    }

    func toggleColumn(_ column: CollocateColumnKey) {
        toggleVisibleColumnAndRebuild(column)
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
