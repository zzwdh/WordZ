import Foundation

import WordZWindowing
@MainActor
package final class WorkspaceActionDispatcher: ObservableObject {
    unowned let workspace: MainWorkspaceViewModel
    let preferredWindowRoute: NativeWindowRoute?

    package init(workspace: MainWorkspaceViewModel, preferredWindowRoute: NativeWindowRoute? = nil) {
        self.workspace = workspace
        self.preferredWindowRoute = preferredWindowRoute
    }
}
