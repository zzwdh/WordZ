import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func restoreSelectionFromWorkspace(
        features: WorkspaceFeatureSet,
        restoreWorkspace: Bool
    ) {
        sessionWorkflow.restoreSelectionFromWorkspace(features: features, restoreWorkspace: restoreWorkspace)
    }

    func newWorkspace(features: WorkspaceFeatureSet) async {
        await sessionWorkflow.newWorkspace(features: features)
    }

    func restoreSavedWorkspace(features: WorkspaceFeatureSet) async {
        await sessionWorkflow.restoreSavedWorkspace(features: features)
    }

    func handleCorpusSelectionChange(features: WorkspaceFeatureSet) {
        sessionWorkflow.handleCorpusSelectionChange(features: features)
    }

    func prepareCorpusSelectionChange(features: WorkspaceFeatureSet) {
        sessionWorkflow.prepareCorpusSelectionChange(features: features)
    }

    func markWorkspaceEdited(features: WorkspaceFeatureSet) {
        sessionWorkflow.markWorkspaceEdited(features: features)
    }

    func markInputStateEdited(features: WorkspaceFeatureSet) {
        sessionWorkflow.markInputStateEdited(features: features)
    }

    func applyWorkspacePresentation(features: WorkspaceFeatureSet) {
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func syncWindowDocumentState(features: WorkspaceFeatureSet) {
        persistenceWorkflow.syncWindowDocumentState(features: features)
    }
}
