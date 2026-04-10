import Foundation

struct NativeHostPreferencesSnapshot: Codable, Equatable {
    var languageMode: AppLanguageMode
    var autoUpdateEnabled: Bool
    var checkForUpdatesOnLaunch: Bool
    var autoDownloadUpdates: Bool
    var autoInstallDownloadedUpdates: Bool
    var recentDocuments: [RecentDocumentItem]
    var lastUpdateCheckAt: String
    var lastUpdateStatus: String
    var downloadedUpdateVersion: String
    var downloadedUpdateName: String
    var downloadedUpdatePath: String
    var taskHistory: [PersistedNativeBackgroundTaskItem]

    static let `default` = NativeHostPreferencesSnapshot(
        languageMode: .system,
        autoUpdateEnabled: true,
        checkForUpdatesOnLaunch: true,
        autoDownloadUpdates: false,
        autoInstallDownloadedUpdates: false,
        recentDocuments: [],
        lastUpdateCheckAt: "",
        lastUpdateStatus: "尚未检查更新。",
        downloadedUpdateVersion: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        taskHistory: []
    )

    enum CodingKeys: String, CodingKey {
        case languageMode
        case autoUpdateEnabled
        case checkForUpdatesOnLaunch
        case autoDownloadUpdates
        case autoInstallDownloadedUpdates
        case recentDocuments
        case lastUpdateCheckAt
        case lastUpdateStatus
        case downloadedUpdateVersion
        case downloadedUpdateName
        case downloadedUpdatePath
        case taskHistory
    }

    init(
        languageMode: AppLanguageMode,
        autoUpdateEnabled: Bool,
        checkForUpdatesOnLaunch: Bool,
        autoDownloadUpdates: Bool,
        autoInstallDownloadedUpdates: Bool,
        recentDocuments: [RecentDocumentItem],
        lastUpdateCheckAt: String,
        lastUpdateStatus: String,
        downloadedUpdateVersion: String,
        downloadedUpdateName: String,
        downloadedUpdatePath: String,
        taskHistory: [PersistedNativeBackgroundTaskItem] = []
    ) {
        self.languageMode = languageMode
        self.autoUpdateEnabled = autoUpdateEnabled
        self.checkForUpdatesOnLaunch = checkForUpdatesOnLaunch
        self.autoDownloadUpdates = autoDownloadUpdates
        self.autoInstallDownloadedUpdates = autoInstallDownloadedUpdates
        self.recentDocuments = recentDocuments
        self.lastUpdateCheckAt = lastUpdateCheckAt
        self.lastUpdateStatus = lastUpdateStatus
        self.downloadedUpdateVersion = downloadedUpdateVersion
        self.downloadedUpdateName = downloadedUpdateName
        self.downloadedUpdatePath = downloadedUpdatePath
        self.taskHistory = taskHistory
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.languageMode = try container.decodeIfPresent(AppLanguageMode.self, forKey: .languageMode) ?? .system
        self.autoUpdateEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoUpdateEnabled) ?? true
        self.checkForUpdatesOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? true
        self.autoDownloadUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadUpdates) ?? false
        self.autoInstallDownloadedUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoInstallDownloadedUpdates) ?? false
        self.recentDocuments = try container.decodeIfPresent([RecentDocumentItem].self, forKey: .recentDocuments) ?? []
        self.lastUpdateCheckAt = try container.decodeIfPresent(String.self, forKey: .lastUpdateCheckAt) ?? ""
        self.lastUpdateStatus = try container.decodeIfPresent(String.self, forKey: .lastUpdateStatus) ?? "尚未检查更新。"
        self.downloadedUpdateVersion = try container.decodeIfPresent(String.self, forKey: .downloadedUpdateVersion) ?? ""
        self.downloadedUpdateName = try container.decodeIfPresent(String.self, forKey: .downloadedUpdateName) ?? ""
        self.downloadedUpdatePath = try container.decodeIfPresent(String.self, forKey: .downloadedUpdatePath) ?? ""
        self.taskHistory = try container.decodeIfPresent([PersistedNativeBackgroundTaskItem].self, forKey: .taskHistory) ?? []
    }
}
