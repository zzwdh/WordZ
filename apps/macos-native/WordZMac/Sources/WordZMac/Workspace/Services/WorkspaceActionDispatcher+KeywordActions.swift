import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleKeywordAction(_ action: KeywordPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runKeyword() }
        case .changeTargetCorpus, .changeReferenceCorpus, .changeStatistic, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            syncResult(.keyword) { workspace.keyword.handle(action) }
        }
    }
}
