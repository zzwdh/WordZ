import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleKWICAction(_ action: KWICPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runKWIC() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            syncResult(.kwic) {
                workspace.kwic.handle(action)
                workspace.syncLocatorSourceFromKWIC()
            }
        case .activateRow(let rowID):
            syncResult(.kwic) {
                workspace.kwic.handle(.activateRow(rowID))
                workspace.syncLocatorSourceFromKWIC()
            }
            launch { await self.workspace.runLocator() }
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
