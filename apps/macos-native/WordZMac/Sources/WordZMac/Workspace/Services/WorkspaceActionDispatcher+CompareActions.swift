import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleCompareAction(_ action: ComparePageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runCompare() }
        case .changeReferenceCorpus, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage, .toggleCorpusSelection:
            syncResult(.compare) { workspace.compare.handle(action) }
        case .copyCurrent(_):
            launch { await self.workspace.flowCoordinator.copyCompareReading(currentOnly: true, features: self.workspace.features) }
        case .copyVisible(_):
            launch { await self.workspace.flowCoordinator.copyCompareReading(currentOnly: false, features: self.workspace.features) }
        case .exportCurrent(_):
            launch {
                await self.workspace.flowCoordinator.exportCompareReading(
                    currentOnly: true,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        case .exportVisible(_):
            launch {
                await self.workspace.flowCoordinator.exportCompareReading(
                    currentOnly: false,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
