import Foundation

struct SettingsPaneSceneModel: Equatable {
    let workspaceSummary: String
    let buildSummary: String
    let help: [String]
    let releaseNotes: [String]
    let latestReleaseNotes: [String]
    let recentDocuments: [RecentDocumentItem]
    let userDataDirectory: String
    let updateSummary: String
    let supportStatus: String
    let latestVersionLabel: String
    let latestReleaseTitle: String
    let latestReleasePublishedLabel: String
    let latestAssetName: String
    let downloadedUpdateName: String
    let downloadedUpdatePath: String
    let taskCenterSummary: String
    let canDownloadUpdate: Bool
    let canInstallDownloadedUpdate: Bool
    let isCheckingUpdates: Bool
    let isDownloadingUpdate: Bool
    let downloadProgressLabel: String

    static let empty = SettingsPaneSceneModel(
        workspaceSummary: l10n("等待载入本地语料库", table: "Errors", mode: .system, fallback: "Waiting for the local corpus library"),
        buildSummary: "SwiftUI + Swift native engine",
        help: [],
        releaseNotes: [],
        latestReleaseNotes: [],
        recentDocuments: [],
        userDataDirectory: "",
        updateSummary: l10n("尚未检查更新。", table: "Errors", mode: .system, fallback: "No update check has run yet."),
        supportStatus: l10n("准备就绪", table: "Errors", mode: .system, fallback: "Ready"),
        latestVersionLabel: l10n("未知", mode: .system, fallback: "Unknown"),
        latestReleaseTitle: "",
        latestReleasePublishedLabel: "",
        latestAssetName: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        taskCenterSummary: l10n("当前没有后台任务。", table: "Errors", mode: .system, fallback: "No background tasks right now."),
        canDownloadUpdate: false,
        canInstallDownloadedUpdate: false,
        isCheckingUpdates: false,
        isDownloadingUpdate: false,
        downloadProgressLabel: ""
    )
}
