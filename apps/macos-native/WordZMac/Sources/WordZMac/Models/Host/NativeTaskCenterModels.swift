import Foundation

extension NativeBackgroundTaskState {
    func displayLabel(in mode: AppLanguageMode) -> String {
        switch self {
        case .running:
            return wordZText("进行中", "Running", mode: mode)
        case .completed:
            return wordZText("已完成", "Completed", mode: mode)
        case .failed:
            return wordZText("失败", "Failed", mode: mode)
        }
    }

    var symbolName: String {
        switch self {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}

extension NativeBackgroundTaskAction {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .cancelTask:
            return wordZText("取消", "Cancel", mode: mode)
        case .openFile:
            return wordZText("打开文件", "Open File", mode: mode)
        case .openURL:
            return wordZText("查看详情", "View Details", mode: mode)
        case .installDownloadedUpdate:
            return wordZText("安装更新", "Install Update", mode: mode)
        }
    }
}

extension NativeBackgroundTaskItem {
    func progressLabel(in mode: AppLanguageMode) -> String {
        guard let normalizedProgress else {
            return state.displayLabel(in: mode)
        }
        return "\(Int((normalizedProgress * 100).rounded()))%"
    }
}

struct NativeTaskCenterSceneModel: Equatable {
    let items: [NativeBackgroundTaskItem]
    let runningCount: Int
    let completedCount: Int
    let failedCount: Int
    let summary: String
    let aggregateProgress: Double?
    let highlightedItems: [NativeBackgroundTaskItem]

    static let empty = NativeTaskCenterSceneModel(
        items: [],
        runningCount: 0,
        completedCount: 0,
        failedCount: 0,
        summary: "当前没有后台任务。",
        aggregateProgress: nil,
        highlightedItems: []
    )
}

struct NativeUpdateStateSnapshot: Equatable {
    let currentVersion: String
    let latestVersion: String
    let releaseURL: String
    let statusMessage: String
    let updateAvailable: Bool
    let isChecking: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let downloadedUpdateVersion: String
    let downloadedUpdateName: String
    let downloadedUpdatePath: String
    let releaseTitle: String
    let publishedAt: String
    let releaseNotes: [String]
    let assetName: String

    static let empty = NativeUpdateStateSnapshot(
        currentVersion: "",
        latestVersion: "",
        releaseURL: "",
        statusMessage: "尚未检查更新。",
        updateAvailable: false,
        isChecking: false,
        isDownloading: false,
        downloadProgress: nil,
        downloadedUpdateVersion: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        releaseTitle: "",
        publishedAt: "",
        releaseNotes: [],
        assetName: ""
    )

    var hasDownloadedUpdate: Bool {
        !downloadedUpdatePath.isEmpty
    }

    var canDownloadUpdate: Bool {
        updateAvailable && !assetName.isEmpty && !isDownloading && !hasDownloadedUpdate
    }

    var canInstallDownloadedUpdate: Bool {
        !downloadedUpdatePath.isEmpty
    }
}
