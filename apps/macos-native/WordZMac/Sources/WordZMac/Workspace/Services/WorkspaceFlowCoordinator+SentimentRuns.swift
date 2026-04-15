import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runSentiment(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runSentiment(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func exportSentimentSummary(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportSentimentSummary(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportSentimentStructuredJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportSentimentStructuredJSON(
            features: features,
            preferredRoute: preferredRoute
        )
    }
}
