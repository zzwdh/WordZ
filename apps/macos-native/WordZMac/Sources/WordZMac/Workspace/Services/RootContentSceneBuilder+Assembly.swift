import Foundation

extension RootContentSceneBuilder {
    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel {
        RootContentSceneModel(
            windowTitle: windowTitle,
            selectedTab: activeTab.mainWorkspaceTab,
            tabs: makeTabs(languageMode: languageMode)
        )
    }
}
