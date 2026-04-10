import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleTopicsAction(_ action: TopicsPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runTopics() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectCluster, .previousPage, .nextPage:
            syncResult(.topics) { workspace.topics.handle(action) }
        case .exportSummary:
            launch { await self.workspace.exportTopicsSummary(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportSegments:
            launch { await self.workspace.exportTopicsSegments(preferredWindowRoute: self.preferredWindowRoute) }
        }
    }
}
