import Foundation

@MainActor
protocol RootContentSceneBuilding {
    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel
}

