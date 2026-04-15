import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func refreshConcordanceSavedSets(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.refreshConcordanceSavedSets(features: features)
    }

    func importConcordanceSavedSetsJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.importConcordanceSavedSetsJSON(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveKWICConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.saveKWICConcordanceSavedSet(
            scope: scope,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveLocatorConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.saveLocatorConcordanceSavedSet(
            scope: scope,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func deleteConcordanceSavedSet(
        setID: String,
        features: WorkspaceFeatureSet
    ) async {
        await analysisWorkflow.deleteConcordanceSavedSet(setID: setID, features: features)
    }

    func saveRefinedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.saveRefinedConcordanceSavedSet(
            kind: kind,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func saveSelectedConcordanceSavedSetNotes(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) async {
        await analysisWorkflow.saveSelectedConcordanceSavedSetNotes(
            kind: kind,
            features: features
        )
    }

    func exportSelectedConcordanceSavedSetJSON(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportSelectedConcordanceSavedSetJSON(
            kind: kind,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func loadSelectedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) async {
        await analysisWorkflow.loadSelectedConcordanceSavedSet(
            kind: kind,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
