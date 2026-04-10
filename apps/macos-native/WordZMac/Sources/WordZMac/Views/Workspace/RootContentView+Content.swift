import SwiftUI

extension RootContentView {
    var workspaceContent: some View {
        MainWorkspaceSplitContainer(
            isSidebarVisible: layoutState.sidebarVisibilityBinding,
            isInspectorVisible: layoutState.inspectorVisibilityBinding
        ) {
            workspaceSidebarPane
        } detail: {
            workspaceMainPane
        } inspector: {
            workspaceInspectorPane
        }
    }

    var workspaceSidebarPane: some View {
        SidebarView(
            viewModel: viewModel.sidebar,
            selectedRoute: selectedRouteBinding
        )
    }

    var workspaceMainPane: some View {
        VStack(spacing: 0) {
            workspaceIssueBanner
            currentDetailView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WordZTheme.workspaceBackground)
    }

    var workspaceInspectorPane: some View {
        workspaceInspector
    }

    var selectedRouteBinding: Binding<WorkspaceMainRoute?> {
        Binding(
            get: { viewModel.selectedRoute },
            set: { nextValue in
                guard let nextValue else { return }
                shellActionHandler.handle(.selectRoute(nextValue))
            }
        )
    }
}
