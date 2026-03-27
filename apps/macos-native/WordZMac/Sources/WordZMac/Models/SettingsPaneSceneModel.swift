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
    let zoomLabel: String
    let fontScaleLabel: String
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
        workspaceSummary: "等待载入本地语料库",
        buildSummary: "SwiftUI + Swift native engine",
        help: [],
        releaseNotes: [],
        latestReleaseNotes: [],
        recentDocuments: [],
        userDataDirectory: "",
        updateSummary: "尚未检查更新。",
        supportStatus: "准备就绪",
        zoomLabel: "100%",
        fontScaleLabel: "100%",
        latestVersionLabel: "未知",
        latestReleaseTitle: "",
        latestReleasePublishedLabel: "",
        latestAssetName: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        taskCenterSummary: "当前没有后台任务。",
        canDownloadUpdate: false,
        canInstallDownloadedUpdate: false,
        isCheckingUpdates: false,
        isDownloadingUpdate: false,
        downloadProgressLabel: ""
    )
}
