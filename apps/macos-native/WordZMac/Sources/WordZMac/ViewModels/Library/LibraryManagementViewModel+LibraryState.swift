import Foundation

@MainActor
extension LibraryManagementViewModel {
    func applyBootstrap(_ snapshot: LibrarySnapshot) {
        applyLibrarySnapshot(snapshot)
    }

    func applyRecentCorpusSetIDs(_ corpusSetIDs: [String]) {
        recentCorpusSetIDs = CorpusSetRecentsSupport.normalizedRecentCorpusSetIDs(corpusSetIDs)
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        requestSceneSync()
    }

    func applyLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        guard !hasAppliedLibrarySnapshot || librarySnapshot != snapshot else { return }
        deferSceneSync {
            hasAppliedLibrarySnapshot = true
            librarySnapshot = snapshot
            if let selectedFolderID, !snapshot.folders.contains(where: { $0.id == selectedFolderID }) {
                self.selectedFolderID = nil
            }
            if let selectedCorpusSetID, !snapshot.corpusSets.contains(where: { $0.id == selectedCorpusSetID }) {
                self.selectedCorpusSetID = nil
            }
            normalizeCorpusSelectionForCurrentState()
            requestSceneSync()
        }
    }

    func applyRecycleSnapshot(_ snapshot: RecycleBinSnapshot) {
        deferSceneSync {
            recycleSnapshot = snapshot
            if let selectedRecycleEntryID, !snapshot.entries.contains(where: { $0.id == selectedRecycleEntryID }) {
                self.selectedRecycleEntryID = nil
            }
            requestSceneSync()
        }
    }

    func syncSidebarSelection(_ selectedCorpusID: String?) {
        deferSceneSync {
            applyCorpusSelection(selectedCorpusID.map { [$0] } ?? [], preferredPrimaryID: selectedCorpusID)
        }
    }

    func applyMetadataFilterState(_ state: CorpusMetadataFilterState) {
        guard metadataFilterState != state else { return }
        deferSceneSync {
            metadataFilterState = state
            normalizeCorpusSelectionForCurrentState()
        }
    }

    func selectFolder(_ folderID: String?) {
        deferSceneSync {
            showsCorpusBuilder = false
            showsRecycleBin = false
            selectedFolderID = folderID
            selectedCorpusSetID = nil
            normalizeCorpusSelectionForCurrentState()
            selectedRecycleEntryID = nil
        }
    }

    func selectCorpusSet(_ corpusSetID: String?) {
        deferSceneSync {
            showsCorpusBuilder = false
            showsRecycleBin = false
            selectedCorpusSetID = corpusSetID
            selectedRecycleEntryID = nil
            if let corpusSet = selectedCorpusSet {
                selectedFolderID = nil
                metadataFilterState = corpusSet.metadataFilterState
                applyCorpusSelection(Set(corpusSet.corpusIDs), preferredPrimaryID: corpusSet.corpusIDs.first)
            } else {
                normalizeCorpusSelectionForCurrentState()
            }
        }
    }

    func selectCorpus(_ corpusID: String?) {
        deferSceneSync {
            showsCorpusBuilder = false
            showsRecycleBin = false
            applyCorpusSelection(corpusID.map { [$0] } ?? [], preferredPrimaryID: corpusID)
            if corpusID != nil {
                selectedRecycleEntryID = nil
            }
        }
    }

    func selectCorpusIDs(_ corpusIDs: Set<String>) {
        deferSceneSync {
            showsCorpusBuilder = false
            showsRecycleBin = false
            applyCorpusSelection(corpusIDs, preferredPrimaryID: selectedCorpusID)
            if !corpusIDs.isEmpty {
                selectedRecycleEntryID = nil
            }
        }
    }

    func selectRecycleEntry(_ recycleEntryID: String?) {
        deferSceneSync {
            showsCorpusBuilder = false
            showsRecycleBin = true
            selectedFolderID = nil
            selectedCorpusSetID = nil
            selectedRecycleEntryID = recycleEntryID
            applyCorpusSelection([], preferredPrimaryID: nil)
        }
    }

    func selectCorpusBuilder() {
        deferSceneSync {
            showsCorpusBuilder = true
            showsRecycleBin = false
            selectedFolderID = nil
            selectedCorpusSetID = nil
            selectedRecycleEntryID = nil
            applyCorpusSelection([], preferredPrimaryID: nil)
        }
    }

    func setBusy(_ isBusy: Bool) {
        guard self.isBusy != isBusy else { return }
        self.isBusy = isBusy
        requestSceneSync()
    }

    func setStatus(_ message: String) {
        guard statusMessage != message else { return }
        statusMessage = message
        requestSceneSync()
    }

    func setError(_ message: String) {
        guard statusMessage != message else { return }
        statusMessage = message
        requestSceneSync()
    }

    func setImportProgress(_ snapshot: LibraryImportProgressSnapshot?) {
        guard importProgressSnapshot != snapshot else { return }
        importProgressSnapshot = snapshot
    }

    private func applyCorpusSelection(_ corpusIDs: Set<String>, preferredPrimaryID: String?) {
        let visibleCorpora = filteredCorpora
        let validIDs = Set(visibleCorpora.map(\.id))
        let filteredSelection = corpusIDs.intersection(validIDs)
        let nextPrimaryID = resolvePrimaryCorpusID(
            preferred: preferredPrimaryID,
            from: filteredSelection,
            visibleCorpora: visibleCorpora
        )

        isSyncingCorpusSelection = true
        var didChangeSelection = false
        if selectedCorpusIDs != filteredSelection {
            selectedCorpusIDs = filteredSelection
            didChangeSelection = true
        }
        if selectedCorpusID != nextPrimaryID {
            selectedCorpusID = nextPrimaryID
            didChangeSelection = true
        }
        isSyncingCorpusSelection = false
        if didChangeSelection {
            requestSceneSync()
        }
    }

    func normalizeCorpusSelectionForCurrentState() {
        applyCorpusSelection(selectedCorpusIDs, preferredPrimaryID: selectedCorpusID)
    }

    private func resolvePrimaryCorpusID(
        preferred: String?,
        from corpusIDs: Set<String>,
        visibleCorpora: [LibraryCorpusItem]
    ) -> String? {
        if let preferred, corpusIDs.contains(preferred) {
            return preferred
        }
        return visibleCorpora.first(where: { corpusIDs.contains($0.id) })?.id
    }
}
