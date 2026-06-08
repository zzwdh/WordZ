import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleLocatorAction(_ action: LocatorPageAction) {
        switch action {
        case .run:
            handleWorkspaceIntent(.runAnalysis(.locator))
        case .saveCorpusSet:
            launch { await self.workspace.saveLocatorCorpusSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveCurrentHitSet:
            launch { await self.workspace.saveLocatorCurrentHitSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveVisibleHitSet:
            launch { await self.workspace.saveLocatorVisibleHitSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveFilteredSavedSet:
            launch { await self.workspace.saveRefinedLocatorSavedSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .saveSelectedSavedSetNotes:
            launch { await self.workspace.saveSelectedLocatorSavedSetNotes() }
        case .importSavedSetsJSON:
            launch { await self.workspace.importConcordanceSavedSetsJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .refreshSavedSets:
            launch { await self.workspace.refreshConcordanceSavedSets() }
        case .loadSelectedSavedSet:
            launch { await self.workspace.loadSelectedLocatorSavedSet() }
        case .deleteSavedSet(let setID):
            launch { await self.workspace.deleteLocatorSavedSet(setID) }
        case .exportSelectedSavedSetJSON:
            launch { await self.workspace.exportSelectedLocatorSavedSetJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            syncResult(.locator) { workspace.locator.handle(action) }
        case .selectSavedSet:
            syncResult(.locator) { workspace.locator.handle(action) }
        case .activateRow(let rowID):
            syncResult(.locator) { workspace.locator.handle(.activateRow(rowID)) }
            handleWorkspaceIntent(.runAnalysis(.locator))
        case .openSourceReader:
            handleWorkspaceIntent(.openSourceReader)
        case .copyCurrent(let format):
            launch { await self.workspace.flowCoordinator.copyLocatorReading(format, currentOnly: true, features: self.workspace.features) }
        case .copyVisible(let format):
            launch { await self.workspace.flowCoordinator.copyLocatorReading(format, currentOnly: false, features: self.workspace.features) }
        case .exportCurrent(let format):
            launch {
                await self.workspace.flowCoordinator.exportLocatorReading(
                    format,
                    currentOnly: true,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        case .exportVisible(let format):
            launch {
                await self.workspace.flowCoordinator.exportLocatorReading(
                    format,
                    currentOnly: false,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
