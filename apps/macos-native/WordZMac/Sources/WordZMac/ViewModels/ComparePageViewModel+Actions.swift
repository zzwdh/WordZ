import Foundation

extension ComparePageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    func handle(_ action: ComparePageAction) {
        switch action {
        case .run:
            return
        case .toggleCorpusSelection(let corpusID):
            toggleCorpusSelection(corpusID)
        case .changeReferenceCorpus(let corpusID):
            changeReferenceCorpus(corpusID)
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
        case .copyCurrent, .copyVisible, .exportCurrent, .exportVisible:
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

    func toggleCorpusSelection(_ corpusID: String) {
        if selectedCorpusIDs.contains(corpusID) {
            guard selectedCorpusIDs.count > 2 else { return }
            selectedCorpusIDs.remove(corpusID)
        } else {
            selectedCorpusIDs.insert(corpusID)
        }
        selectionItems = selectionItems.map {
            CompareSelectableCorpusSceneItem(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                isSelected: selectedCorpusIDs.contains($0.id)
            )
        }
        normalizeReferenceSelection()
        rebuildReferenceOptions()
        result = nil
        currentPage = 1
        selectedRowID = nil
        invalidateCaches()
        scene = nil
        onInputChange?()
    }

    func changeReferenceCorpus(_ corpusID: String?) {
        let nextSelection = CompareReferenceSelection(optionID: corpusID)
        guard selectedReferenceSelection != nextSelection else { return }
        selectedReferenceSelection = nextSelection
        normalizeReferenceSelection()
        rebuildReferenceOptions()
        resetToFirstPageAndRebuild()
        onInputChange?()
    }

    func toggleColumn(_ column: CompareColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }

    func sortByColumn(_ column: CompareColumnKey) {
        let nextSort: CompareSortMode?
        switch column {
        case .word:
            nextSort = .alphabeticalAscending
        case .keyness:
            nextSort = .keynessDescending
        case .effect:
            nextSort = .effectDescending
        case .spread:
            nextSort = .spreadDescending
        case .total:
            nextSort = .totalDescending
        case .range:
            nextSort = .rangeDescending
        case .dominantCorpus, .distribution:
            nextSort = nil
        }
        guard let nextSort, sortMode != nextSort else { return }
        sortMode = nextSort
        resetToFirstPageAndRebuild()
    }
}
