import Foundation

struct RootContentSceneBuilder {
    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        toolbar: WorkspaceToolbarSceneModel,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel {
        RootContentSceneModel(
            windowTitle: windowTitle,
            selectedTab: activeTab.mainWorkspaceTab,
            tabs: WorkspaceDetailTab.mainWorkspaceTabs.map {
                RootContentTabSceneItem(tab: $0, title: $0.displayTitle(in: languageMode))
            },
            toolbar: toolbar
        )
    }
}
