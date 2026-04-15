import Foundation

@MainActor
extension WorkspacePersistenceWorkflowService {
    func saveSettings(features: WorkspaceFeatureSet) async {
        do {
            try await repository.saveUISettings(features.settings.exportSnapshot())
            try hostPreferencesStore.save(features.settings.exportHostPreferences())
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func persistRecentCorpusSetSelection(
        _ corpusSetID: String?,
        features: WorkspaceFeatureSet
    ) async {
        guard let corpusSetID else { return }

        let currentSnapshot = features.settings.exportSnapshot()
        let nextRecentCorpusSetIDs = CorpusSetRecentsSupport.updatedRecentCorpusSetIDs(
            current: currentSnapshot.recentCorpusSetIDs,
            newID: corpusSetID
        )
        guard nextRecentCorpusSetIDs != currentSnapshot.recentCorpusSetIDs else { return }

        let nextSnapshot = UISettingsSnapshot(
            showWelcomeScreen: currentSnapshot.showWelcomeScreen,
            restoreWorkspace: currentSnapshot.restoreWorkspace,
            debugLogging: currentSnapshot.debugLogging,
            recentMetadataSourceLabels: currentSnapshot.recentMetadataSourceLabels,
            recentCorpusSetIDs: nextRecentCorpusSetIDs
        )

        do {
            try await repository.saveUISettings(nextSnapshot)
            features.settings.applyRecentCorpusSetIDs(nextRecentCorpusSetIDs)
            features.sidebar.applyRecentCorpusSetIDs(nextRecentCorpusSetIDs)
            features.library.applyRecentCorpusSetIDs(nextRecentCorpusSetIDs)
        } catch {
            return
        }
    }
}
