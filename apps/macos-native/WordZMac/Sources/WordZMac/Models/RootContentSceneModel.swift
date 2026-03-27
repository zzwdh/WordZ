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
    let toolbar: WorkspaceToolbarSceneModel

    static let empty = RootContentSceneModel(
        windowTitle: "WordZ",
        selectedTab: .stats,
        tabs: WorkspaceDetailTab.allCases.map {
            RootContentTabSceneItem(tab: $0, title: $0.displayTitle(in: .system))
        },
        toolbar: WorkspaceToolbarSceneModel(items: [])
    )
}
