import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var workspace: MainWorkspaceViewModel
    @StateObject private var dispatcher: WorkspaceActionDispatcher

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _dispatcher = StateObject(
            wrappedValue: WorkspaceActionDispatcher(
                workspace: workspace,
                preferredWindowRoute: .settings
            )
        )
    }

    var body: some View {
        SettingsPaneView(
            settings: workspace.settings,
            onAction: dispatcher.handleSettingsAction
        )
        .adaptiveWindowScaffold(for: .settings)
        .bindWindowRoute(.settings, titleProvider: { mode in
            NativeWindowRoute.settings.title(in: mode)
        })
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .settings))
        .task {
            await workspace.initializeIfNeeded()
            workspace.syncSceneGraph(source: .settings)
        }
        .frame(minWidth: 980, minHeight: 720)
    }
}
