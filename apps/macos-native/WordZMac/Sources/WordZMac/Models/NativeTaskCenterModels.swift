import Foundation

enum NativeBackgroundTaskState: String, Codable, Equatable {
    case running
    case completed
    case failed

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

enum NativeBackgroundTaskAction: Equatable {
    case cancelTask(id: UUID)
    case openFile(path: String)
    case openURL(String)
    case installDownloadedUpdate(path: String)

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

struct NativeBackgroundTaskItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let state: NativeBackgroundTaskState
    let progress: Double?
    let startedAt: Date
    let updatedAt: Date
    let primaryAction: NativeBackgroundTaskAction?

    var normalizedProgress: Double? {
        guard let progress else { return nil }
        return min(max(progress, 0), 1)
    }

    func progressLabel(in mode: AppLanguageMode) -> String {
        guard let normalizedProgress else {
            return state.displayLabel(in: mode)
        }
        return "\(Int((normalizedProgress * 100).rounded()))%"
    }
}

struct PersistedNativeBackgroundTaskAction: Codable, Equatable {
    let kind: String
    let value: String

    init?(action: NativeBackgroundTaskAction?) {
        guard let action else { return nil }
        switch action {
        case .cancelTask:
            return nil
        case .openFile(let path):
            self.kind = "openFile"
            self.value = path
        case .openURL(let url):
            self.kind = "openURL"
            self.value = url
        case .installDownloadedUpdate(let path):
            self.kind = "installDownloadedUpdate"
            self.value = path
        }
    }

    var action: NativeBackgroundTaskAction? {
        switch kind {
        case "openFile":
            return .openFile(path: value)
        case "openURL":
            return .openURL(value)
        case "installDownloadedUpdate":
            return .installDownloadedUpdate(path: value)
        default:
            return nil
        }
    }
}

struct PersistedNativeBackgroundTaskItem: Codable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let state: NativeBackgroundTaskState
    let progress: Double?
    let startedAt: Date
    let updatedAt: Date
    let primaryAction: PersistedNativeBackgroundTaskAction?

    init(item: NativeBackgroundTaskItem) {
        self.id = item.id
        self.title = item.title
        self.detail = item.detail
        self.state = item.state
        self.progress = item.progress
        self.startedAt = item.startedAt
        self.updatedAt = item.updatedAt
        self.primaryAction = PersistedNativeBackgroundTaskAction(action: item.primaryAction)
    }

    func restoredItem(interruptedDetail: String) -> NativeBackgroundTaskItem {
        let restoredState: NativeBackgroundTaskState = state == .running ? .failed : state
        let restoredDetail: String
        if state == .running {
            restoredDetail = detail.isEmpty ? interruptedDetail : "\(detail) \(interruptedDetail)"
        } else {
            restoredDetail = detail
        }
        return NativeBackgroundTaskItem(
            id: id,
            title: title,
            detail: restoredDetail,
            state: restoredState,
            progress: restoredState == .completed ? 1 : (restoredState == .running ? progress : nil),
            startedAt: startedAt,
            updatedAt: updatedAt,
            primaryAction: restoredState == .running ? nil : primaryAction?.action
        )
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
