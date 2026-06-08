import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleKWICAction(_ action: KWICPageAction) {
        switch action {
        case .run:
            handleWorkspaceIntent(.runAnalysis(.kwic))
        case .saveCorpusSet:
            launch { await self.workspace.saveKWICCorpusSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveCurrentHitSet:
            launch { await self.workspace.saveKWICCurrentHitSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveVisibleHitSet:
            launch { await self.workspace.saveKWICVisibleHitSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveFilteredSavedSet:
            launch { await self.workspace.saveRefinedKWICSavedSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveSelectedSavedSetNotes:
            launch { await self.workspace.saveSelectedKWICSavedSetNotes() }
        case .importSavedSetsJSON:
            launch { await self.workspace.importConcordanceSavedSetsJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .refreshSavedSets:
            launch { await self.workspace.refreshConcordanceSavedSets() }
        case .loadSelectedSavedSet:
            launch { await self.workspace.loadSelectedKWICSavedSet() }
        case .deleteSavedSet(let setID):
            launch { await self.workspace.deleteKWICSavedSet(setID) }
        case .exportSelectedSavedSetJSON:
            launch { await self.workspace.exportSelectedKWICSavedSetJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            syncResult(.kwic) {
                workspace.kwic.handle(action)
                workspace.syncLocatorSourceFromKWIC()
            }
        case .selectSavedSet:
            syncResult(.kwic) { workspace.kwic.handle(action) }
        case .activateRow(let rowID):
            syncResult(.kwic) {
                workspace.kwic.handle(.activateRow(rowID))
                workspace.syncLocatorSourceFromKWIC()
            }
            handleWorkspaceIntent(.runAnalysis(.locator))
        case .openSourceReader:
            handleWorkspaceIntent(.openSourceReader)
        case .copyCurrent(let format):
            launch { await self.workspace.flowCoordinator.copyKWICReading(format, currentOnly: true, features: self.workspace.features) }
        case .copyVisible(let format):
            launch { await self.workspace.flowCoordinator.copyKWICReading(format, currentOnly: false, features: self.workspace.features) }
        case .exportCurrent(let format):
            launch {
                await self.workspace.flowCoordinator.exportKWICReading(
                    format,
                    currentOnly: true,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        case .exportVisible(let format):
            launch {
                await self.workspace.flowCoordinator.exportKWICReading(
                    format,
                    currentOnly: false,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
