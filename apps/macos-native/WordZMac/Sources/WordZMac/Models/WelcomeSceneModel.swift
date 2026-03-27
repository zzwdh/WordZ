import Foundation

struct WelcomeSceneModel: Equatable {
    let title: String
    let subtitle: String
    let workspaceSummary: String
    let canOpenSelection: Bool
    let recentDocuments: [RecentDocumentItem]
    let releaseNotes: [String]
    let help: [String]

    static let empty = WelcomeSceneModel(
        title: "WordZ",
        subtitle: "准备连接本地语料工作台",
        workspaceSummary: "等待初始化",
        canOpenSelection: false,
        recentDocuments: [],
        releaseNotes: [],
        help: []
    )
}
