import SwiftUI
import WordZWindowing

extension WordZCoreAppScenes {
    @MainActor
    @SceneBuilder
    static func evidenceWorkbenchWindow(
        workspace: MainWorkspaceViewModel,
        localization: WordZLocalization
    ) -> some Scene {
        Window("Evidence Workbench", id: NativeWindowRoute.evidenceWorkbench.id) {
            EvidenceWorkbenchWindowView(workspace: workspace)
                .wordZLocalizedEnvironment(localization)
        }
        .nativeWindowScenePresentation(.evidenceWorkbench)
    }
}
