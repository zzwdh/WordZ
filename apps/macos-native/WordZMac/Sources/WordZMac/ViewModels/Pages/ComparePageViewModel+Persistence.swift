import Foundation

extension ComparePageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: {
            self.rebuildReferenceOptions()
            self.rebuildScene()
        }) {
            clearSentimentCrossAnalysis()
            query = snapshot.searchQuery
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
            let snapshotSelection = Set(snapshot.compareSelectedCorpusIDs)
            if !snapshotSelection.isEmpty {
                selectedCorpusIDs = snapshotSelection
            } else if selectionItems.isEmpty {
                selectedCorpusIDs = []
            }
            if !selectionItems.isEmpty {
                selectionItems = selectionItems.map { item in
                    CompareSelectableCorpusSceneItem(
                        id: item.id,
                        title: item.title,
                        subtitle: item.subtitle,
                        isSelected: selectedCorpusIDs.contains(item.id)
                    )
                }
            }
            selectedReferenceSelection = CompareReferenceSelection(optionID: snapshot.compareReferenceCorpusID)
            if !selectionItems.isEmpty {
                normalizeReferenceSelection()
            }
        }
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        availableCorpora = snapshot.corpora
        availableCorpusSets = snapshot.corpusSets
        let validIDs = Set(snapshot.corpora.map(\.id))
        let previousSelection = selectedCorpusIDs
        selectedCorpusIDs = selectedCorpusIDs.intersection(validIDs)

        if selectedCorpusIDs.count < 2 {
            for corpus in snapshot.corpora where !selectedCorpusIDs.contains(corpus.id) {
                selectedCorpusIDs.insert(corpus.id)
                if selectedCorpusIDs.count >= 2 { break }
            }
        }

        selectionItems = snapshot.corpora.map { corpus in
            CompareSelectableCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                isSelected: selectedCorpusIDs.contains(corpus.id)
            )
        }
        normalizeReferenceSelection()
        rebuildReferenceOptions()

        if previousSelection != selectedCorpusIDs {
            result = nil
            currentPage = 1
            clearSentimentCrossAnalysis()
            invalidateCaches()
        }
        rebuildScene()
    }

    func apply(_ result: CompareResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            clearSentimentCrossAnalysis()
            self.result = result
            currentPage = 1
            invalidateCaches()
        }
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            clearSentimentCrossAnalysis()
            self.query = ""
            self.searchOptions = .default
            self.stopwordFilter = .default
            self.isEditingStopwords = false
            self.result = nil
            self.sortMode = .keynessDescending
            self.pageSize = .fifty
            self.currentPage = 1
            self.visibleColumns = Self.defaultVisibleColumns
            self.selectedReferenceSelection = .automatic
            self.referenceOptions = []
            self.selectedRowID = nil
            self.invalidateCaches()
            self.scene = nil
        }
    }
}
