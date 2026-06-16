import Foundation

import WordZHost
import WordZShared
struct NativeHostPreferencesSnapshot: Codable, Equatable {
    var languageMode: AppLanguageMode
    var autoUpdateEnabled: Bool
    var checkForUpdatesOnLaunch: Bool
    var autoDownloadUpdates: Bool
    var autoInstallDownloadedUpdates: Bool
    var apiAccessEnabled: Bool
    var apiRequestTimeoutSeconds: Int
    var apiMaxConcurrentRequests: Int
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
        apiAccessEnabled: true,
        apiRequestTimeoutSeconds: 10,
        apiMaxConcurrentRequests: 2,
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
        case apiAccessEnabled
        case apiRequestTimeoutSeconds
        case apiMaxConcurrentRequests
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
        apiAccessEnabled: Bool = true,
        apiRequestTimeoutSeconds: Int = 10,
        apiMaxConcurrentRequests: Int = 2,
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
        self.apiAccessEnabled = apiAccessEnabled
        self.apiRequestTimeoutSeconds = Self.clampedAPIRequestTimeoutSeconds(apiRequestTimeoutSeconds)
        self.apiMaxConcurrentRequests = Self.clampedAPIMaxConcurrentRequests(apiMaxConcurrentRequests)
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
        self.apiAccessEnabled = record.apiAccessEnabled
        self.apiRequestTimeoutSeconds = Self.clampedAPIRequestTimeoutSeconds(record.apiRequestTimeoutSeconds)
        self.apiMaxConcurrentRequests = Self.clampedAPIMaxConcurrentRequests(record.apiMaxConcurrentRequests)
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
        self.apiAccessEnabled = try container.decodeIfPresent(Bool.self, forKey: .apiAccessEnabled) ?? true
        self.apiRequestTimeoutSeconds = Self.clampedAPIRequestTimeoutSeconds(
            try container.decodeIfPresent(Int.self, forKey: .apiRequestTimeoutSeconds) ?? 10
        )
        self.apiMaxConcurrentRequests = Self.clampedAPIMaxConcurrentRequests(
            try container.decodeIfPresent(Int.self, forKey: .apiMaxConcurrentRequests) ?? 2
        )
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
            apiAccessEnabled: apiAccessEnabled,
            apiRequestTimeoutSeconds: apiRequestTimeoutSeconds,
            apiMaxConcurrentRequests: apiMaxConcurrentRequests,
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

    static func clampedAPIRequestTimeoutSeconds(_ value: Int) -> Int {
        min(max(value, 5), 60)
    }

    static func clampedAPIMaxConcurrentRequests(_ value: Int) -> Int {
        min(max(value, 1), 4)
    }
}
