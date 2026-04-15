import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func refreshConcordanceSavedSets() async {
        await flowCoordinator.refreshConcordanceSavedSets(features: features)
        syncResultContentSceneGraph(for: .kwic)
        syncResultContentSceneGraph(for: .locator)
    }

    func importConcordanceSavedSetsJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.importConcordanceSavedSetsJSON(
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .kwic)
        syncResultContentSceneGraph(for: .locator)
    }

    func saveKWICCurrentHitSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveKWICConcordanceSavedSet(
            scope: .current,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .kwic)
    }

    func saveKWICVisibleHitSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveKWICConcordanceSavedSet(
            scope: .visible,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .kwic)
    }

    func saveRefinedKWICSavedSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveRefinedConcordanceSavedSet(
            kind: .kwic,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .kwic)
    }

    func saveSelectedKWICSavedSetNotes() async {
        await flowCoordinator.saveSelectedConcordanceSavedSetNotes(
            kind: .kwic,
            features: features
        )
        syncResultContentSceneGraph(for: .kwic)
    }

    func deleteKWICSavedSet(_ setID: String) async {
        await flowCoordinator.deleteConcordanceSavedSet(setID: setID, features: features)
        syncResultContentSceneGraph(for: .kwic)
    }

    func exportSelectedKWICSavedSetJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSelectedConcordanceSavedSetJSON(
            kind: .kwic,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .kwic)
    }

    func loadSelectedKWICSavedSet() async {
        await flowCoordinator.loadSelectedConcordanceSavedSet(
            kind: .kwic,
            features: features
        )
        syncResultContentSceneGraph(for: .kwic, rebuildRootScene: true)
        syncResultContentSceneGraph(for: .locator)
    }

    func saveLocatorCurrentHitSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveLocatorConcordanceSavedSet(
            scope: .current,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .locator)
    }

    func saveLocatorVisibleHitSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveLocatorConcordanceSavedSet(
            scope: .visible,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .locator)
    }

    func saveRefinedLocatorSavedSet(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.saveRefinedConcordanceSavedSet(
            kind: .locator,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .locator)
    }

    func saveSelectedLocatorSavedSetNotes() async {
        await flowCoordinator.saveSelectedConcordanceSavedSetNotes(
            kind: .locator,
            features: features
        )
        syncResultContentSceneGraph(for: .locator)
    }

    func deleteLocatorSavedSet(_ setID: String) async {
        await flowCoordinator.deleteConcordanceSavedSet(setID: setID, features: features)
        syncResultContentSceneGraph(for: .locator)
    }

    func exportSelectedLocatorSavedSetJSON(preferredWindowRoute: NativeWindowRoute? = nil) async {
        await flowCoordinator.exportSelectedConcordanceSavedSetJSON(
            kind: .locator,
            features: features,
            preferredRoute: preferredWindowRoute
        )
        syncResultContentSceneGraph(for: .locator)
    }

    func loadSelectedLocatorSavedSet() async {
        await flowCoordinator.loadSelectedConcordanceSavedSet(
            kind: .locator,
            features: features
        )
        syncResultContentSceneGraph(for: .locator, rebuildRootScene: true)
        syncResultContentSceneGraph(for: .kwic)
    }
}
