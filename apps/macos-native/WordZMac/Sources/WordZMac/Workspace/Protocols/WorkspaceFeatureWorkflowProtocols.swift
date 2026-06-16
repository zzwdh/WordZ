import Foundation

import WordZWindowing
import WordZHost
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

struct WorkspaceFeatureWorkflowSet {
    let sentiment: any WorkspaceSentimentWorkflowServing
    let topics: any WorkspaceTopicsWorkflowServing
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
