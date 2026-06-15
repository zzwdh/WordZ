import SwiftUI
import WordZWindowing
import WordZShared

package enum WordZCoreAppScenes {
    @MainActor
    @SceneBuilder
    package static func make<LibraryWindowContent: View>(
        workspace: MainWorkspaceViewModel,
        applicationDelegate: NativeApplicationDelegate,
        menuBarController: WordZMenuBarController,
        localization: WordZLocalization,
        @ViewBuilder libraryWindowContent: @escaping (MainWorkspaceViewModel) -> LibraryWindowContent
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
            libraryWindowContent(workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.library)

        Window("Source Text", id: NativeWindowRoute.sourceReader.id) {
            SourceReaderWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.sourceReader)

        Settings {
            SettingsWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.settings)

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
