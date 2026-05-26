import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleTokenizeAction(_ action: TokenizePageAction) {
        switch action {
        case .run:
            handleWorkspaceIntent(.runAnalysis(.tokenize))
        case .exportText:
            launch { await self.workspace.exportTokenizedText(preferredWindowRoute: self.preferredWindowRoute) }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            syncResult(.tokenize) { workspace.tokenize.handle(action) }
        }
    }
}
