import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleLocatorAction(_ action: LocatorPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runLocator() }
        case .saveCorpusSet:
            launch { await self.workspace.saveLocatorCorpusSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .addCurrentRowToEvidenceWorkbench:
            launch { await self.workspace.captureCurrentLocatorEvidenceItem() }
        case .setEvidenceReviewStatus(let itemID, let reviewStatus):
            launch { await self.workspace.updateEvidenceReviewStatus(itemID: itemID, reviewStatus: reviewStatus) }
        case .saveSelectedEvidenceNote:
            launch { await self.workspace.saveSelectedEvidenceNote() }
        case .deleteEvidenceItem(let itemID):
            launch { await self.workspace.deleteEvidenceItem(itemID) }
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
            launch { await self.workspace.runLocator() }
        case .openSourceReader:
            NativeAppCommandCenter.post(.openSourceReader)
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
