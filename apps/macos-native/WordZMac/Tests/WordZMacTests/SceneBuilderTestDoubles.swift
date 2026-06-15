import WordZShared
@testable import WordZWorkspaceCore

@MainActor
final class CountingRootContentSceneBuilder: RootContentSceneBuilding {
    private(set) var buildCallCount = 0

    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel {
        buildCallCount += 1
        return RootContentSceneBuilder().build(
            windowTitle: windowTitle,
            activeTab: activeTab,
            languageMode: languageMode
        )
    }
}
