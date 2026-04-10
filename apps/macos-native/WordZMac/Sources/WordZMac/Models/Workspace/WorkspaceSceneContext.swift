import Foundation

struct WorkspaceSceneContext: Equatable {
    let appName: String
    let versionLabel: String
    let workspaceSummary: String
    let buildSummary: String
    let help: [String]

    static let empty = WorkspaceSceneContext(
        appName: "WordZ",
        versionLabel: "mac native preview",
        workspaceSummary: "等待载入本地语料库",
        buildSummary: "SwiftUI + Node.js sidecar",
        help: []
    )
}
