import Foundation

package struct NativeHostPreferencesRecord: Codable, Equatable {
    package var languageModeRaw: String
    package var autoUpdateEnabled: Bool
    package var checkForUpdatesOnLaunch: Bool
    package var autoDownloadUpdates: Bool
    package var autoInstallDownloadedUpdates: Bool
    package var showMenuBarIcon: Bool
    package var recentDocuments: [RecentDocumentItem]
    package var lastUpdateCheckAt: String
    package var lastUpdateStatus: String?
    package var downloadedUpdateVersion: String
    package var downloadedUpdateName: String
    package var downloadedUpdatePath: String
    package var taskHistory: [PersistedNativeBackgroundTaskItem]
    package var hasCompletedInitialLaunch: Bool

    package static let `default` = NativeHostPreferencesRecord(
        languageModeRaw: "system",
        autoUpdateEnabled: true,
        checkForUpdatesOnLaunch: true,
        autoDownloadUpdates: false,
        autoInstallDownloadedUpdates: false,
        showMenuBarIcon: true,
        recentDocuments: [],
        lastUpdateCheckAt: "",
        lastUpdateStatus: nil,
        downloadedUpdateVersion: "",
        downloadedUpdateName: "",
        downloadedUpdatePath: "",
        taskHistory: [],
        hasCompletedInitialLaunch: false
    )

    private enum CodingKeys: String, CodingKey {
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

    package init(
        languageModeRaw: String = "system",
        autoUpdateEnabled: Bool,
        checkForUpdatesOnLaunch: Bool,
        autoDownloadUpdates: Bool,
        autoInstallDownloadedUpdates: Bool,
        showMenuBarIcon: Bool = true,
        recentDocuments: [RecentDocumentItem],
        lastUpdateCheckAt: String,
        lastUpdateStatus: String?,
        downloadedUpdateVersion: String,
        downloadedUpdateName: String,
        downloadedUpdatePath: String,
        taskHistory: [PersistedNativeBackgroundTaskItem] = [],
        hasCompletedInitialLaunch: Bool = false
    ) {
        self.languageModeRaw = languageModeRaw.isEmpty ? "system" : languageModeRaw
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

    package init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            languageModeRaw: try container.decodeIfPresent(String.self, forKey: .languageMode) ?? "system",
            autoUpdateEnabled: try container.decodeIfPresent(Bool.self, forKey: .autoUpdateEnabled) ?? true,
            checkForUpdatesOnLaunch: try container.decodeIfPresent(Bool.self, forKey: .checkForUpdatesOnLaunch) ?? true,
            autoDownloadUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoDownloadUpdates) ?? false,
            autoInstallDownloadedUpdates: try container.decodeIfPresent(Bool.self, forKey: .autoInstallDownloadedUpdates) ?? false,
            showMenuBarIcon: try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true,
            recentDocuments: try container.decodeIfPresent([RecentDocumentItem].self, forKey: .recentDocuments) ?? [],
            lastUpdateCheckAt: try container.decodeIfPresent(String.self, forKey: .lastUpdateCheckAt) ?? "",
            lastUpdateStatus: try container.decodeIfPresent(String.self, forKey: .lastUpdateStatus),
            downloadedUpdateVersion: try container.decodeIfPresent(String.self, forKey: .downloadedUpdateVersion) ?? "",
            downloadedUpdateName: try container.decodeIfPresent(String.self, forKey: .downloadedUpdateName) ?? "",
            downloadedUpdatePath: try container.decodeIfPresent(String.self, forKey: .downloadedUpdatePath) ?? "",
            taskHistory: try container.decodeIfPresent([PersistedNativeBackgroundTaskItem].self, forKey: .taskHistory) ?? [],
            hasCompletedInitialLaunch: try container.decodeIfPresent(Bool.self, forKey: .hasCompletedInitialLaunch) ?? false
        )
    }

    package func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(languageModeRaw, forKey: .languageMode)
        try container.encode(autoUpdateEnabled, forKey: .autoUpdateEnabled)
        try container.encode(checkForUpdatesOnLaunch, forKey: .checkForUpdatesOnLaunch)
        try container.encode(autoDownloadUpdates, forKey: .autoDownloadUpdates)
        try container.encode(autoInstallDownloadedUpdates, forKey: .autoInstallDownloadedUpdates)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(recentDocuments, forKey: .recentDocuments)
        try container.encode(lastUpdateCheckAt, forKey: .lastUpdateCheckAt)
        try container.encodeIfPresent(lastUpdateStatus, forKey: .lastUpdateStatus)
        try container.encode(downloadedUpdateVersion, forKey: .downloadedUpdateVersion)
        try container.encode(downloadedUpdateName, forKey: .downloadedUpdateName)
        try container.encode(downloadedUpdatePath, forKey: .downloadedUpdatePath)
        try container.encode(taskHistory, forKey: .taskHistory)
        try container.encode(hasCompletedInitialLaunch, forKey: .hasCompletedInitialLaunch)
    }
}
