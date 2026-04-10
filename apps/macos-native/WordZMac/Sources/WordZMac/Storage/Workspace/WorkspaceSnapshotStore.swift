import Foundation

protocol WorkspaceSnapshotStore: AnyObject {
    func loadWorkspaceSnapshot() throws -> WorkspaceSnapshotSummary
    func saveWorkspaceSnapshot(_ draft: WorkspaceStateDraft) throws
    func loadUISettings() throws -> UISettingsSnapshot
    func saveUISettings(_ snapshot: UISettingsSnapshot) throws
}
