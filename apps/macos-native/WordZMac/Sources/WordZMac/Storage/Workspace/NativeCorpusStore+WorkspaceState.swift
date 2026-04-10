import Foundation

extension NativeCorpusStore {
    func loadWorkspaceSnapshot() throws -> WorkspaceSnapshotSummary {
        try loadWorkspacePersistedSnapshot().workspaceSnapshot
    }

    func saveWorkspaceSnapshot(_ draft: WorkspaceStateDraft) throws {
        let persisted = NativePersistedWorkspaceSnapshot(draft: draft)
        cachedWorkspaceSnapshot = persisted
        try snapshotStore.saveWorkspaceSnapshot(persisted)
    }

    func loadUISettings() throws -> UISettingsSnapshot {
        try loadPersistedUISettings().uiSettings
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) throws {
        let persisted = NativePersistedUISettings(
            showWelcomeScreen: snapshot.showWelcomeScreen,
            restoreWorkspace: snapshot.restoreWorkspace,
            debugLogging: snapshot.debugLogging
        )
        cachedUISettings = persisted
        try snapshotStore.saveUISettings(persisted)
    }
}
