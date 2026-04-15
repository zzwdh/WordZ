import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func persistRecentCorpusSetSelection(
        _ corpusSetID: String?,
        features: WorkspaceFeatureSet
    ) async {
        await persistenceWorkflow.persistRecentCorpusSetSelection(corpusSetID, features: features)
    }
}
