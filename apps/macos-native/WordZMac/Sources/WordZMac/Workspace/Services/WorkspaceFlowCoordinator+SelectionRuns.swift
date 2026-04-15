import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runCompare(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runCompare(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runKeyword(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runKeyword(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runChiSquare(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runChiSquare(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
