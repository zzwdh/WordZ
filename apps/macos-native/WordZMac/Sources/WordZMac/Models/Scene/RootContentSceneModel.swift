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
        tabs: WorkspaceDetailTab.mainWorkspaceTabs.map {
            RootContentTabSceneItem(tab: $0, title: $0.displayTitle(in: .system))
        }
    )
}
