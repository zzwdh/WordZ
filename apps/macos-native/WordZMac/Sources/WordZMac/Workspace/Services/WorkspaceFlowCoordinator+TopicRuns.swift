import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runTopics(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runTopics(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
