import SwiftUI
import WordZWindowing

extension WordZCoreAppScenes {
    @MainActor
    @SceneBuilder
    static func evidenceWorkbenchWindow(
        workspace: MainWorkspaceViewModel,
        localization: WordZLocalization
    ) -> some Scene {
        Window("Clips", id: NativeWindowRoute.evidenceWorkbench.id) {
            EvidenceWorkbenchWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.evidenceWorkbench)
    }
}
