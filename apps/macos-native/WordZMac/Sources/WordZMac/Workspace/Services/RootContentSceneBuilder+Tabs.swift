import Foundation

extension RootContentSceneBuilder {
    func makeTabs(languageMode: AppLanguageMode) -> [RootContentTabSceneItem] {
        WorkspaceDetailTab.mainWorkspaceTabs.map {
            RootContentTabSceneItem(tab: $0, title: $0.displayTitle(in: languageMode))
        }
    }
}
