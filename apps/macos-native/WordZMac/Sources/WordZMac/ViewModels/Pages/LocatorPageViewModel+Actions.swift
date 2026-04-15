import Foundation

extension LocatorPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.totalRows ?? result?.rows.count
    }

    func handle(_ action: LocatorPageAction) {
        switch action {
        case .run:
            return
        case .saveCorpusSet, .addCurrentRowToEvidenceWorkbench, .setEvidenceReviewStatus, .saveSelectedEvidenceNote, .deleteEvidenceItem, .saveCurrentHitSet, .saveVisibleHitSet, .saveFilteredSavedSet, .saveSelectedSavedSetNotes, .importSavedSetsJSON, .refreshSavedSets, .loadSelectedSavedSet, .deleteSavedSet, .exportSelectedSavedSetJSON:
            return
        case .selectSavedSet(let setID):
            selectedSavedSetID = setID
            normalizeSavedSetSelection()
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleColumn(column)
        case .selectRow(let rowID):
            selectRow(rowID)
        case .activateRow(let rowID):
            selectRow(rowID)
            if let nextSource = selectedSceneRow?.sourceCandidate {
                source = nextSource
            }
        case .openSourceReader, .copyCurrent, .copyVisible, .exportCurrent, .exportVisible:
            return
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func toggleColumn(_ column: LocatorColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }

    func selectRow(_ rowID: String?) {
        guard let scene else {
            selectedRowID = nil
            return
        }
        guard let rowID else {
            selectedRowID = scene.rows.first?.id
            return
        }
        if scene.rows.contains(where: { $0.id == rowID }) {
            selectedRowID = rowID
        }
    }
}
