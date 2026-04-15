import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func persistWorkspaceState(
        features: WorkspaceFeatureSet,
        refreshPresentationAfterSave: Bool = true,
        syncWindowAfterSave: Bool = true
    ) {
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            refreshPresentationAfterSave: refreshPresentationAfterSave,
            syncWindowAfterSave: syncWindowAfterSave,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func currentWorkspaceDraft(features: WorkspaceFeatureSet) -> WorkspaceStateDraft {
        persistenceWorkflow.currentWorkspaceDraft(features: features)
    }

    func refreshRecentDocuments(features: WorkspaceFeatureSet) {
        persistenceWorkflow.refreshRecentDocuments(features: features)
    }
}
