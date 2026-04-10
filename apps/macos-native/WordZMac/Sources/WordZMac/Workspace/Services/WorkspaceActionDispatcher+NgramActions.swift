import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleNgramAction(_ action: NgramPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runNgram() }
        case .changeSort, .sortByColumn, .changePageSize, .changeSize, .toggleColumn, .previousPage, .nextPage:
            syncResult(.ngram) { workspace.ngram.handle(action) }
        }
    }
}
