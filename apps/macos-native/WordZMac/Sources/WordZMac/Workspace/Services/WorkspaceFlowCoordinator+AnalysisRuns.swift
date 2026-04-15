import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func openSelectedCorpus(features: WorkspaceFeatureSet) async {
        await sessionWorkflow.openSelectedCorpus(features: features)
    }

    func saveSettings(features: WorkspaceFeatureSet) async {
        await persistenceWorkflow.saveSettings(features: features)
    }
}
