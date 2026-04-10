import Foundation

@MainActor
extension WorkspaceSceneStore {
    var appInfoSnapshot: AppInfoSummary? {
        currentAppInfoSnapshot()
    }
}
