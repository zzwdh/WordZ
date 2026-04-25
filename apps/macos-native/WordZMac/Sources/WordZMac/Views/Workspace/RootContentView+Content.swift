import SwiftUI

extension RootContentView {
    var workspaceContent: some View {
        MainWorkspaceSplitContainer(
            isSidebarVisible: layoutState.sidebarVisibilityBinding,
            isInspectorVisible: layoutState.inspectorVisibilityBinding,
            topAccessory: workspaceTopAccessoryContent
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
            selectedRoute: selectedRouteBinding,
            openAnalysis: commandHandler.selectTab
        )
    }

    var workspaceMainPane: some View {
        currentDetailView
            .environmentObject(viewModel.lexicalAutocomplete)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Keep the main workspace on the stable window background until the
        // 26-specific detail pane treatment is tuned. The adaptive glass path
        // currently makes the analysis pane read as dimmed.
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
                guard viewModel.selectedRoute != nextValue else { return }
                shellActionHandler.handle(.selectRoute(nextValue))
            }
        )
    }

    var usesWorkspaceTopAccessory: Bool {
        false
    }

    var workspaceTopAccessoryContent: AnyView? {
        nil
    }
}
