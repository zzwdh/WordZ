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
            selectedTab: activeTab,
            tabs: WorkspaceDetailTab.allCases.map {
                RootContentTabSceneItem(tab: $0, title: $0.displayTitle(in: languageMode))
            },
            toolbar: toolbar
        )
    }
}
