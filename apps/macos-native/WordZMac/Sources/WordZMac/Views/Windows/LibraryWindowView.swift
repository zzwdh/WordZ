import SwiftUI

struct LibraryWindowView: View {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @StateObject private var dispatcher: WorkspaceActionDispatcher

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _dispatcher = StateObject(
            wrappedValue: WorkspaceActionDispatcher(
                workspace: workspace,
                preferredWindowRoute: .library
            )
        )
    }

    var body: some View {
        LibraryManagementView(
            viewModel: workspace.library,
            sidebar: workspace.sidebar,
            onAction: dispatcher.handleLibraryAction
        )
        .bindWindowRoute(.library)
        .task {
            await workspace.initializeIfNeeded()
            await workspace.refreshLibraryManagement()
        }
        .frame(minWidth: 1120, minHeight: 760)
    }
}
