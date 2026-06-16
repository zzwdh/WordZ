import Foundation

import WordZHost
import WordZShared
@MainActor
final class WorkspaceSettingsViewModel: ObservableObject {
    var onLanguageModeChange: (() -> Void)?

    @Published var languageMode: AppLanguageMode = .system {
        didSet {
            guard oldValue != languageMode else { return }
            let normalizedMode = WordZLocalization.normalizedPreferredMode(languageMode)
            guard languageMode == normalizedMode else {
                languageMode = normalizedMode
                return
            }
            WordZLocalization.shared.updatePreferredMode(normalizedMode)
            syncScene()
            onLanguageModeChange?()
        }
    }
    @Published var showWelcomeScreen: Bool = true {
        didSet {
            guard oldValue != showWelcomeScreen else { return }
            syncScene()
        }
    }
    @Published var restoreWorkspace: Bool = true {
        didSet {
            guard oldValue != restoreWorkspace else { return }
            syncScene()
        }
    }
    @Published var debugLogging: Bool = false {
        didSet {
            guard oldValue != debugLogging else { return }
            syncScene()
        }
    }
    @Published var autoUpdateEnabled: Bool = true {
        didSet {
            guard oldValue != autoUpdateEnabled else { return }
            if !autoUpdateEnabled {
                if autoInstallDownloadedUpdates {
                    autoInstallDownloadedUpdates = false
                    return
                }
                if autoDownloadUpdates {
                    autoDownloadUpdates = false
                    return
                }
            }
            syncScene()
        }
    }
    @Published var checkForUpdatesOnLaunch: Bool = true {
        didSet {
            guard oldValue != checkForUpdatesOnLaunch else { return }
            syncScene()
        }
    }
    @Published var autoDownloadUpdates: Bool = false {
        didSet {
            guard oldValue != autoDownloadUpdates else { return }
            if !autoDownloadUpdates, autoInstallDownloadedUpdates {
                autoInstallDownloadedUpdates = false
                return
            }
            if autoDownloadUpdates, !autoUpdateEnabled {
                autoUpdateEnabled = true
                return
            }
            syncScene()
        }
    }
    @Published var autoInstallDownloadedUpdates: Bool = false {
        didSet {
            guard oldValue != autoInstallDownloadedUpdates else { return }
            if autoInstallDownloadedUpdates {
                if !autoDownloadUpdates {
                    autoDownloadUpdates = true
                    return
                }
                if !autoUpdateEnabled {
                    autoUpdateEnabled = true
                    return
                }
            }
            syncScene()
        }
    }
    @Published var apiAccessEnabled: Bool = true {
        didSet {
            guard oldValue != apiAccessEnabled else { return }
            syncScene()
        }
    }
    @Published var apiRequestTimeoutSeconds: Int = NativeHostPreferencesSnapshot.default.apiRequestTimeoutSeconds {
        didSet {
            let clampedValue = NativeHostPreferencesSnapshot.clampedAPIRequestTimeoutSeconds(apiRequestTimeoutSeconds)
            guard apiRequestTimeoutSeconds == clampedValue else {
                apiRequestTimeoutSeconds = clampedValue
                return
            }
            guard oldValue != apiRequestTimeoutSeconds else { return }
            syncScene()
        }
    }
    @Published var apiMaxConcurrentRequests: Int = NativeHostPreferencesSnapshot.default.apiMaxConcurrentRequests {
        didSet {
            let clampedValue = NativeHostPreferencesSnapshot.clampedAPIMaxConcurrentRequests(apiMaxConcurrentRequests)
            guard apiMaxConcurrentRequests == clampedValue else {
                apiMaxConcurrentRequests = clampedValue
                return
            }
            guard oldValue != apiMaxConcurrentRequests else { return }
            syncScene()
        }
    }
    @Published var apiCredentialDraft: String = ""
    @Published var showMenuBarIcon: Bool = true {
        didSet {
            guard oldValue != showMenuBarIcon else { return }
            syncScene()
        }
    }
    @Published private(set) var scene = SettingsPaneSceneModel.empty

    private var context = WorkspaceSceneContext.empty
    private var recentMetadataSourceLabels: [String] = []
    private var recentCorpusSetIDs: [String] = []
    private var releaseNotes: [String] = []
    private var recentDocuments: [RecentDocumentItem] = []
    private var userDataDirectory = ""
    private var lastUpdateCheckAt = ""
    private var lastUpdateStatus = NativeHostPreferencesSnapshot.default.lastUpdateStatus
    private var apiCredentialConfigured = false
    private var apiCredentialStatus = SettingsPaneSceneModel.empty.apiCredentialStatus
    private var supportStatus = SettingsPaneSceneModel.empty.supportStatus
    private var taskCenterSummary = SettingsPaneSceneModel.empty.taskCenterSummary
    private var currentVersion = ""
    private var latestVersion = ""
    private var latestReleaseTitle = ""
    private var latestReleasePublishedAt = ""
    private var latestReleaseNotes: [String] = []
    private var latestAssetName = ""
    private var downloadedUpdateName = ""
    private var downloadedUpdatePath = ""
    private var downloadedUpdateVersion = ""
    private var isCheckingUpdates = false
    private var isDownloadingUpdate = false
    private var downloadProgress: Double?
    private var updateAvailable = false

    init() {
        WordZLocalization.shared.updatePreferredMode(languageMode)
        syncScene()
    }

    func apply(_ snapshot: UISettingsSnapshot) {
        showWelcomeScreen = snapshot.showWelcomeScreen
        restoreWorkspace = snapshot.restoreWorkspace
        debugLogging = snapshot.debugLogging
        recentMetadataSourceLabels = snapshot.recentMetadataSourceLabels
        recentCorpusSetIDs = snapshot.recentCorpusSetIDs
    }

    func applyAppInfo(_ appInfo: AppInfoSummary?) {
        currentVersion = appInfo?.version ?? ""
        releaseNotes = appInfo?.releaseNotes ?? []
        userDataDirectory = appInfo?.userDataDir ?? ""
        syncScene()
    }

    func applyHostPreferences(
        _ snapshot: NativeHostPreferencesSnapshot,
        preservingRuntimeUpdatePolicy: Bool = false
    ) {
        let resolvedSnapshot: NativeHostPreferencesSnapshot
        if preservingRuntimeUpdatePolicy {
            resolvedSnapshot = NativeHostPreferencesSnapshot(
                languageMode: .system,
                autoUpdateEnabled: autoUpdateEnabled,
                checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
                autoDownloadUpdates: autoDownloadUpdates,
                autoInstallDownloadedUpdates: autoInstallDownloadedUpdates,
                apiAccessEnabled: apiAccessEnabled,
                apiRequestTimeoutSeconds: apiRequestTimeoutSeconds,
                apiMaxConcurrentRequests: apiMaxConcurrentRequests,
                showMenuBarIcon: snapshot.showMenuBarIcon,
                recentDocuments: snapshot.recentDocuments,
                lastUpdateCheckAt: snapshot.lastUpdateCheckAt,
                lastUpdateStatus: snapshot.lastUpdateStatus,
                downloadedUpdateVersion: snapshot.downloadedUpdateVersion,
                downloadedUpdateName: snapshot.downloadedUpdateName,
                downloadedUpdatePath: snapshot.downloadedUpdatePath
            )
        } else {
            resolvedSnapshot = snapshot
        }

        languageMode = .system
        autoUpdateEnabled = resolvedSnapshot.autoUpdateEnabled
        checkForUpdatesOnLaunch = resolvedSnapshot.checkForUpdatesOnLaunch
        autoDownloadUpdates = resolvedSnapshot.autoDownloadUpdates
        autoInstallDownloadedUpdates = resolvedSnapshot.autoInstallDownloadedUpdates
        apiAccessEnabled = resolvedSnapshot.apiAccessEnabled
        apiRequestTimeoutSeconds = resolvedSnapshot.apiRequestTimeoutSeconds
        apiMaxConcurrentRequests = resolvedSnapshot.apiMaxConcurrentRequests
        showMenuBarIcon = resolvedSnapshot.showMenuBarIcon
        recentDocuments = resolvedSnapshot.recentDocuments
        lastUpdateCheckAt = resolvedSnapshot.lastUpdateCheckAt
        lastUpdateStatus = resolvedSnapshot.lastUpdateStatus
        downloadedUpdateVersion = resolvedSnapshot.downloadedUpdateVersion
        downloadedUpdateName = resolvedSnapshot.downloadedUpdateName
        downloadedUpdatePath = resolvedSnapshot.downloadedUpdatePath
        syncScene()
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func applyUpdateState(_ snapshot: NativeUpdateStateSnapshot) {
        latestVersion = snapshot.latestVersion
        updateAvailable = snapshot.updateAvailable
        if !snapshot.releaseTitle.isEmpty {
            latestReleaseTitle = snapshot.releaseTitle
        }
        if !snapshot.publishedAt.isEmpty {
            latestReleasePublishedAt = snapshot.publishedAt
        }
        if !snapshot.releaseNotes.isEmpty {
            latestReleaseNotes = snapshot.releaseNotes
        }
        if !snapshot.assetName.isEmpty {
            latestAssetName = snapshot.assetName
        }
        if !snapshot.statusMessage.isEmpty {
            lastUpdateStatus = snapshot.statusMessage
        }
        isCheckingUpdates = snapshot.isChecking
        isDownloadingUpdate = snapshot.isDownloading
        downloadProgress = snapshot.downloadProgress
        if !snapshot.downloadedUpdateName.isEmpty {
            downloadedUpdateName = snapshot.downloadedUpdateName
        }
        if !snapshot.downloadedUpdatePath.isEmpty {
            downloadedUpdatePath = snapshot.downloadedUpdatePath
        }
        if !snapshot.downloadedUpdateVersion.isEmpty {
            downloadedUpdateVersion = snapshot.downloadedUpdateVersion
        }
        syncScene()
    }

    func applyTaskCenterSummary(_ summary: String) {
        taskCenterSummary = summary
        syncScene()
    }

    func applyAPICredentialState(isConfigured: Bool, status: String? = nil) {
        apiCredentialConfigured = isConfigured
        apiCredentialStatus = status ?? (
            isConfigured
            ? wordZText("API 凭据已保存。", "API credential is saved.", mode: .system)
            : SettingsPaneSceneModel.empty.apiCredentialStatus
        )
        syncScene()
    }

    func clearAPICredentialDraft() {
        apiCredentialDraft = ""
    }

    func setAPICredentialStatus(_ status: String) {
        apiCredentialStatus = status
        syncScene()
    }

    func exportSnapshot() -> UISettingsSnapshot {
        UISettingsSnapshot(
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging,
            recentMetadataSourceLabels: recentMetadataSourceLabels,
            recentCorpusSetIDs: recentCorpusSetIDs
        )
    }

    func applyRecentMetadataSourceLabels(_ labels: [String]) {
        recentMetadataSourceLabels = MetadataSourcePresetSupport.normalizedRecentSourceLabels(labels)
    }

    func applyRecentCorpusSetIDs(_ corpusSetIDs: [String]) {
        recentCorpusSetIDs = CorpusSetRecentsSupport.normalizedRecentCorpusSetIDs(corpusSetIDs)
    }

    func exportHostPreferences() -> NativeHostPreferencesSnapshot {
        NativeHostPreferencesSnapshot(
            languageMode: .system,
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
            downloadedUpdatePath: downloadedUpdatePath
        )
    }

    func setSupportStatus(_ status: String) {
        supportStatus = status
        syncScene()
    }

    func setUpdateStatus(_ status: String, checkedAt: String) {
        lastUpdateStatus = status
        lastUpdateCheckAt = checkedAt
        syncScene()
    }

    private func syncScene() {
        let mode: AppLanguageMode = .system
        let nextScene = SettingsPaneSceneModel(
            workspaceSummary: context.workspaceSummary,
            buildSummary: context.buildSummary,
            help: context.help,
            releaseNotes: releaseNotes,
            latestReleaseNotes: latestReleaseNotes.isEmpty ? releaseNotes : latestReleaseNotes,
            recentDocuments: recentDocuments,
            userDataDirectory: userDataDirectory,
            updateSummary: makeUpdateSummary(),
            apiSummary: makeAPISummary(),
            apiCredentialStatus: apiCredentialStatus,
            apiCredentialConfigured: apiCredentialConfigured,
            apiRequestTimeoutLabel: wordZText("\(apiRequestTimeoutSeconds) 秒", "\(apiRequestTimeoutSeconds) seconds", mode: mode),
            apiMaxConcurrentRequestsLabel: "\(apiMaxConcurrentRequests)",
            supportStatus: supportStatus,
            latestVersionLabel: latestVersion.isEmpty ? currentVersion : latestVersion,
            latestReleaseTitle: latestReleaseTitle.isEmpty ? (latestVersion.isEmpty ? currentVersion : latestVersion) : latestReleaseTitle,
            latestReleasePublishedLabel: formattedPublishedAtLabel(),
            latestAssetName: latestAssetName,
            downloadedUpdateName: downloadedUpdateName,
            downloadedUpdatePath: downloadedUpdatePath,
            taskCenterSummary: taskCenterSummary,
            canDownloadUpdate: updateAvailable && !latestAssetName.isEmpty && downloadedUpdatePath.isEmpty && !isDownloadingUpdate,
            canInstallDownloadedUpdate: !downloadedUpdatePath.isEmpty,
            isCheckingUpdates: isCheckingUpdates,
            isDownloadingUpdate: isDownloadingUpdate,
            downloadProgressLabel: downloadProgress.map {
                wordZText("下载进度 \(Int(($0 * 100).rounded()))%", "Download \(Int(($0 * 100).rounded()))%", mode: mode)
            } ?? ""
        )
        guard nextScene != scene else { return }
        scene = nextScene
    }

    private func makeUpdateSummary() -> String {
        let mode: AppLanguageMode = .system
        let policy = autoUpdateEnabled
            ? (
                autoInstallDownloadedUpdates
                ? wordZText(
                    "自动更新已开启，后台下载和安装重启流程已启用。",
                    "Automatic updates are enabled, and download/install restart handoff is on.",
                    mode: mode
                )
                : (
                    autoDownloadUpdates
                    ? wordZText(
                        "自动更新已开启，后台下载已启用，安装前会先询问。",
                        "Automatic updates are enabled, background downloads are on, and install still asks first.",
                        mode: mode
                    )
                    : wordZText("自动更新已开启，后台下载已关闭。", "Automatic updates are enabled, and background downloads are off.", mode: mode)
                )
            )
            : wordZText("自动更新已关闭。", "Automatic updates are disabled.", mode: mode)
        let launchCheck = checkForUpdatesOnLaunch
            ? wordZText("启动时将检查更新。", "Updates will be checked on launch.", mode: mode)
            : wordZText("启动时不检查更新。", "Updates will not be checked on launch.", mode: mode)
        let downloadLine: String
        if isDownloadingUpdate {
            downloadLine = downloadProgress.map {
                wordZText("正在下载更新：\(Int(($0 * 100).rounded()))%", "Downloading update: \(Int(($0 * 100).rounded()))%", mode: mode)
            } ?? wordZText("正在下载更新…", "Downloading update…", mode: mode)
        } else if !downloadedUpdateName.isEmpty {
            downloadLine = wordZText("已下载更新：\(downloadedUpdateName)", "Downloaded update: \(downloadedUpdateName)", mode: mode)
        } else {
            downloadLine = lastUpdateStatus
        }
        if lastUpdateCheckAt.isEmpty {
            return "\(policy)\n\(launchCheck)\n\(downloadLine)"
        }
        return "\(policy)\n\(launchCheck)\n\(wordZText("上次检查", "Last checked", mode: mode))：\(lastUpdateCheckAt)\n\(downloadLine)"
    }

    private func makeAPISummary() -> String {
        let mode: AppLanguageMode = .system
        if apiAccessEnabled {
            let policy = wordZText(
                "请求超时 \(apiRequestTimeoutSeconds) 秒，并发上限 \(apiMaxConcurrentRequests)。",
                "Request timeout \(apiRequestTimeoutSeconds)s, max concurrency \(apiMaxConcurrentRequests).",
                mode: mode
            )
            let accessLine = wordZText(
                "联网 API 已开启。WordZ 仍会优先使用本地分析，只有更新检查或你手动触发的 API 动作会联网。",
                "Network API access is on. WordZ still uses local analysis first; only update checks or API actions you trigger will use the network.",
                mode: mode
            )
            return "\(accessLine)\n\(policy)"
        }
        return wordZText(
            "联网 API 已关闭。本地语料分析不受影响，检查更新和 API 动作会暂停。",
            "Network API access is off. Local corpus analysis still works; update checks and API actions are paused.",
            mode: mode
        )
    }

    private func formattedPublishedAtLabel() -> String {
        guard !latestReleasePublishedAt.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: latestReleasePublishedAt) else {
            return latestReleasePublishedAt
        }
        return WordZLocalization.localizedDateTimeString(from: date, mode: .system)
    }
}
