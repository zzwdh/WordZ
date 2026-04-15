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
        workspaceSummary: l10n("等待载入本地语料库", table: "Errors", mode: .system, fallback: "Waiting for the local corpus library"),
        buildSummary: "SwiftUI + Node.js sidecar",
        help: []
    )
}
