import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runTopics(features: WorkspaceFeatureSet) async {
        await topicsWorkflow.runTopics(
            features: features.topicsWorkflowContext,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
