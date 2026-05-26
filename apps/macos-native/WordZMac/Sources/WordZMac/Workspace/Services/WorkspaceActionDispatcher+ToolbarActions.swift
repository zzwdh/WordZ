import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleToolbarAction(_ action: WorkspaceToolbarAction) {
        handleWorkspaceIntent(WorkspaceIntent(toolbarAction: action))
    }
}
