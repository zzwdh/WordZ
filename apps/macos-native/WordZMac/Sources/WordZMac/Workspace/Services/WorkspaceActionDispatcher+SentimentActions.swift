import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleSentimentAction(_ action: SentimentPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runSentiment() }
        case .openSourceReader:
            NativeAppCommandCenter.post(.openSourceReader)
        case .addCurrentRowToEvidenceWorkbench:
            launch { await self.workspace.captureCurrentSentimentEvidenceItem() }
        case .exportSummary:
            launch { await self.workspace.exportSentimentSummary(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportStructuredJSON:
            launch { await self.workspace.exportSentimentStructuredJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .confirmSelectedRow:
            launch { await self.workspace.confirmSelectedSentimentRow() }
        case .overrideSelectedRow(let label):
            launch { await self.workspace.overrideSelectedSentimentRow(label) }
        case .clearSelectedRowReview:
            launch { await self.workspace.clearSelectedSentimentReview() }
        case .importUserLexiconBundle:
            launch { await self.workspace.importSentimentUserLexiconBundle(preferredWindowRoute: self.preferredWindowRoute) }
        case .changeSource,
             .changeUnit,
             .changeContextBasis,
             .changeBackend,
             .changeDomainPack,
             .changeRuleProfile,
             .changeCalibrationProfile,
             .changeChartKind,
             .changeThresholdPreset,
             .changeDecisionThreshold,
             .changeMinimumEvidence,
             .changeNeutralBias,
             .changeFilterQuery,
             .changeLabelFilter,
             .changeReviewFilter,
             .changeReviewStatusFilter,
             .toggleShowOnlyHardCases,
             .changeSelectedRowReviewNote,
             .removeUserLexiconBundle,
             .changeSort,
             .sortByColumn,
             .changePageSize,
             .previousPage,
             .nextPage,
             .toggleColumn,
             .selectRow,
             .changeManualText,
             .toggleCorpusSelection,
             .changeReferenceCorpus:
            syncResult(.sentiment) { workspace.sentiment.handle(action) }
        }
    }
}
