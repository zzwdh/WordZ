import Foundation

extension EngineClient {
    func fetchWorkspaceState() async throws -> WorkspaceSnapshotSummary {
        let result = try await invokeResult(method: EngineContracts.Method.workspaceGetState)
        return WorkspaceSnapshotSummary(json: JSONFieldReader.dictionary(result, key: "snapshot"))
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.workspaceSaveState,
            params: ["snapshot": draft.asJSONObject()]
        )
    }

    func fetchUISettings() async throws -> UISettingsSnapshot {
        let result = try await invokeResult(method: EngineContracts.Method.workspaceGetUiSettings)
        return UISettingsSnapshot(json: JSONFieldReader.dictionary(result, key: "settings"))
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.workspaceSaveUiSettings,
            params: ["settings": snapshot.asJSONObject()]
        )
    }
}
