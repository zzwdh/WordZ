import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func openSelectedCorpus(features: WorkspaceFeatureSet) async {
        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: features.sidebar.selectedCorpusID)
            applyWorkspacePresentation(features: features)
            refreshRecentDocuments(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
            syncWindowDocumentState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func saveSettings(features: WorkspaceFeatureSet) async {
        do {
            try await repository.saveUISettings(features.settings.exportSnapshot())
            try hostPreferencesStore.save(features.settings.exportHostPreferences())
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }
}
