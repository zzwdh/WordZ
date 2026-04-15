import Foundation

struct RootContentTabSceneItem: Identifiable, Equatable {
    let tab: WorkspaceDetailTab
    let title: String

    var id: String { tab.id }
}

struct RootContentSceneModel: Equatable {
    let windowTitle: String
    let selectedTab: WorkspaceDetailTab
    let tabs: [RootContentTabSceneItem]

    static let empty = RootContentSceneModel(
        windowTitle: "WordZ",
        selectedTab: .stats,
        tabs: WorkspaceFeatureRegistry.mainTabs.map { tab in
            RootContentTabSceneItem(
                tab: tab,
                title: WorkspaceFeatureRegistry.descriptor(for: tab).title(in: .system)
            )
        }
    )
}
