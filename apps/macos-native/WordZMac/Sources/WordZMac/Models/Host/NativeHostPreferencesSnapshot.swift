import Foundation

struct NativeHostPreferencesSnapshot: Codable, Equatable {
    var languageMode: AppLanguageMode
    var autoUpdateEnabled: Bool
    var checkForUpdatesOnLaunch: Bool
    var autoDownloadUpdates: Bool
    var autoInstallDownloadedUpdates: Bool
    var showMenuBarIcon: Bool
    var recentDocuments: [RecentDocumentItem]
    var lastUpdateCheckAt: String
    var lastUpdateStatus: String
    var downloadedUpdateVersion: String
    var downloadedUpdateName: String
    var downloadedUpdatePath: String
    var taskHistory: [PersistedNativeBackgroundTaskItem]
    var hasCompletedInitialLaunch: Bool

    static let `default` = NativeHostPreferencesSnapshot(
        languageMode: .system,
        autoUpdateEnabled: true,
        checkForUpdatesOnLaunch: true,
        autoDownloadUpdates: false,
        autoInstallDownloadedUpdates: false,
        showMenuBarIcon: true,
        recentDocuments: [],
        lastUpdateCheckAt: "",
        lastUpdateStatus: Self.defaultLastUpdateStatus,
        downloadedUpdateVersion: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        taskHistory: [],
        hasCompletedInitialLaunch: false
    )

    enum CodingKeys: String, CodingKey {
        case languageMode
        case autoUpdateEnabled
        case checkForUpdatesOnLaunch
        case autoDownloadUpdates
        case autoInstallDownloadedUpdates
        case showMenuBarIcon
        case recentDocuments
        case lastUpdateCheckAt
        case lastUpdateStatus
        case downloadedUpdateVersion
        case downloadedUpdateName
        case downloadedUpdatePath
        case taskHistory
        case hasCompletedInitialLaunch
    }

    init(
        languageMode: AppLanguageMode,
        autoUpdateEnabled: Bool,
        checkForUpdatesOnLaunch: Bool,
        autoDownloadUpdates: Bool,
        autoInstallDownloadedUpdates: Bool,
        showMenuBarIcon: Bool = true,
        recentDocuments: [RecentDocumentItem],
        lastUpdateCheckAt: String,
        lastUpdateStatus: String,
        downloadedUpdateVersion: String,
        downloadedUpdateName: String,
        downloadedUpdatePath: String,
        taskHistory: [PersistedNativeBackgroundTaskItem] = [],
        hasCompletedInitialLaunch: Bool = false
    ) {
        self.languageMode = .system
        self.autoUpdateEnabled = autoUpdateEnabled
        self.checkForUpdatesOnLaunch = checkForUpdatesOnLaunch
        self.autoDownloadUpdates = autoDownloadUpdates
        self.autoInstallDownloadedUpdates = autoInstallDownloadedUpdates
        self.showMenuBarIcon = showMenuBarIcon
        self.recentDocuments = recentDocuments
        self.lastUpdateCheckAt = lastUpdateCheckAt
        self.lastUpdateStatus = lastUpdateStatus
        self.downloadedUpdateVersion = downloadedUpdateVersion
        self.downloadedUpdateName = downloadedUpdateName
        self.downloadedUpdatePath = downloadedUpdatePath
        self.taskHistory = taskHistory
        self.hasCompletedInitialLaunch = hasCompletedInitialLaunch
    }

    init(record: NativeHostPreferencesRecord) {
        self.languageMode = .system
        self.autoUpdateEnabled = record.autoUpdateEnabled
        self.checkForUpdatesOnLaunch = record.checkForUpdatesOnLaunch
        self.autoDownloadUpdates = record.autoDownloadUpdates
        self.autoInstallDownloadedUpdates = record.autoInstallDownloadedUpdates
        self.showMenuBarIcon = record.showMenuBarIcon
        self.recentDocuments = record.recentDocuments
        self.lastUpdateCheckAt = record.lastUpdateCheckAt
        self.lastUpdateStatus = Self.resolveLastUpdateStatus(record.lastUpdateStatus)
        self.downloadedUpdateVersion = record.downloadedUpdateVersion
        self.downloadedUpdateName = record.downloadedUpdateName
        self.downloadedUpdatePath = record.downloadedUpdatePath
        self.taskHistory = record.taskHistory
        self.hasCompletedInitialLaunch = record.hasCompletedInitialLaunch
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decodeIfPresent(AppLanguageMode.self, forKey: .languageMode)
        self.languageMode = .system
        self.autoUpdateEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoUpdateEnabled) ?? true
        self.checkForUpdatesOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? true
        self.autoDownloadUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadUpdates) ?? false
        self.autoInstallDownloadedUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoInstallDownloadedUpdates) ?? false
        self.showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        self.recentDocuments = try container.decodeIfPresent([RecentDocumentItem].self, forKey: .recentDocuments) ?? []
        self.lastUpdateCheckAt = try container.decodeIfPresent(String.self, forKey: .lastUpdateCheckAt) ?? ""
        self.lastUpdateStatus = Self.resolveLastUpdateStatus(
            try container.decodeIfPresent(String.self, forKey: .lastUpdateStatus)
        )
        self.downloadedUpdateVersion = try container.decodeIfPresent(String.self, forKey: .downloadedUpdateVersion) ?? ""
        self.downloadedUpdateName = try container.decodeIfPresent(String.self, forKey: .downloadedUpdateName) ?? ""
        self.downloadedUpdatePath = try container.decodeIfPresent(String.self, forKey: .downloadedUpdatePath) ?? ""
        self.taskHistory = try container.decodeIfPresent([PersistedNativeBackgroundTaskItem].self, forKey: .taskHistory) ?? []
        self.hasCompletedInitialLaunch = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialLaunch) ?? false
    }

    var hostRecord: NativeHostPreferencesRecord {
        NativeHostPreferencesRecord(
            languageModeRaw: AppLanguageMode.system.rawValue,
            autoUpdateEnabled: autoUpdateEnabled,
            checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
            autoDownloadUpdates: autoDownloadUpdates,
            autoInstallDownloadedUpdates: autoInstallDownloadedUpdates,
            showMenuBarIcon: showMenuBarIcon,
            recentDocuments: recentDocuments,
            lastUpdateCheckAt: lastUpdateCheckAt,
            lastUpdateStatus: lastUpdateStatus,
            downloadedUpdateVersion: downloadedUpdateVersion,
            downloadedUpdateName: downloadedUpdateName,
            downloadedUpdatePath: downloadedUpdatePath,
            taskHistory: taskHistory,
            hasCompletedInitialLaunch: hasCompletedInitialLaunch
        )
    }

    private static var defaultLastUpdateStatus: String {
        l10n("尚未检查更新。", table: "Errors", mode: .system, fallback: "No update check has run yet.")
    }

    private static func resolveLastUpdateStatus(_ status: String?) -> String {
        status ?? defaultLastUpdateStatus
    }
}
