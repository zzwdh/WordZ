import SwiftUI
import WordZWindowing

package enum WordZCoreAppScenes {
    @MainActor
    @SceneBuilder
    package static func make(
        workspace: MainWorkspaceViewModel,
        applicationDelegate: NativeApplicationDelegate,
        menuBarController: WordZMenuBarController,
        localization: WordZLocalization
    ) -> some Scene {
        WindowGroup("WordZ", id: NativeWindowRoute.mainWorkspace.id) {
            RootContentView(
                viewModel: workspace,
                applicationDelegate: applicationDelegate
            )
            .wordZLocalizedEnvironment(localization)
            .frame(minWidth: 1180, minHeight: 760)
            .task {
                menuBarController.start(applicationDelegate: applicationDelegate)
            }
        }
        .nativeWindowScenePresentation(.mainWorkspace)
        .commands {
            WordZMacCommands(workspace: workspace)
        }

        Window("Library", id: NativeWindowRoute.library.id) {
            LibraryWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.library)

        evidenceWorkbenchWindow(
            workspace: workspace,
            localization: localization
        )

        Window("Source Reader", id: NativeWindowRoute.sourceReader.id) {
            SourceReaderWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.sourceReader)

        Settings {
            SettingsWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.settings)

        Window("Task Center", id: NativeWindowRoute.taskCenter.id) {
            TaskCenterWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.taskCenter)

        Window("Update", id: NativeWindowRoute.updatePrompt.id) {
            UpdateWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.updatePrompt)

        Window("About WordZ", id: NativeWindowRoute.about.id) {
            AboutWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.about)

        Window("Usage Guide", id: NativeWindowRoute.help.id) {
            HelpCenterWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.help)

        Window("Release Notes", id: NativeWindowRoute.releaseNotes.id) {
            ReleaseNotesWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.releaseNotes)
    }
}
