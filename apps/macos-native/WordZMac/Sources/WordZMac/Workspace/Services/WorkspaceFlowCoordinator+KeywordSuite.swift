import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func importKeywordReferenceWordList(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.importKeywordReferenceWordList(
            features: features,
            preferredRoute: preferredRoute,
            markWorkspaceEdited: markWorkspaceEdited
        )
    }

    func refreshKeywordSavedLists(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.refreshKeywordSavedLists(features: features)
    }

    func saveKeywordCurrentList(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.saveKeywordCurrentList(features: features)
    }

    func deleteKeywordSavedList(listID: String, features: WorkspaceFeatureSet) async {
        await analysisWorkflow.deleteKeywordSavedList(listID: listID, features: features)
    }

    func importKeywordSavedListsJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.importKeywordSavedListsJSON(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportKeywordSavedListsJSON(
        scope: KeywordSavedListExportScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportKeywordSavedListsJSON(
            scope: scope,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportKeywordRowContext(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportKeywordRowContext(
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func prepareKeywordKWIC(
        scope: KeywordKWICScope,
        features: WorkspaceFeatureSet
    ) async -> Bool {
        await analysisWorkflow.prepareKeywordKWIC(
            scope: scope,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
