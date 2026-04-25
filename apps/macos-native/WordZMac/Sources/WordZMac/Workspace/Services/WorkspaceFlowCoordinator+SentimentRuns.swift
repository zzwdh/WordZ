import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runSentiment(features: WorkspaceFeatureSet) async {
        if features.sentiment.source == .topicSegments {
            await topicsWorkflow.runTopicSegmentsSentiment(
                features: features.topicsWorkflowContext,
                syncFeatureContexts: syncFeatureContexts
            )
            return
        }

        await sentimentWorkflow.runSentiment(
            features: features.sentimentWorkflowContext,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func importSentimentUserLexiconBundle(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await sentimentWorkflow.importSentimentUserLexiconBundle(
            features: features.sentimentWorkflowContext,
            preferredRoute: preferredRoute,
            markWorkspaceEdited: markWorkspaceEdited
        )
    }

    func exportSentimentSummary(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await sentimentWorkflow.exportSentimentSummary(
            features: features.sentimentWorkflowContext,
            preferredRoute: preferredRoute
        )
    }

    func exportSentimentStructuredJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await sentimentWorkflow.exportSentimentStructuredJSON(
            features: features.sentimentWorkflowContext,
            preferredRoute: preferredRoute
        )
    }
}
