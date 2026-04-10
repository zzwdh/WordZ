import Foundation

@MainActor
final class WorkspaceActionDispatcher: ObservableObject {
    unowned let workspace: MainWorkspaceViewModel
    let preferredWindowRoute: NativeWindowRoute?

    init(workspace: MainWorkspaceViewModel, preferredWindowRoute: NativeWindowRoute? = nil) {
        self.workspace = workspace
        self.preferredWindowRoute = preferredWindowRoute
    }
}
