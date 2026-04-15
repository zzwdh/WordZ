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
        subtitle: l10n("准备连接本地语料工作台", table: "Windows", mode: .system, fallback: "Preparing the local corpus workspace"),
        workspaceSummary: l10n("等待初始化", table: "Errors", mode: .system, fallback: "Waiting for initialization"),
        canOpenSelection: false,
        recentDocuments: [],
        releaseNotes: [],
        help: []
    )
}
