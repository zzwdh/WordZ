import SwiftUI

@main
struct WordZMacApp: App {
    @NSApplicationDelegateAdaptor(NativeApplicationDelegate.self) private var applicationDelegate
    @StateObject private var workspace: MainWorkspaceViewModel
    @StateObject private var localization = WordZLocalization.shared

    init() {
        let container = NativeAppContainer.live()
        _workspace = StateObject(wrappedValue: container.makeMainWorkspaceViewModel())
    }

    var body: some Scene {
        WindowGroup("WordZ", id: NativeWindowRoute.mainWorkspace.id) {
            RootContentView(
                viewModel: workspace,
                applicationDelegate: applicationDelegate
            )
            .environmentObject(localization)
            .environment(\.wordZLanguageMode, localization.effectiveMode)
            .frame(minWidth: 1180, minHeight: 760)
        }
        .commands {
            WordZMacCommands(workspace: workspace)
        }

        Window("语料库", id: NativeWindowRoute.library.id) {
            LibraryWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }

        Settings {
            SettingsWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }

        Window("任务中心", id: NativeWindowRoute.taskCenter.id) {
            TaskCenterWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }
        .windowResizability(.contentSize)

        Window("更新", id: NativeWindowRoute.updatePrompt.id) {
            UpdateWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }
        .windowResizability(.contentSize)

        Window("关于 WordZ", id: NativeWindowRoute.about.id) {
            AboutWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }
        .windowResizability(.contentSize)

        Window("使用说明", id: NativeWindowRoute.help.id) {
            HelpCenterWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }
        .windowResizability(.contentSize)

        Window("版本说明", id: NativeWindowRoute.releaseNotes.id) {
            ReleaseNotesWindowView(workspace: workspace)
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusMenuView(
                workspace: workspace,
                sidebar: workspace.sidebar,
                settings: workspace.settings,
                taskCenter: workspace.taskCenter
            )
                .environmentObject(localization)
                .environment(\.wordZLanguageMode, localization.effectiveMode)
        } label: {
            Image(nsImage: WordZMenuBarIcon.image())
                .accessibilityLabel("WordZ")
        }
        .menuBarExtraStyle(.menu)
    }
}
