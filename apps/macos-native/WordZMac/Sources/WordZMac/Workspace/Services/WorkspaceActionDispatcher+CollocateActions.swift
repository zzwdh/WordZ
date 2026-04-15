import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleCollocateAction(_ action: CollocatePageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runCollocate() }
        case .openKWIC:
            launch { await self.workspace.openCollocateKWIC() }
        case .applyPreset, .changeFocusMetric, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            syncResult(.collocate) { workspace.collocate.handle(action) }
        case .copyCurrent(_):
            launch { await self.workspace.flowCoordinator.copyCollocateReading(currentOnly: true, features: self.workspace.features) }
        case .copyVisible(_):
            launch { await self.workspace.flowCoordinator.copyCollocateReading(currentOnly: false, features: self.workspace.features) }
        case .copyMethodSummary:
            launch { await self.workspace.flowCoordinator.copyCollocateMethodSummary(features: self.workspace.features) }
        case .exportCurrent(_):
            launch {
                await self.workspace.flowCoordinator.exportCollocateReading(
                    currentOnly: true,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        case .exportVisible(_):
            launch {
                await self.workspace.flowCoordinator.exportCollocateReading(
                    currentOnly: false,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
