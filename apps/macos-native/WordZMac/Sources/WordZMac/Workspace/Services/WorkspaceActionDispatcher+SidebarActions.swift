import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleSidebarAction(_ action: SidebarAction) {
        switch action {
        case .refresh:
            launch { await self.workspace.refreshLibraryManagement() }
        case .openSelected:
            launch { await self.workspace.openSelectedCorpus() }
        case .applyCorpusSet(let corpusSetID):
            sync(.librarySelection) {
                let selectedSet = workspace.sidebar.librarySnapshot.corpusSets.first(where: { $0.id == corpusSetID })
                workspace.sidebar.applyCorpusSet(selectedSet)
                workspace.library.selectCorpusSet(corpusSetID)
                workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
            }
            launch { await self.workspace.flowCoordinator.persistRecentCorpusSetSelection(corpusSetID, features: self.workspace.features) }
        case .selectTargetCorpus(let corpusID):
            sync(.full) {
                workspace.sidebar.selectedCorpusID = corpusID
                workspace.library.selectCorpus(corpusID)
                workspace.keyword.handle(.changeTargetCorpus(corpusID))
            }
        case .selectReferenceCorpus(let corpusID):
            sync(.full) {
                workspace.keyword.handle(.changeReferenceCorpus(corpusID ?? ""))
            }
        case .openAnalysis(let tab):
            sync(.full) {
                workspace.selectedTab = tab
            }
        case .exportCurrent:
            launch { await self.workspace.exportCurrent(preferredWindowRoute: self.preferredWindowRoute) }
        case .quickLookSelected(let corpusID):
            sync(.librarySelection) {
                workspace.sidebar.selectedCorpusID = corpusID
                workspace.library.selectCorpus(corpusID)
            }
            launch { await self.workspace.quickLookSelectedCorpus() }
        case .showCorpusInfoSelected(let corpusID):
            sync(.librarySelection) {
                workspace.sidebar.selectedCorpusID = corpusID
                workspace.library.selectCorpus(corpusID)
            }
            NativeAppCommandCenter.post(.showLibrary)
            launch {
                await self.workspace.handleLibraryAction(
                    .showSelectedCorpusInfo,
                    preferredWindowRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
