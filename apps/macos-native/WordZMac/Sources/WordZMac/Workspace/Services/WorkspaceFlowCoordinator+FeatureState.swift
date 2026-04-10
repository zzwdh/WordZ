import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func applyWorkspaceSnapshot(_ workspaceSnapshot: WorkspaceSnapshotSummary, features: WorkspaceFeatureSet) {
        features.stats.apply(workspaceSnapshot)
        features.word.apply(workspaceSnapshot)
        features.tokenize.apply(workspaceSnapshot)
        features.topics.apply(workspaceSnapshot)
        features.compare.apply(workspaceSnapshot)
        features.keyword.apply(workspaceSnapshot)
        features.chiSquare.apply(workspaceSnapshot)
        features.ngram.apply(workspaceSnapshot)
        features.kwic.apply(workspaceSnapshot)
        features.collocate.apply(workspaceSnapshot)

        if let restoredTab = WorkspaceDetailTab.fromSnapshotValue(workspaceSnapshot.currentTab) {
            features.shell.selectedTab = restoredTab.mainWorkspaceTab
        }

        let preferredFolderID = workspaceSnapshot.currentLibraryFolderId
        if preferredFolderID == "all" || preferredFolderID.isEmpty {
            features.library.selectFolder(nil)
        } else {
            features.library.selectFolder(preferredFolderID)
        }

        let selectedCorpusSet = features.sidebar.librarySnapshot.corpusSets.first(where: { $0.id == workspaceSnapshot.selectedCorpusSetID })
        features.sidebar.applyCorpusSet(selectedCorpusSet)
        features.library.selectCorpusSet(selectedCorpusSet?.id)

        let preferredCorpusID = workspaceSnapshot.corpusIds.first
        if let preferredCorpusID,
           features.sidebar.filteredCorpora.contains(where: { $0.id == preferredCorpusID }) {
            features.sidebar.selectedCorpusID = preferredCorpusID
            features.library.selectCorpus(preferredCorpusID)
            return
        }

        let preferredName = workspaceSnapshot.corpusNames.first
        if let preferredName,
           let matchingCorpus = features.sidebar.filteredCorpora.first(where: { $0.name == preferredName }) {
            features.sidebar.selectedCorpusID = matchingCorpus.id
            features.library.selectCorpus(matchingCorpus.id)
            return
        }

        if let currentSelection = features.sidebar.selectedCorpusID,
           features.sidebar.filteredCorpora.contains(where: { $0.id == currentSelection }) {
            features.library.selectCorpus(currentSelection)
            return
        }

        let fallbackCorpusID = features.library.selectedFolderID == nil
            ? features.sidebar.librarySnapshot.corpora.first?.id
            : features.sidebar.librarySnapshot.corpora.first(where: { $0.folderId == features.library.selectedFolderID })?.id
        features.sidebar.selectedCorpusID = fallbackCorpusID
        features.library.selectCorpus(fallbackCorpusID)
    }

    func resetFeatureResults(features: WorkspaceFeatureSet) {
        features.stats.reset()
        features.word.reset()
        features.tokenize.reset()
        features.topics.reset()
        features.compare.reset()
        features.keyword.reset()
        features.chiSquare.reset()
        features.ngram.reset()
        features.kwic.reset()
        features.collocate.reset()
        features.locator.reset()
    }

    func syncFeatureContexts(features: WorkspaceFeatureSet) {
        let context = sceneStore.context
        features.shell.applyContext(context)
        features.sidebar.applyContext(context)
        features.library.applyContext(context)
        features.settings.applyContext(context)
    }
}
