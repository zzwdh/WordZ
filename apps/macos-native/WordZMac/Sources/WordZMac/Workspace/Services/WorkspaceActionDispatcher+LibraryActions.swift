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
        case .editSelectedCorpusMetadata:
            if let selectedCorpus = workspace.library.selectedCorpus ?? workspace.sidebar.selectedCorpus {
                workspace.library.presentMetadataEditor(for: selectedCorpus)
            }
        case .editSelectedCorporaMetadata:
            let selectedCorpora = workspace.library.selectedCorpora
            if selectedCorpora.count > 1 {
                workspace.library.presentBatchMetadataEditor(for: selectedCorpora)
            }
        default:
            launch { await self.workspace.handleLibraryAction(action, preferredWindowRoute: self.preferredWindowRoute) }
        }
    }
}
