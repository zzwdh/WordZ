import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runStats(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runStats(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runWord(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runWord(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runTokenize(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runTokenize(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runKWIC(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runKWIC(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runNgram(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runNgram(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runCollocate(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runCollocate(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runLocator(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runLocator(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
