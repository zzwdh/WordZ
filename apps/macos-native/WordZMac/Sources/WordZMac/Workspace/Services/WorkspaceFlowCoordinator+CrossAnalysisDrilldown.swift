import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func prepareCompareDrilldown(
        target: CompareDrilldownTarget,
        features: WorkspaceFeatureSet
    ) async -> Bool {
        await analysisWorkflow.prepareCompareDrilldown(
            target: target,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func prepareCollocateKWIC(features: WorkspaceFeatureSet) async -> Bool {
        await analysisWorkflow.prepareCollocateKWIC(
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
