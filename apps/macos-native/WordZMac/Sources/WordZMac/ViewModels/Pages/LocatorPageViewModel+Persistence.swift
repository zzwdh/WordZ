import Foundation

extension LocatorPageViewModel {
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

    func updateSource(_ source: LocatorSource?) {
        guard self.source != source else {
            rebuildScene()
            return
        }
        invalidatePendingSceneBuilds()
        self.source = source
        result = nil
        loadedSavedSetID = nil
        currentPage = 1
        selectedRowID = nil
        selectedSavedSetID = nil
        savedSetFilterQuery = ""
        savedSetNotesDraft = ""
        scene = nil
    }

    func apply(_ result: LocatorResult, source: LocatorSource, loadedSavedSetID: String? = nil) {
        self.result = result
        self.source = source
        self.loadedSavedSetID = loadedSavedSetID
        currentPage = 1
        rebuildScene()
    }

    func reset() {
        invalidatePendingSceneBuilds()
        result = nil
        source = nil
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        selectedRowID = nil
        selectedSavedSetID = nil
        savedSetFilterQuery = ""
        savedSetNotesDraft = ""
        loadedSavedSetID = nil
        scene = nil
    }
}
