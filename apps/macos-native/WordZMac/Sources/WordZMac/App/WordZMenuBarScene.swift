import SwiftUI

struct WordZMenuBarScene: Scene {
    @ObservedObject private var workspace: MainWorkspaceViewModel
    @ObservedObject private var settings: WorkspaceSettingsViewModel
    @ObservedObject private var localization: WordZLocalization

    init(
        workspace: MainWorkspaceViewModel,
        localization: WordZLocalization
    ) {
        _workspace = ObservedObject(wrappedValue: workspace)
        _settings = ObservedObject(wrappedValue: workspace.settings)
        _localization = ObservedObject(wrappedValue: localization)
    }

    var body: some Scene {
        MenuBarExtra(isInserted: menuBarInsertionBinding) {
            MenuBarStatusMenuView(
                workspace: workspace,
                sidebar: workspace.sidebar,
                settings: settings,
                taskCenter: workspace.taskCenter
            )
            .wordZLocalizedEnvironment(localization)
        } label: {
            WordZMenuBarStatusIconView(
                status: workspace.menuBarStatus
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarInsertionBinding: Binding<Bool> {
        Binding(
            get: { settings.showMenuBarIcon },
            set: { settings.showMenuBarIcon = $0 }
        )
    }
}
