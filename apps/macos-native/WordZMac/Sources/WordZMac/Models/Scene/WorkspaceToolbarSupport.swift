import Foundation

extension WorkspaceToolbarSceneModel {
    func item(for action: WorkspaceToolbarAction) -> WorkspaceToolbarActionItem? {
        items.first(where: { $0.action == action })
    }
}

extension WorkspaceToolbarAction {
    var nativeCommand: NativeAppCommand {
        WorkspaceActionRegistry.nativeCommand(for: self) ?? .refreshWorkspace
    }

    var toolbarSymbolName: String {
        WorkspaceActionRegistry.systemImage(for: self)
    }
}
