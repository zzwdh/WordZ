import Foundation

extension KWICPageViewModel {
    func applySavedSets(_ sets: [ConcordanceSavedSet]) {
        savedSets = sets.sorted { $0.updatedAt > $1.updatedAt }
        if let loadedSavedSetID, !savedSets.contains(where: { $0.id == loadedSavedSetID }) {
            self.loadedSavedSetID = nil
        }
        normalizeSavedSetSelection()
        syncSavedSetEditorState(resetFilter: false)
    }

    func normalizeSavedSetSelection() {
        let validSetIDs = Set(savedSets.map(\.id))
        if let selectedSavedSetID, !validSetIDs.contains(selectedSavedSetID) {
            self.selectedSavedSetID = nil
        }
        if self.selectedSavedSetID == nil {
            self.selectedSavedSetID = savedSets.first?.id
        }
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            keyword = snapshot.searchQuery
            leftWindow = snapshot.kwicLeftWindow
            rightWindow = snapshot.kwicRightWindow
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
        }
    }

    func apply(_ result: KWICResult, loadedSavedSetID: String? = nil) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            self.loadedSavedSetID = loadedSavedSetID
            currentPage = 1
            invalidateCaches()
        }
    }

    func reset() {
        resetState {
            keyword = ""
            leftWindow = "5"
            rightWindow = "5"
            searchOptions = .default
            stopwordFilter = .default
            isEditingStopwords = false
            result = nil
            sortMode = .original
            pageSize = .fifty
            currentPage = 1
            visibleColumns = Self.defaultVisibleColumns
            selectedRowID = nil
            selectedSavedSetID = nil
            savedSetFilterQuery = ""
            savedSetNotesDraft = ""
            loadedSavedSetID = nil
            invalidateCaches()
            scene = nil
        }
    }
}
