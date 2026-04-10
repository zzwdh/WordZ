import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func sync(_ source: SceneSyncSource, after mutation: () -> Void) {
        mutation()
        workspace.syncSceneGraph(source: source)
    }

    func syncResult(_ tab: WorkspaceDetailTab, after mutation: () -> Void) {
        mutation()
        workspace.syncResultContentSceneGraph(for: tab)
    }
}
