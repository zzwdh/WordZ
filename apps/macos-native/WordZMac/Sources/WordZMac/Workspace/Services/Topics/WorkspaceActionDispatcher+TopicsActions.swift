import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleTopicsAction(_ action: TopicsPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runTopics() }
        case .openKWIC:
            launch { await self.workspace.openTopicsKWIC() }
        case .openSentiment(let scope):
            launch { await self.workspace.openTopicsSentiment(scope: scope) }
        case .openSentimentExemplar(let rowID):
            launch { await self.workspace.openTopicsSentiment(scope: .selectedTopic, preferredRowID: rowID) }
        case .openSentimentSourceReader(let rowID):
            launch { await self.workspace.openTopicsSentiment(scope: .selectedTopic, preferredRowID: rowID, openSourceReaderAfterSelection: true) }
        case .selectRow, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectCluster, .previousPage, .nextPage:
            syncResult(.topics) { workspace.topics.handle(action) }
        case .activateRow(let rowID):
            syncResult(.topics) { workspace.topics.handle(.selectRow(rowID)) }
            NativeAppCommandCenter.post(.openSourceReader)
        case .openSourceReader:
            NativeAppCommandCenter.post(.openSourceReader)
        case .exportSummary:
            launch { await self.workspace.exportTopicsSummary(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportSegments:
            launch { await self.workspace.exportTopicsSegments(preferredWindowRoute: self.preferredWindowRoute) }
        }
    }
}
