import Foundation
import WordZShared

extension RootContentSceneBuilder {
    func makeTabs(languageMode: AppLanguageMode) -> [RootContentTabSceneItem] {
        WorkspaceFeatureRegistry.mainTabs.map { tab in
            RootContentTabSceneItem(
                tab: tab,
                title: WorkspaceFeatureRegistry.descriptor(for: tab).title(in: languageMode)
            )
        }
    }
}
