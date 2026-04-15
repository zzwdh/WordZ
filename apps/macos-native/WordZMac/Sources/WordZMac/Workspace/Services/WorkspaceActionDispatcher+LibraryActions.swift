import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleLibraryAction(_ action: LibraryManagementAction) {
        switch action {
        case .selectFolder(let folderID):
            sync(.librarySelection) {
                workspace.library.selectFolder(folderID)
                if workspace.sidebar.selectedCorpusID != workspace.library.selectedCorpusID {
                    workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
                }
            }
        case .selectCorpusSet(let corpusSetID):
            sync(.librarySelection) {
                workspace.library.selectCorpusSet(corpusSetID)
                let selectedSet = workspace.library.selectedCorpusSet
                workspace.sidebar.applyCorpusSet(selectedSet)
                workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
            }
            launch { await self.workspace.flowCoordinator.persistRecentCorpusSetSelection(corpusSetID, features: self.workspace.features) }
        case .selectCorpus(let corpusID):
            sync(.librarySelection) {
                workspace.library.selectCorpus(corpusID)
                workspace.sidebar.selectedCorpusID = corpusID
            }
        case .selectCorpusIDs(let corpusIDs):
            sync(.librarySelection) {
                workspace.library.selectCorpusIDs(corpusIDs)
                workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
            }
        case .selectRecycleEntry(let recycleEntryID):
            sync(.librarySelection) {
                workspace.library.selectRecycleEntry(recycleEntryID)
                workspace.sidebar.selectedCorpusID = nil
            }
        case .openSelectedCorpus:
            if let selectedCorpusID = workspace.library.selectedCorpusID {
                workspace.sidebar.selectedCorpusID = selectedCorpusID
            }
            workspace.syncSceneGraph(source: .librarySelection)
            launch { await self.workspace.openSelectedCorpus() }
        case .quickLookSelectedCorpus:
            launch { await self.workspace.quickLookSelectedCorpus() }
        case .shareSelectedCorpus:
            launch { await self.workspace.shareSelectedCorpus() }
        case .editSelectedCorpusMetadata:
            if let selectedCorpus = workspace.library.selectedCorpus ?? workspace.sidebar.selectedCorpus {
                workspace.library.presentMetadataEditor(
                    for: selectedCorpus,
                    sourcePresetLabels: workspace.sidebar.metadataSourcePresetLabels,
                    recentSourceLabels: workspace.sidebar.metadataRecentSourceMenuLabels,
                    quickYearLabels: workspace.sidebar.metadataQuickYearLabels,
                    commonYearLabels: workspace.sidebar.metadataCommonYearLabels
                )
            }
        case .editSelectedCorporaMetadata:
            let selectedCorpora = workspace.library.selectedCorpora
            if selectedCorpora.count > 1 {
                workspace.library.presentBatchMetadataEditor(
                    for: selectedCorpora,
                    sourcePresetLabels: workspace.sidebar.metadataSourcePresetLabels,
                    recentSourceLabels: workspace.sidebar.metadataRecentSourceMenuLabels,
                    quickYearLabels: workspace.sidebar.metadataQuickYearLabels,
                    commonYearLabels: workspace.sidebar.metadataCommonYearLabels
                )
            }
        default:
            launch { await self.workspace.handleLibraryAction(action, preferredWindowRoute: self.preferredWindowRoute) }
        }
    }
}
