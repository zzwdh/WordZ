import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func applyWorkspaceSnapshot(_ workspaceSnapshot: WorkspaceSnapshotSummary, features: WorkspaceFeatureSet) {
        sessionWorkflow.applyWorkspaceSnapshot(workspaceSnapshot, features: features)
    }

    func resetFeatureResults(features: WorkspaceFeatureSet) {
        sessionWorkflow.resetFeatureResults(features: features)
    }

    func syncFeatureContexts(features: WorkspaceFeatureSet) {
        sessionWorkflow.syncFeatureContexts(features: features)
    }
}
