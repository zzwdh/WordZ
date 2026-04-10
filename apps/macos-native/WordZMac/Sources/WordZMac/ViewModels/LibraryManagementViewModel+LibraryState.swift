import Foundation

@MainActor
extension LibraryManagementViewModel {
    func applyBootstrap(_ snapshot: LibrarySnapshot) {
        applyLibrarySnapshot(snapshot)
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func applyLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        librarySnapshot = snapshot
        if let selectedFolderID, !snapshot.folders.contains(where: { $0.id == selectedFolderID }) {
            self.selectedFolderID = nil
        }
        if let selectedCorpusSetID, !snapshot.corpusSets.contains(where: { $0.id == selectedCorpusSetID }) {
            self.selectedCorpusSetID = nil
        }
        normalizeCorpusSelectionForCurrentState()
        syncScene()
    }

    func applyRecycleSnapshot(_ snapshot: RecycleBinSnapshot) {
        recycleSnapshot = snapshot
        if let selectedRecycleEntryID, !snapshot.entries.contains(where: { $0.id == selectedRecycleEntryID }) {
            self.selectedRecycleEntryID = snapshot.entries.first?.id
        }
        syncScene()
    }

    func syncSidebarSelection(_ selectedCorpusID: String?) {
        applyCorpusSelection(selectedCorpusID.map { [$0] } ?? [], preferredPrimaryID: selectedCorpusID)
        syncScene()
    }

    func applyMetadataFilterState(_ state: CorpusMetadataFilterState) {
        guard metadataFilterState != state else { return }
        metadataFilterState = state
        normalizeCorpusSelectionForCurrentState()
        syncScene()
    }

    func selectFolder(_ folderID: String?) {
        selectedFolderID = folderID
        normalizeCorpusSelectionForCurrentState()
        selectedRecycleEntryID = nil
    }

    func selectCorpusSet(_ corpusSetID: String?) {
        selectedCorpusSetID = corpusSetID
        selectedFolderID = nil
        selectedRecycleEntryID = nil
        if let corpusSet = selectedCorpusSet {
            metadataFilterState = corpusSet.metadataFilterState
            applyCorpusSelection(Set(corpusSet.corpusIDs), preferredPrimaryID: corpusSet.corpusIDs.first)
        } else {
            normalizeCorpusSelectionForCurrentState()
        }
    }

    func selectCorpus(_ corpusID: String?) {
        applyCorpusSelection(corpusID.map { [$0] } ?? [], preferredPrimaryID: corpusID)
        if corpusID != nil {
            selectedRecycleEntryID = nil
        }
    }

    func selectCorpusIDs(_ corpusIDs: Set<String>) {
        applyCorpusSelection(corpusIDs, preferredPrimaryID: selectedCorpusID)
        if !corpusIDs.isEmpty {
            selectedRecycleEntryID = nil
        }
    }

    func selectRecycleEntry(_ recycleEntryID: String?) {
        selectedRecycleEntryID = recycleEntryID
        if recycleEntryID != nil {
            applyCorpusSelection([], preferredPrimaryID: nil)
        }
    }

    func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        syncScene()
    }

    func setStatus(_ message: String) {
        statusMessage = message
        syncScene()
    }

    func setError(_ message: String) {
        statusMessage = message
        syncScene()
    }

    func setImportProgress(_ snapshot: LibraryImportProgressSnapshot?) {
        importProgressSnapshot = snapshot
        syncScene()
    }

    private func applyCorpusSelection(_ corpusIDs: Set<String>, preferredPrimaryID: String?) {
        let validIDs = Set(filteredCorpora.map(\.id))
        let filteredSelection = corpusIDs.intersection(validIDs)
        let nextPrimaryID = resolvePrimaryCorpusID(preferred: preferredPrimaryID, from: filteredSelection)

        isSyncingCorpusSelection = true
        selectedCorpusIDs = filteredSelection
        selectedCorpusID = nextPrimaryID
        isSyncingCorpusSelection = false
    }

    private func normalizeCorpusSelectionForCurrentState() {
        applyCorpusSelection(selectedCorpusIDs, preferredPrimaryID: selectedCorpusID)
    }

    private func resolvePrimaryCorpusID(preferred: String?, from corpusIDs: Set<String>) -> String? {
        if let preferred, corpusIDs.contains(preferred) {
            return preferred
        }
        return filteredCorpora.first(where: { corpusIDs.contains($0.id) })?.id
    }
}
