import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleSentimentAction(_ action: SentimentPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runSentiment() }
        case .exportSummary:
            launch { await self.workspace.exportSentimentSummary(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportStructuredJSON:
            launch { await self.workspace.exportSentimentStructuredJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .changeSource,
             .changeUnit,
             .changeContextBasis,
             .changeBackend,
             .changeChartKind,
             .changeThresholdPreset,
             .changeDecisionThreshold,
             .changeMinimumEvidence,
             .changeNeutralBias,
             .changeFilterQuery,
             .changeLabelFilter,
             .changeSort,
             .sortByColumn,
             .changePageSize,
             .toggleColumn,
             .selectRow,
             .changeManualText,
             .toggleCorpusSelection,
             .changeReferenceCorpus:
            syncResult(.sentiment) { workspace.sentiment.handle(action) }
        }
    }
}
