import Foundation

@MainActor
protocol WorkspaceSentimentWorkflowServing {
    func runSentiment(
        features: WorkspaceSentimentWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async

    func importSentimentUserLexiconBundle(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async

    func exportSentimentSummary(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func exportSentimentStructuredJSON(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async
}

@MainActor
protocol WorkspaceTopicsWorkflowServing {
    func runTopics(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async

    func prepareCompareTopics(
        features: WorkspaceTopicsWorkflowContext,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) -> Bool

    func prepareTopicsSentiment(
        scope: TopicsSentimentDrilldownScope,
        features: WorkspaceTopicsWorkflowContext,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool

    func prepareTopicsKWIC(
        features: WorkspaceTopicsWorkflowContext,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool

    func runTopicSegmentsSentiment(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async
}

@MainActor
protocol WorkspaceEvidenceWorkflowServing {
    func refreshEvidenceItems(features: WorkspaceEvidenceWorkflowContext) async

    func captureCurrentKWICEvidenceItem(
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft?
    ) async

    func captureCurrentLocatorEvidenceItem(
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft?
    ) async

    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func saveSelectedEvidenceDetails(features: WorkspaceEvidenceWorkflowContext) async

    func moveSelectedEvidenceItem(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func moveSelectedEvidenceGroup(
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func moveEvidenceGroup(
        groupID: String,
        direction: EvidenceWorkbenchMoveDirection,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func moveEvidenceGroup(
        groupID: String,
        to targetGroupID: String,
        placement: EvidenceWorkbenchGroupInsertPlacement,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func assignEvidenceItem(
        itemID: String,
        to targetGroupID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func createGroupAndAssignEvidenceItem(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func renameSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func splitSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func mergeSelectedEvidenceGroup(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func captureSourceReaderEvidenceItem(
        sourceKind: EvidenceSourceKind,
        context: SourceReaderLaunchContext,
        anchor: SourceReaderHitAnchor,
        selection: SourceReaderSelection,
        features: WorkspaceEvidenceWorkflowContext,
        draft: EvidenceCaptureDraft?
    ) async

    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceEvidenceWorkflowContext
    ) async

    func exportEvidencePacketMarkdown(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async

    func exportEvidenceJSON(
        features: WorkspaceEvidenceWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async
}

struct WorkspaceFeatureWorkflowSet {
    let sentiment: any WorkspaceSentimentWorkflowServing
    let topics: any WorkspaceTopicsWorkflowServing
    let evidence: any WorkspaceEvidenceWorkflowServing
}

@MainActor
protocol WorkspaceFeatureWorkflowBuilding {
    func make(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter,
        analysisWorkflow: WorkspaceAnalysisWorkflowService
    ) -> WorkspaceFeatureWorkflowSet
}
