import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func saveCompareCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await libraryWorkflow.saveCompareCorpusSet(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveKWICCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await libraryWorkflow.saveKWICCorpusSet(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveLocatorCorpusSet(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await libraryWorkflow.saveLocatorCorpusSet(
            features: features,
            preferredRoute: preferredRoute
        )
    }
}
