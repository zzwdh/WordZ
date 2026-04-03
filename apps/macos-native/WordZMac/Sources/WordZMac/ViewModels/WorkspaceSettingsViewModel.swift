import Foundation

@MainActor
final class WorkspaceSettingsViewModel: ObservableObject {
    var onLanguageModeChange: (() -> Void)?

    @Published var languageMode: AppLanguageMode = .system {
        didSet {
            WordZLocalization.shared.updatePreferredMode(languageMode)
            syncScene()
            onLanguageModeChange?()
        }
    }
    @Published var showWelcomeScreen: Bool = true {
        didSet { syncScene() }
    }
    @Published var restoreWorkspace: Bool = true {
        didSet { syncScene() }
    }
    @Published var debugLogging: Bool = false {
        didSet { syncScene() }
    }
    @Published var autoUpdateEnabled: Bool = true {
        didSet { syncScene() }
    }
    @Published var checkForUpdatesOnLaunch: Bool = true {
        didSet { syncScene() }
    }
    @Published var autoDownloadUpdates: Bool = false {
        didSet { syncScene() }
    }
    @Published private(set) var scene = SettingsPaneSceneModel.empty

    private var context = WorkspaceSceneContext.empty
    private var releaseNotes: [String] = []
    private var recentDocuments: [RecentDocumentItem] = []
    private var userDataDirectory = ""
    private var lastUpdateCheckAt = ""
    private var lastUpdateStatus = NativeHostPreferencesSnapshot.default.lastUpdateStatus
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
    }

    func applyAppInfo(_ appInfo: AppInfoSummary?) {
        currentVersion = appInfo?.version ?? ""
        releaseNotes = appInfo?.releaseNotes ?? []
        userDataDirectory = appInfo?.userDataDir ?? ""
        syncScene()
    }

    func applyHostPreferences(_ snapshot: NativeHostPreferencesSnapshot) {
        languageMode = snapshot.languageMode
        autoUpdateEnabled = snapshot.autoUpdateEnabled
        checkForUpdatesOnLaunch = snapshot.checkForUpdatesOnLaunch
        autoDownloadUpdates = snapshot.autoDownloadUpdates
        recentDocuments = snapshot.recentDocuments
        lastUpdateCheckAt = snapshot.lastUpdateCheckAt
        lastUpdateStatus = snapshot.lastUpdateStatus
        downloadedUpdateVersion = snapshot.downloadedUpdateVersion
        downloadedUpdateName = snapshot.downloadedUpdateName
        downloadedUpdatePath = snapshot.downloadedUpdatePath
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

    func exportSnapshot() -> UISettingsSnapshot {
        UISettingsSnapshot(
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging
        )
    }

    func exportHostPreferences() -> NativeHostPreferencesSnapshot {
        NativeHostPreferencesSnapshot(
            languageMode: languageMode,
            autoUpdateEnabled: autoUpdateEnabled,
            checkForUpdatesOnLaunch: checkForUpdatesOnLaunch,
            autoDownloadUpdates: autoDownloadUpdates,
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
        let mode = languageMode
        scene = SettingsPaneSceneModel(
            workspaceSummary: context.workspaceSummary,
            buildSummary: context.buildSummary,
            help: context.help,
            releaseNotes: releaseNotes,
            latestReleaseNotes: latestReleaseNotes.isEmpty ? releaseNotes : latestReleaseNotes,
            recentDocuments: recentDocuments,
            userDataDirectory: userDataDirectory,
            updateSummary: makeUpdateSummary(),
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
    }

    private func makeUpdateSummary() -> String {
        let mode = languageMode
        let policy = autoUpdateEnabled
            ? (
                autoDownloadUpdates
                ? wordZText("自动更新已开启，后台下载已启用。", "Automatic updates are enabled, and background downloads are on.", mode: mode)
                : wordZText("自动更新已开启，后台下载已关闭。", "Automatic updates are enabled, and background downloads are off.", mode: mode)
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

    private func formattedPublishedAtLabel() -> String {
        guard !latestReleasePublishedAt.isEmpty else { return "" }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: latestReleasePublishedAt) else {
            return latestReleasePublishedAt
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
