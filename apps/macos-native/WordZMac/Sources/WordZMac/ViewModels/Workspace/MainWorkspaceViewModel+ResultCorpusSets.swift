import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func saveCompareCorpusSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveCompareCorpusSet(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .full)
    }

    func saveKWICCorpusSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveKWICCorpusSet(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .full)
    }

    func saveLocatorCorpusSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveLocatorCorpusSet(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncSceneGraph(source: .full)
    }
}
