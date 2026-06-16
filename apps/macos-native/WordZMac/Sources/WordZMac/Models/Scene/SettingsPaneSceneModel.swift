import Foundation

import WordZHost
import WordZShared
struct SettingsPaneSceneModel: Equatable {
    let workspaceSummary: String
    let buildSummary: String
    let help: [String]
    let releaseNotes: [String]
    let latestReleaseNotes: [String]
    let recentDocuments: [RecentDocumentItem]
    let userDataDirectory: String
    let updateSummary: String
    let apiSummary: String
    let apiCredentialStatus: String
    let apiCredentialConfigured: Bool
    let apiRequestTimeoutLabel: String
    let apiMaxConcurrentRequestsLabel: String
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
        buildSummary: "本机分析版",
        help: [],
        releaseNotes: [],
        latestReleaseNotes: [],
        recentDocuments: [],
        userDataDirectory: "",
        updateSummary: l10n("尚未检查更新。", table: "Errors", mode: .system, fallback: "No update check has run yet."),
        apiSummary: l10n("联网 API 可用。", table: "Errors", mode: .system, fallback: "Network API access is available."),
        apiCredentialStatus: l10n("未保存 API 凭据。", table: "Errors", mode: .system, fallback: "No API credential saved."),
        apiCredentialConfigured: false,
        apiRequestTimeoutLabel: "10 秒",
        apiMaxConcurrentRequestsLabel: "2",
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
