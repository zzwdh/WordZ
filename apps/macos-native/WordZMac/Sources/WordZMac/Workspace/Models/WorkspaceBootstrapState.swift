import Foundation

struct WorkspaceBootstrapState: Sendable {
    let appInfo: AppInfoSummary
    let librarySnapshot: LibrarySnapshot
    let workspaceSnapshot: WorkspaceSnapshotSummary
    let uiSettings: UISettingsSnapshot
}
