import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleTokenizeAction(_ action: TokenizePageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runTokenize() }
        case .exportText:
            launch { await self.workspace.exportTokenizedText(preferredWindowRoute: self.preferredWindowRoute) }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            syncResult(.tokenize) { workspace.tokenize.handle(action) }
        }
    }
}
