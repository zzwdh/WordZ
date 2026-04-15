import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func refreshLibraryManagement(features: WorkspaceFeatureSet) async {
        await libraryWorkflow.refreshLibraryManagement(features: features)
    }

    func handleLibraryAction(
        _ action: LibraryManagementAction,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await libraryWorkflow.handleLibraryAction(
            action,
            features: features,
            preferredRoute: preferredRoute,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func showSelectedCorpusInfo(features: WorkspaceFeatureSet) async throws {
        try await libraryWorkflow.showSelectedCorpusInfo(features: features)
    }
}
