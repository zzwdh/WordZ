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
        WindowGroup {
            RootContentView(
                viewModel: workspace,
                applicationDelegate: applicationDelegate
            )
            .environmentObject(localization)
            .environment(\.wordZLanguageMode, localization.effectiveMode)
            .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            WordZMacCommands(workspace: workspace)
        }

        Window("任务中心", id: NativeWindowRoute.taskCenter.id) {
            TaskCenterWindowView(workspace: workspace)
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

        Window("帮助中心", id: NativeWindowRoute.help.id) {
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
    }
}
