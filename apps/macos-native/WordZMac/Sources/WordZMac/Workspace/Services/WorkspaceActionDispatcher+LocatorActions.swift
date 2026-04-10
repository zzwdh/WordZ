import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleLocatorAction(_ action: LocatorPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runLocator() }
        case .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            syncResult(.locator) { workspace.locator.handle(action) }
        case .activateRow(let rowID):
            syncResult(.locator) { workspace.locator.handle(.activateRow(rowID)) }
            launch { await self.workspace.runLocator() }
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
