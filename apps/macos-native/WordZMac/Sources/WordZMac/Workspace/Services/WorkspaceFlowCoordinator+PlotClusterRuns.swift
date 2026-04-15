import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runPlot(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runPlot(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func preparePlotKWIC(features: WorkspaceFeatureSet) async -> Bool {
        await analysisWorkflow.preparePlotKWIC(
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func runCluster(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.runCluster(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func prepareClusterKWIC(features: WorkspaceFeatureSet) async -> Bool {
        await analysisWorkflow.prepareClusterKWIC(
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
