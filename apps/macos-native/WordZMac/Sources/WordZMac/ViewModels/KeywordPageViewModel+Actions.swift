import Foundation

extension KeywordPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.totalRows ?? result?.rows.count
    }

    func handle(_ action: KeywordPageAction) {
        switch action {
        case .run:
            return
        case .changeTargetCorpus(let corpusID):
            selectedTargetCorpusID = corpusID.isEmpty ? nil : corpusID
            normalizeSelections()
            handleInputChange()
        case .changeReferenceCorpus(let corpusID):
            selectedReferenceCorpusID = corpusID.isEmpty ? nil : corpusID
            normalizeSelections()
            handleInputChange()
        case .changeStatistic(let nextStatistic):
            guard statistic != nextStatistic else { return }
            statistic = nextStatistic
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
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func handleInputChange() {
        propagateInputChange(rebuildScene: true) {
            rebuildScene()
        }
    }

    func sortByColumn(_ column: KeywordColumnKey) {
        let nextSort: KeywordSortMode
        switch column {
        case .rank, .score, .logRatio, .pValue:
            nextSort = .scoreDescending
        case .word:
            nextSort = .alphabeticalAscending
        case .targetFrequency, .referenceFrequency:
            nextSort = .targetFrequencyDescending
        case .targetNormFrequency, .referenceNormFrequency:
            nextSort = .targetNormFrequencyDescending
        }
        applySortModeChange(nextSort)
    }

    func toggleColumn(_ column: KeywordColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }
}
