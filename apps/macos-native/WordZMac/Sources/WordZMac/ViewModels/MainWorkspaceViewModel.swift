import AppKit
import Foundation
import SwiftUI

enum SceneSyncSource {
    case full
    case navigation
    case librarySelection
    case resultContent
    case settings
}

@MainActor
final class MainWorkspaceViewModel: ObservableObject {
    @Published var sidebar: LibrarySidebarViewModel
    @Published var shell: WorkspaceShellViewModel
    @Published var library: LibraryManagementViewModel
    @Published var stats: StatsPageViewModel
    @Published var word: WordPageViewModel
    @Published var tokenize: TokenizePageViewModel
    @Published var topics: TopicsPageViewModel
    @Published var compare: ComparePageViewModel
    @Published var chiSquare: ChiSquarePageViewModel
    @Published var ngram: NgramPageViewModel
    @Published var wordCloud: WordCloudPageViewModel
    @Published var kwic: KWICPageViewModel
    @Published var collocate: CollocatePageViewModel
    @Published var locator: LocatorPageViewModel
    @Published var settings: WorkspaceSettingsViewModel
    @Published private(set) var sceneGraph = WorkspaceSceneGraph.empty
    @Published private(set) var rootScene = RootContentSceneModel.empty
    @Published var isWelcomePresented = false
    @Published private(set) var activeIssue: WorkspaceIssueBanner?

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }
    @Published private(set) var welcomeScene = WelcomeSceneModel.empty
    let taskCenter: NativeTaskCenter

    private let sceneStore: WorkspaceSceneStore
    private let sceneGraphStore: WorkspaceSceneGraphStore
    private let rootSceneBuilder: RootContentSceneBuilder
    private let flowCoordinator: WorkspaceFlowCoordinator
    private let appCoordinator: AppCoordinator
    private let sessionStore: WorkspaceSessionStore
    private let hostPreferencesStore: any NativeHostPreferencesStoring
    private let hostActionService: any NativeHostActionServicing
    private let quickLookPreviewFileService: QuickLookPreviewFileService
    private let updateService: any NativeUpdateServicing
    private let notificationService: any NativeNotificationServicing
    private var initialized = false
    private var inputChangeSyncTask: Task<Void, Never>?
    private var updateState = NativeUpdateStateSnapshot.empty
    private var isRunningUpdateCheck = false
    private var isRunningUpdateDownload = false
    private var lastPersistedTaskHistory: [PersistedNativeBackgroundTaskItem] = []

    private enum CurrentContentTarget {
        case file(String)
        case tableSnapshot(NativeTableExportSnapshot)
        case textDocument(PlainTextExportDocument)
    }

    init(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService = WorkspacePersistenceService(),
        workspacePresentation: WorkspacePresentationService = WorkspacePresentationService(),
        sceneStore: WorkspaceSceneStore = WorkspaceSceneStore(),
        sceneGraphStore: WorkspaceSceneGraphStore = WorkspaceSceneGraphStore(),
        rootSceneBuilder: RootContentSceneBuilder = RootContentSceneBuilder(),
        windowDocumentController: NativeWindowDocumentController = NativeWindowDocumentController(),
        dialogService: NativeDialogServicing = NativeSheetDialogService(),
        hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
        hostActionService: (any NativeHostActionServicing)? = nil,
        quickLookPreviewFileService: QuickLookPreviewFileService = QuickLookPreviewFileService(),
        updateService: (any NativeUpdateServicing)? = nil,
        notificationService: (any NativeNotificationServicing)? = nil,
        taskCenter: NativeTaskCenter = NativeTaskCenter(),
        sessionStore: WorkspaceSessionStore = WorkspaceSessionStore(),
        libraryCoordinator: LibraryCoordinator? = nil,
        sidebar: LibrarySidebarViewModel = LibrarySidebarViewModel(),
        shell: WorkspaceShellViewModel = WorkspaceShellViewModel(),
        library: LibraryManagementViewModel = LibraryManagementViewModel(),
        stats: StatsPageViewModel = StatsPageViewModel(),
        word: WordPageViewModel = WordPageViewModel(),
        tokenize: TokenizePageViewModel = TokenizePageViewModel(),
        topics: TopicsPageViewModel = TopicsPageViewModel(),
        compare: ComparePageViewModel = ComparePageViewModel(),
        chiSquare: ChiSquarePageViewModel = ChiSquarePageViewModel(),
        ngram: NgramPageViewModel = NgramPageViewModel(),
        wordCloud: WordCloudPageViewModel = WordCloudPageViewModel(),
        kwic: KWICPageViewModel = KWICPageViewModel(),
        collocate: CollocatePageViewModel = CollocatePageViewModel(),
        locator: LocatorPageViewModel = LocatorPageViewModel(),
        settings: WorkspaceSettingsViewModel = WorkspaceSettingsViewModel()
    ) {
        self.sceneStore = sceneStore
        self.sceneGraphStore = sceneGraphStore
        self.rootSceneBuilder = rootSceneBuilder
        self.sessionStore = sessionStore
        self.hostPreferencesStore = hostPreferencesStore
        self.hostActionService = hostActionService ?? NativeHostActionService(dialogService: dialogService)
        self.quickLookPreviewFileService = quickLookPreviewFileService
        self.updateService = updateService ?? GitHubReleaseUpdateService()
        self.notificationService = notificationService ?? {
            if !NativeNotificationEnvironment.supportsUserNotifications {
                return NoOpNotificationService()
            }
            return NativeNotificationService()
        }()
        self.taskCenter = taskCenter
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.stats = stats
        self.word = word
        self.tokenize = tokenize
        self.topics = topics
        self.compare = compare
        self.chiSquare = chiSquare
        self.ngram = ngram
        self.wordCloud = wordCloud
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
        self.settings = settings

        let resolvedLibraryCoordinator = libraryCoordinator ?? LibraryCoordinator(
            repository: repository,
            sessionStore: sessionStore
        )
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: workspacePersistence,
            workspacePresentation: workspacePresentation,
            sceneStore: sceneStore,
            windowDocumentController: windowDocumentController,
            dialogService: dialogService,
            hostActionService: self.hostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            libraryCoordinator: resolvedLibraryCoordinator,
            taskCenter: taskCenter
        )
        self.flowCoordinator = flowCoordinator
        self.appCoordinator = AppCoordinator(
            repository: repository,
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: flowCoordinator,
            hostPreferencesStore: hostPreferencesStore
        )
        self.settings.onLanguageModeChange = { [weak self] in
            self?.syncSceneGraph()
        }

        let initialHostPreferences = hostPreferencesStore.load()
        settings.applyHostPreferences(initialHostPreferences)
        lastPersistedTaskHistory = initialHostPreferences.taskHistory
        updateState = NativeUpdateStateSnapshot(
            currentVersion: "",
            latestVersion: "",
            releaseURL: "",
            statusMessage: initialHostPreferences.lastUpdateStatus,
            updateAvailable: false,
            isChecking: false,
            isDownloading: false,
            downloadProgress: nil,
            downloadedUpdateVersion: initialHostPreferences.downloadedUpdateVersion,
            downloadedUpdateName: initialHostPreferences.downloadedUpdateName,
            downloadedUpdatePath: initialHostPreferences.downloadedUpdatePath,
            releaseTitle: "",
            publishedAt: "",
            releaseNotes: [],
            assetName: ""
        )
        settings.applyUpdateState(updateState)
        taskCenter.restoreHistory(initialHostPreferences.taskHistory)
        settings.applyTaskCenterSummary(taskCenter.scene.summary)
        taskCenter.onSceneChange = { [weak self] scene in
            self?.settings.applyTaskCenterSummary(scene.summary)
        }
        taskCenter.onHistoryChange = { [weak self] history in
            self?.persistTaskHistory(history)
        }

        self.sidebar.onSelectionChange = { [weak self] in
            guard let self else { return }
            self.flowCoordinator.handleCorpusSelectionChange(features: self.features)
            self.syncSceneGraph(source: .librarySelection)
        }
        self.shell.onTabChange = { [weak self] in
            guard let self else { return }
            self.flowCoordinator.markWorkspaceEdited(features: self.features)
            self.syncSceneGraph(source: .navigation)
        }
        self.compare.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.kwic.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.ngram.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.word.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.tokenize.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.topics.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.collocate.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.wordCloud.onInputChange = { [weak self] in
            self?.scheduleInputStateSync()
        }
        self.library.syncSidebarSelection(self.sidebar.selectedCorpusID)
        syncSceneGraph()
    }

    var selectedTab: WorkspaceDetailTab {
        get { shell.selectedTab.mainWorkspaceTab }
        set { shell.selectedTab = newValue.mainWorkspaceTab }
    }

    var windowTitle: String { sceneStore.context.appName }
    var canRestoreWorkspace: Bool { sessionStore.workspaceSnapshot != nil }
    var canQuickLookCurrentCorpus: Bool { currentContentTarget != nil }
    var canShareCurrentContent: Bool { currentContentTarget != nil }
    var issueBanner: WorkspaceIssueBanner? {
        if sidebar.scene.engineState == .failed {
            return WorkspaceIssueBanner(
                tone: .error,
                title: t("本地引擎启动失败", "Local Engine Startup Failed"),
                message: sidebar.scene.errorMessage.isEmpty ? sidebar.scene.engineStatus : sidebar.scene.errorMessage,
                recoveryAction: .refreshWorkspace
            )
        }
        if !sidebar.scene.errorMessage.isEmpty {
            return WorkspaceIssueBanner(
                tone: .warning,
                title: t("当前工作区需要处理", "Workspace Attention Needed"),
                message: sidebar.scene.errorMessage,
                recoveryAction: .refreshWorkspace
            )
        }
        return activeIssue
    }

    private var features: WorkspaceFeatureSet {
        WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: shell,
            library: library,
            stats: stats,
            word: word,
            tokenize: tokenize,
            topics: topics,
            compare: compare,
            chiSquare: chiSquare,
            ngram: ngram,
            wordCloud: wordCloud,
            kwic: kwic,
            collocate: collocate,
            locator: locator,
            settings: settings
        )
    }

    func attachWindow(_ window: NSWindow?) {
        flowCoordinator.attachWindow(window, features: features)
    }

    func initializeIfNeeded() async {
        guard !initialized else { return }
        cancelPendingInputStateSync()
        initialized = true
        await appCoordinator.refreshAll(features: features)
        syncSceneGraph()
        showWelcomeIfNeeded()
        scheduleLaunchUpdateCheckIfNeeded()
    }

    func refreshAll() async {
        cancelPendingInputStateSync()
        await appCoordinator.refreshAll(features: features)
        syncSceneGraph()
        showWelcomeIfNeeded()
        scheduleLaunchUpdateCheckIfNeeded()
    }

    func openSelectedCorpus() async {
        cancelPendingInputStateSync()
        await flowCoordinator.openSelectedCorpus(features: features)
        syncSceneGraph(source: .librarySelection)
    }

    func runStats() async {
        await flowCoordinator.runStats(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runWord() async {
        await flowCoordinator.runWord(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runTokenize() async {
        await flowCoordinator.runTokenize(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runTopics() async {
        await flowCoordinator.runTopics(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runCompare() async {
        await flowCoordinator.runCompare(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runChiSquare() async {
        await flowCoordinator.runChiSquare(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runKWIC() async {
        await flowCoordinator.runKWIC(features: features)
        syncLocatorSourceFromKWIC()
        syncSceneGraph(source: .resultContent)
    }

    func runNgram() async {
        await flowCoordinator.runNgram(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runWordCloud() async {
        await flowCoordinator.runWordCloud(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runCollocate() async {
        await flowCoordinator.runCollocate(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func runLocator() async {
        await flowCoordinator.runLocator(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func saveSettings() async {
        await flowCoordinator.saveSettings(features: features)
        syncSceneGraph(source: .settings)
    }

    func showLibrary() {
        if shell.selectedTab == .library {
            shell.selectedTab = .stats
            syncSceneGraph(source: .navigation)
        }
    }

    func showSettings() {
        if shell.selectedTab == .settings {
            shell.selectedTab = .stats
            syncSceneGraph(source: .navigation)
        }
    }

    func presentWelcome() {
        isWelcomePresented = true
    }

    func dismissWelcome() {
        isWelcomePresented = false
    }

    func newWorkspace() async {
        cancelPendingInputStateSync()
        await flowCoordinator.newWorkspace(features: features)
        syncSceneGraph(source: .full)
        clearActiveIssue()
    }

    func restoreSavedWorkspace() async {
        cancelPendingInputStateSync()
        await flowCoordinator.restoreSavedWorkspace(features: features)
        syncSceneGraph(source: .full)
        clearActiveIssue()
    }

    func openRecentDocument(_ corpusID: String) async {
        cancelPendingInputStateSync()
        guard sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            let message = t("最近打开记录对应的语料已不存在。", "The corpus referenced by this recent item no longer exists.")
            settings.setSupportStatus(message)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("无法重新打开最近项目", "Unable to Reopen Recent Item"),
                message: message,
                recoveryAction: .refreshWorkspace
            )
            return
        }
        sidebar.selectedCorpusID = corpusID
        syncSceneGraph(source: .librarySelection)
        await openSelectedCorpus()
        isWelcomePresented = false
        clearActiveIssue()
    }

    func handleExternalPaths(_ paths: [String]) async {
        guard !paths.isEmpty else { return }
        cancelPendingInputStateSync()
        await flowCoordinator.importExternalPaths(paths, features: features)
        syncSceneGraph(source: .full)
        isWelcomePresented = false
        clearActiveIssue()
    }

    func importCorpusFromDialog() async {
        cancelPendingInputStateSync()
        await flowCoordinator.importCorpusFromDialog(features: features)
        syncSceneGraph(source: .full)
        isWelcomePresented = false
        clearActiveIssue()
    }

    func openUserDataDirectory() async {
        guard !settings.scene.userDataDirectory.isEmpty else {
            settings.setSupportStatus(t("当前没有可用的用户数据目录。", "No user data directory is available right now."))
            return
        }
        do {
            try await hostActionService.openUserDataDirectory(path: settings.scene.userDataDirectory)
            settings.setSupportStatus(t("已在 Finder 中打开用户数据目录。", "Opened the user data directory in Finder."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开用户数据目录", titleEn: "Unable to Open User Data Directory")
        }
    }

    func openFeedback() async {
        do {
            try await hostActionService.openFeedback()
            settings.setSupportStatus(t("已打开反馈页。", "Opened the feedback page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开反馈入口", titleEn: "Unable to Open Feedback")
        }
    }

    func openProjectHome() async {
        do {
            try await hostActionService.openProjectHome()
            settings.setSupportStatus(t("已打开项目主页。", "Opened the project home page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开项目主页", titleEn: "Unable to Open Project Home")
        }
    }

    func quickLookCurrentCorpus() async {
        guard let target = currentContentTarget else {
            presentQuickLookUnavailableIssue()
            return
        }
        do {
            try await hostActionService.quickLook(path: try preparedPath(for: target))
            settings.setSupportStatus(t("已打开当前内容的 Quick Look 预览。", "Opened Quick Look for the current content."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开 Quick Look 预览", titleEn: "Unable to Open Quick Look")
        }
    }

    func quickLookSelectedCorpus() async {
        guard let path = selectedCorpusPreviewablePath else {
            presentQuickLookUnavailableIssue()
            return
        }
        do {
            try await hostActionService.quickLook(path: path)
            settings.setSupportStatus(t("已打开所选语料的 Quick Look 预览。", "Opened Quick Look for the selected corpus."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开 Quick Look 预览", titleEn: "Unable to Open Quick Look")
        }
    }

    func shareCurrentContent() async {
        guard let target = currentContentTarget else {
            presentShareUnavailableIssue()
            return
        }
        do {
            try await hostActionService.share(paths: [try preparedPath(for: target)])
            settings.setSupportStatus(t("已打开当前内容的系统分享菜单。", "Opened the system share menu for the current content."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开系统分享菜单", titleEn: "Unable to Open Share Menu")
        }
    }

    func openReleaseNotes() async {
        do {
            try await hostActionService.openReleaseNotes()
            settings.setSupportStatus(t("已打开版本说明页。", "Opened the release notes page."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开版本说明", titleEn: "Unable to Open Release Notes")
        }
    }

    func checkForUpdatesNow() async {
        await checkForUpdates(silent: false)
    }

    func downloadLatestUpdate() async {
        guard updateState.canDownloadUpdate, !isRunningUpdateCheck, !isRunningUpdateDownload else { return }
        await performUpdateDownload(using: nil)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    func installDownloadedUpdate() async {
        guard !updateState.downloadedUpdatePath.isEmpty else {
            let status = t("当前没有可安装的已下载更新。", "There is no downloaded update ready to install.")
            settings.setSupportStatus(status)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("没有可安装的更新", "No Downloaded Update"),
                message: status,
                recoveryAction: .checkForUpdates
            )
            return
        }
        do {
            try await hostActionService.openDownloadedUpdate(path: updateState.downloadedUpdatePath)
            settings.setSupportStatus(t("已打开已下载更新，按系统安装流程继续即可。", "Opened the downloaded update. Continue with the system installer flow."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法打开已下载更新", titleEn: "Unable to Open Downloaded Update")
        }
    }

    func revealDownloadedUpdate() async {
        guard !updateState.downloadedUpdatePath.isEmpty else {
            let status = t("当前没有可显示的已下载更新。", "There is no downloaded update to reveal.")
            settings.setSupportStatus(status)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("没有可显示的更新包", "No Downloaded Installer"),
                message: status,
                recoveryAction: .checkForUpdates
            )
            return
        }
        do {
            try await hostActionService.revealDownloadedUpdate(path: updateState.downloadedUpdatePath)
            settings.setSupportStatus(t("已在 Finder 中显示下载的更新包。", "Revealed the downloaded installer in Finder."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "无法显示已下载更新", titleEn: "Unable to Reveal Downloaded Update")
        }
    }

    func clearRecentDocuments() async {
        do {
            let snapshot = try hostPreferencesStore.clearRecentDocuments()
            try await hostActionService.clearRecentDocuments()
            settings.applyHostPreferences(snapshot)
            settings.setSupportStatus(t("最近打开列表已清空。", "Recent documents have been cleared."))
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "清理最近打开失败", titleEn: "Failed to Clear Recent Items")
        }
        syncSceneGraph(source: .settings)
    }

    func exportDiagnostics() async {
        let taskID = taskCenter.beginTask(title: t("导出诊断", "Export Diagnostics"), detail: t("正在生成诊断报告…", "Generating diagnostics report…"))
        do {
            let path = try await hostActionService.exportDiagnostics(
                report: buildDiagnosticsReport(),
                suggestedName: "WordZMac-diagnostics-\(diagnosticTimestamp()).txt"
            )
            if let path {
                settings.setSupportStatus("\(t("已导出诊断到", "Exported diagnostics to")) \(path)")
                taskCenter.completeTask(id: taskID, detail: "\(t("诊断已导出到", "Diagnostics exported to")) \(path)", action: .openFile(path: path))
                await notificationService.notify(
                    title: t("WordZ 诊断已导出", "WordZ Diagnostics Exported"),
                    subtitle: t("可直接打开生成文件", "The generated file is ready to open"),
                    body: path
                )
                clearActiveIssue()
            } else {
                taskCenter.completeTask(id: taskID, detail: t("已取消导出诊断。", "Diagnostics export cancelled."))
            }
        } catch {
            presentIssue(
                error,
                titleZh: "导出诊断失败",
                titleEn: "Diagnostics Export Failed",
                recoveryAction: .exportDiagnostics
            )
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
        }
    }

    func clearFinishedTasks() {
        taskCenter.clearFinished()
    }

    func updateFrequencyMetricDefinition(_ definition: FrequencyMetricDefinition) {
        stats.applyFrequencyMetricDefinition(definition)
        word.applyFrequencyMetricDefinition(definition)
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func performTaskAction(_ action: NativeBackgroundTaskAction) async {
        do {
            switch action {
            case .cancelTask(let id):
                taskCenter.cancelTask(id: id)
            case .openFile(let path), .installDownloadedUpdate(let path):
                try await hostActionService.openDownloadedUpdate(path: path)
            case .openURL(let urlString):
                if urlString.contains("/releases") {
                    try await hostActionService.openReleaseNotes()
                } else if urlString.contains("/issues") {
                    try await hostActionService.openFeedback()
                } else {
                    try await hostActionService.openProjectHome()
                }
            }
            clearActiveIssue()
        } catch {
            presentIssue(error, titleZh: "执行后台任务失败", titleEn: "Background Task Failed")
        }
    }

    func refreshLibraryManagement() async {
        await flowCoordinator.refreshLibraryManagement(features: features)
        syncSceneGraph()
    }

    func handleLibraryAction(_ action: LibraryManagementAction) async {
        await flowCoordinator.handleLibraryAction(action, features: features)
        syncSceneGraph(source: .full)
    }

    func exportCurrent() async {
        await flowCoordinator.exportCurrent(features: features)
        syncSceneGraph(source: .resultContent)
    }

    func exportTokenizedText() async {
        guard let document = tokenize.exportDocument else { return }
        await flowCoordinator.exportTextDocument(
            document,
            title: t("导出分词结果", "Export Tokenized Text"),
            successStatus: t("已导出分词结果。", "Exported tokenized text."),
            features: features
        )
        syncSceneGraph(source: .resultContent)
    }

    func exportTopicsSummary() async {
        guard let snapshot = topics.exportSummarySnapshot else { return }
        await flowCoordinator.exportSnapshot(
            snapshot,
            title: t("导出主题摘要", "Export Topics Summary"),
            successStatus: t("已导出主题摘要。", "Exported topics summary."),
            features: features
        )
        syncSceneGraph(source: .resultContent)
    }

    func exportTopicsSegments() async {
        guard let snapshot = topics.exportSegmentsSnapshot else { return }
        await flowCoordinator.exportSnapshot(
            snapshot,
            title: t("导出主题片段", "Export Topic Segments"),
            successStatus: t("已导出主题片段。", "Exported topic segments."),
            features: features
        )
        syncSceneGraph(source: .resultContent)
    }

    func shutdown() async {
        cancelPendingInputStateSync()
        await appCoordinator.shutdown()
    }

    func syncSceneGraph(source: SceneSyncSource = .full) {
        switch source {
        case .full:
            compare.syncLibrarySnapshot(sidebar.librarySnapshot)
            library.syncSidebarSelection(sidebar.selectedCorpusID)
            refreshShellAvailability()
            sceneGraphStore.sync(
                context: sceneStore.context,
                sidebar: sidebar.scene,
                shell: shell.scene,
                library: library.scene,
                settings: settings.scene,
                activeTab: selectedTab,
                word: word.scene,
                tokenize: tokenize.scene,
                wordCloud: wordCloud.scene,
                stats: stats.scene,
                topics: topics.scene,
                compare: compare.scene,
                chiSquare: chiSquare.scene,
                ngram: ngram.scene,
                kwic: kwic.scene,
                collocate: collocate.scene,
                locator: locator.scene
            )
            applySyncedGraph(rebuildRootScene: true, rebuildWelcomeScene: true)
        case .navigation:
            refreshShellAvailability()
            sceneGraphStore.syncShellNavigation(shell: shell.scene, activeTab: selectedTab)
            applySyncedGraph(rebuildRootScene: true, rebuildWelcomeScene: false)
        case .librarySelection:
            compare.syncLibrarySnapshot(sidebar.librarySnapshot)
            library.syncSidebarSelection(sidebar.selectedCorpusID)
            refreshShellAvailability()
            sceneGraphStore.syncSidebarAndLibrary(
                sidebar: sidebar.scene,
                library: library.scene,
                shell: shell.scene,
                activeTab: selectedTab
            )
            applySyncedGraph(rebuildRootScene: true, rebuildWelcomeScene: false)
        case .resultContent:
            refreshShellAvailability()
            sceneGraphStore.syncResults(
                shell: shell.scene,
                activeTab: selectedTab,
                word: word.scene,
                tokenize: tokenize.scene,
                wordCloud: wordCloud.scene,
                stats: stats.scene,
                topics: topics.scene,
                compare: compare.scene,
                chiSquare: chiSquare.scene,
                ngram: ngram.scene,
                kwic: kwic.scene,
                collocate: collocate.scene,
                locator: locator.scene
            )
            applySyncedGraph(rebuildRootScene: true, rebuildWelcomeScene: false)
        case .settings:
            sceneGraphStore.syncSettings(settings.scene)
            applySyncedGraph(rebuildRootScene: false, rebuildWelcomeScene: true)
        }
    }

    func syncLocatorSourceFromKWIC() {
        locator.updateSource(kwic.primaryLocatorSource)
    }

    private var currentExportSnapshot: NativeTableExportSnapshot? {
        switch selectedTab {
        case .stats:
            return sceneGraph.stats.exportSnapshot
        case .word:
            return sceneGraph.word.exportSnapshot
        case .tokenize:
            return sceneGraph.tokenize.exportSnapshot
        case .topics:
            return sceneGraph.topics.exportSnapshot
        case .compare:
            return sceneGraph.compare.exportSnapshot
        case .chiSquare:
            return sceneGraph.chiSquare.exportSnapshot
        case .ngram:
            return sceneGraph.ngram.exportSnapshot
        case .wordCloud:
            return sceneGraph.wordCloud.exportSnapshot
        case .kwic:
            return sceneGraph.kwic.exportSnapshot
        case .collocate:
            return sceneGraph.collocate.exportSnapshot
        case .locator:
            return sceneGraph.locator.exportSnapshot
        case .library, .settings:
            return nil
        }
    }

    private var currentPreviewablePath: String? {
        if let selectedCorpusPreviewablePath {
            return selectedCorpusPreviewablePath
        }
        let trimmedOpenedPath = sessionStore.openedCorpus?.filePath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedOpenedPath.isEmpty ? nil : trimmedOpenedPath
    }

    private var selectedCorpusPreviewablePath: String? {
        let trimmedSelectedPath = library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedSelectedPath.isEmpty ? nil : trimmedSelectedPath
    }

    private var currentContentTarget: CurrentContentTarget? {
        switch selectedTab {
        case .tokenize:
            if let document = tokenize.exportDocument {
                return .textDocument(document)
            }
        case .stats, .word, .topics, .compare, .chiSquare, .ngram, .wordCloud, .kwic, .collocate, .locator:
            if let snapshot = currentExportSnapshot {
                return .tableSnapshot(snapshot)
            }
        case .library, .settings:
            break
        }
        guard let path = currentPreviewablePath else { return nil }
        return .file(path)
    }

    private func preparedPath(for target: CurrentContentTarget) throws -> String {
        switch target {
        case .file(let path):
            return path
        case .tableSnapshot(let snapshot):
            return try quickLookPreviewFileService.prepare(snapshot: snapshot)
        case .textDocument(let document):
            return try quickLookPreviewFileService.prepare(textDocument: document)
        }
    }

    private func presentQuickLookUnavailableIssue() {
        let status = t("当前没有可预览的内容。", "There is no previewable content available right now.")
        settings.setSupportStatus(status)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t("没有可预览文件", "No Preview Available"),
            message: status,
            recoveryAction: .refreshWorkspace
        )
    }

    private func persistTaskHistory(_ history: [PersistedNativeBackgroundTaskItem]) {
        guard history != lastPersistedTaskHistory else { return }
        lastPersistedTaskHistory = history
        do {
            var snapshot = hostPreferencesStore.load()
            snapshot.taskHistory = history
            try hostPreferencesStore.save(snapshot)
        } catch {
            settings.setSupportStatus("\(t("任务记录保存失败：", "Failed to save task history: "))\(error.localizedDescription)")
        }
    }

    private func presentShareUnavailableIssue() {
        let status = t("当前没有可分享的内容。", "There is no shareable content available right now.")
        settings.setSupportStatus(status)
        activeIssue = WorkspaceIssueBanner(
            tone: .warning,
            title: t("没有可分享内容", "No Shareable Content"),
            message: status,
            recoveryAction: .refreshWorkspace
        )
    }

    private func showWelcomeIfNeeded() {
        isWelcomePresented = settings.showWelcomeScreen
    }

    private func scheduleInputStateSync() {
        cancelPendingInputStateSync()
        inputChangeSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.performInputStateSync()
            }
        }
    }

    private func cancelPendingInputStateSync() {
        inputChangeSyncTask?.cancel()
        inputChangeSyncTask = nil
    }

    private func performInputStateSync() {
        flowCoordinator.markWorkspaceEdited(features: features)
        syncSceneGraph(source: .resultContent)
    }

    private func scheduleLaunchUpdateCheckIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard settings.autoUpdateEnabled, settings.checkForUpdatesOnLaunch else { return }
        Task { [weak self] in
            guard let self else { return }
            await self.checkForUpdates(silent: true)
        }
    }

    private func checkForUpdates(silent: Bool) async {
        guard !isRunningUpdateCheck, !isRunningUpdateDownload else { return }
        isRunningUpdateCheck = true
        let localizedCheckTitle = t("检查更新", "Check for Updates")
        let localizedCheckDetail = t("正在连接更新源…", "Connecting to the update feed…")
        let taskID = silent ? nil : taskCenter.beginTask(title: localizedCheckTitle, detail: localizedCheckDetail)
        defer {
            isRunningUpdateCheck = false
            syncSceneGraph(source: .settings)
        }
        do {
            updateState = NativeUpdateStateSnapshot(
                currentVersion: currentVersion,
                latestVersion: updateState.latestVersion,
                releaseURL: updateState.releaseURL,
                statusMessage: updateState.statusMessage,
                updateAvailable: updateState.updateAvailable,
                isChecking: true,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: updateState.downloadedUpdateVersion,
                downloadedUpdateName: updateState.downloadedUpdateName,
                downloadedUpdatePath: updateState.downloadedUpdatePath,
                releaseTitle: updateState.releaseTitle,
                publishedAt: updateState.publishedAt,
                releaseNotes: updateState.releaseNotes,
                assetName: updateState.assetName
            )
            settings.applyUpdateState(updateState)

            let result = try await updateService.checkForUpdates(currentVersion: currentVersion)
            let localizedStatus = localizedUpdateStatus(from: result)
            let snapshot = try hostPreferencesStore.recordUpdateCheck(status: localizedStatus)
            settings.setUpdateStatus(localizedStatus, checkedAt: snapshot.lastUpdateCheckAt)
            updateState = NativeUpdateStateSnapshot(
                currentVersion: result.currentVersion,
                latestVersion: result.latestVersion,
                releaseURL: result.releaseURL,
                statusMessage: localizedStatus,
                updateAvailable: result.updateAvailable,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: snapshot.downloadedUpdateVersion,
                downloadedUpdateName: snapshot.downloadedUpdateName,
                downloadedUpdatePath: snapshot.downloadedUpdatePath,
                releaseTitle: result.releaseTitle,
                publishedAt: result.publishedAt,
                releaseNotes: result.releaseNotes,
                assetName: result.asset?.name ?? ""
            )
            settings.applyUpdateState(updateState)
            settings.setSupportStatus(localizedStatus)
            taskID.map { taskCenter.completeTask(id: $0, detail: localizedStatus, action: result.updateAvailable ? .openURL(result.releaseURL) : nil) }
            if result.updateAvailable {
                await notificationService.notify(
                    title: t("发现新版本", "New Version Available"),
                    subtitle: result.latestVersion,
                    body: localizedStatus
                )
                if settings.autoDownloadUpdates && result.asset != nil && snapshot.downloadedUpdateVersion != result.latestVersion {
                    await performUpdateDownload(using: result)
                }
            }
            clearActiveIssue()
        } catch {
            updateState = NativeUpdateStateSnapshot(
                currentVersion: currentVersion,
                latestVersion: updateState.latestVersion,
                releaseURL: updateState.releaseURL,
                statusMessage: error.localizedDescription,
                updateAvailable: false,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: updateState.downloadedUpdateVersion,
                downloadedUpdateName: updateState.downloadedUpdateName,
                downloadedUpdatePath: updateState.downloadedUpdatePath,
                releaseTitle: updateState.releaseTitle,
                publishedAt: updateState.publishedAt,
                releaseNotes: updateState.releaseNotes,
                assetName: updateState.assetName
            )
            settings.applyUpdateState(updateState)
            let status = silent
                ? "\(t("启动时检查更新失败：", "Update check on launch failed: "))\(error.localizedDescription)"
                : error.localizedDescription
            settings.setSupportStatus(status)
            activeIssue = WorkspaceIssueBanner(
                tone: .warning,
                title: t("更新检查失败", "Update Check Failed"),
                message: status,
                recoveryAction: .checkForUpdates
            )
            taskID.map { taskCenter.failTask(id: $0, detail: error.localizedDescription) }
        }
    }

    private func performUpdateDownload(using checkedResult: NativeUpdateCheckResult?) async {
        guard !isRunningUpdateDownload else { return }
        isRunningUpdateDownload = true
        let taskID = taskCenter.beginTask(title: t("下载更新", "Download Update"), detail: t("正在准备下载更新包…", "Preparing the update package…"), progress: 0)
        defer {
            isRunningUpdateDownload = false
            syncSceneGraph(source: .settings)
        }
        do {
            updateState = NativeUpdateStateSnapshot(
                currentVersion: currentVersion,
                latestVersion: updateState.latestVersion,
                releaseURL: updateState.releaseURL,
                statusMessage: updateState.statusMessage,
                updateAvailable: updateState.updateAvailable,
                isChecking: false,
                isDownloading: true,
                downloadProgress: 0,
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                releaseTitle: updateState.releaseTitle,
                publishedAt: updateState.publishedAt,
                releaseNotes: updateState.releaseNotes,
                assetName: updateState.assetName
            )
            settings.applyUpdateState(updateState)

            let result: NativeUpdateCheckResult
            if let checkedResult {
                result = checkedResult
            } else {
                result = try await updateService.checkForUpdates(currentVersion: currentVersion)
            }
            let downloaded = try await updateService.downloadUpdate(result) { [weak self] progress in
                guard let self else { return }
                self.taskCenter.updateTask(
                    id: taskID,
                    detail: "\(self.t("正在下载", "Downloading")) \(result.asset?.name ?? self.t("更新包", "update package"))",
                    progress: progress
                )
                self.updateState = NativeUpdateStateSnapshot(
                    currentVersion: result.currentVersion,
                    latestVersion: result.latestVersion,
                    releaseURL: result.releaseURL,
                    statusMessage: self.t("正在下载更新…", "Downloading update…"),
                    updateAvailable: result.updateAvailable,
                    isChecking: false,
                    isDownloading: true,
                    downloadProgress: progress,
                    downloadedUpdateVersion: "",
                    downloadedUpdateName: "",
                    downloadedUpdatePath: "",
                    releaseTitle: result.releaseTitle,
                    publishedAt: result.publishedAt,
                    releaseNotes: result.releaseNotes,
                    assetName: result.asset?.name ?? ""
                )
                self.settings.applyUpdateState(self.updateState)
            }

            _ = try hostPreferencesStore.recordDownloadedUpdate(
                version: downloaded.version,
                name: downloaded.assetName,
                path: downloaded.localPath
            )
            updateState = NativeUpdateStateSnapshot(
                currentVersion: currentVersion,
                latestVersion: downloaded.version,
                releaseURL: downloaded.releaseURL,
                statusMessage: "\(t("已下载更新", "Downloaded update")) \(downloaded.version)\(t("，可直接安装。", ", ready to install."))",
                updateAvailable: true,
                isChecking: false,
                isDownloading: false,
                downloadProgress: 1,
                downloadedUpdateVersion: downloaded.version,
                downloadedUpdateName: downloaded.assetName,
                downloadedUpdatePath: downloaded.localPath,
                releaseTitle: updateState.releaseTitle,
                publishedAt: updateState.publishedAt,
                releaseNotes: updateState.releaseNotes,
                assetName: updateState.assetName
            )
            settings.applyUpdateState(updateState)
            taskCenter.completeTask(
                id: taskID,
                detail: "\(t("已下载", "Downloaded")) \(downloaded.assetName)",
                action: .installDownloadedUpdate(path: downloaded.localPath)
            )
            await notificationService.notify(
                title: t("WordZ 更新已下载", "WordZ update downloaded"),
                subtitle: downloaded.version,
                body: downloaded.assetName
            )
            settings.setSupportStatus("\(t("已下载更新", "Downloaded update")) \(downloaded.version)\(t("，可直接安装。", ", ready to install."))")
            clearActiveIssue()
        } catch {
            updateState = NativeUpdateStateSnapshot(
                currentVersion: currentVersion,
                latestVersion: updateState.latestVersion,
                releaseURL: updateState.releaseURL,
                statusMessage: error.localizedDescription,
                updateAvailable: updateState.updateAvailable,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: updateState.downloadedUpdateVersion,
                downloadedUpdateName: updateState.downloadedUpdateName,
                downloadedUpdatePath: updateState.downloadedUpdatePath,
                releaseTitle: updateState.releaseTitle,
                publishedAt: updateState.publishedAt,
                releaseNotes: updateState.releaseNotes,
                assetName: updateState.assetName
            )
            settings.applyUpdateState(updateState)
            presentIssue(
                error,
                titleZh: "更新下载失败",
                titleEn: "Update Download Failed",
                recoveryAction: .checkForUpdates
            )
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            await notificationService.notify(
                title: t("WordZ 更新下载失败", "WordZ Update Download Failed"),
                subtitle: t("请稍后重试", "Please try again later"),
                body: error.localizedDescription
            )
        }
    }

    private func syncWelcomeScene() {
        welcomeScene = WelcomeSceneModel(
            title: sceneStore.context.appName,
            subtitle: sceneStore.context.versionLabel,
            workspaceSummary: sceneStore.context.workspaceSummary,
            canOpenSelection: sidebar.selectedCorpusID != nil,
            recentDocuments: settings.scene.recentDocuments,
            releaseNotes: settings.scene.releaseNotes,
            help: settings.scene.help
        )
    }

    private func buildDiagnosticsReport() -> String {
        let uiSettings = settings.exportSnapshot()
        let hostSettings = settings.exportHostPreferences()
        let selectedCorpusName = sidebar.selectedCorpus?.name ?? t("未选择", "None")
        let selectedFolderName = sidebar.selectedCorpus?.folderName ?? t("全部", "All")
        return [
            "WordZMac Diagnostics",
            diagnosticLine("生成时间", "Generated At", NativeDateFormatting.iso8601String(from: Date())),
            diagnosticLine("应用", "App", sceneStore.context.appName),
            diagnosticLine("版本", "Version", sceneStore.context.versionLabel),
            diagnosticLine("构建", "Build", sceneStore.context.buildSummary),
            diagnosticLine("工作区", "Workspace", sceneStore.context.workspaceSummary),
            diagnosticLine("选中文件夹", "Selected Folder", selectedFolderName),
            diagnosticLine("选中语料", "Selected Corpus", selectedCorpusName),
            diagnosticLine("当前模块", "Active Tab", shell.selectedTab.rawValue),
            diagnosticLine("显示欢迎页", "Show Welcome", "\(uiSettings.showWelcomeScreen)"),
            diagnosticLine("恢复工作区", "Restore Workspace", "\(uiSettings.restoreWorkspace)"),
            diagnosticLine("调试日志", "Debug Logging", "\(uiSettings.debugLogging)"),
            diagnosticLine("自动更新", "Auto Update Enabled", "\(hostSettings.autoUpdateEnabled)"),
            diagnosticLine("启动检查更新", "Check For Updates On Launch", "\(hostSettings.checkForUpdatesOnLaunch)"),
            diagnosticLine("后台下载更新", "Auto Download Updates", "\(hostSettings.autoDownloadUpdates)"),
            diagnosticLine("最近打开数量", "Recent Documents", "\(hostSettings.recentDocuments.count)"),
            diagnosticLine("上次检查更新", "Last Update Check", hostSettings.lastUpdateCheckAt),
            diagnosticLine("上次更新状态", "Last Update Status", hostSettings.lastUpdateStatus),
            diagnosticLine("用户数据目录", "User Data Directory", settings.scene.userDataDirectory)
        ].joined(separator: "\n")
    }

    private func diagnosticTimestamp() -> String {
        NativeDateFormatting.compactTimestampString(from: Date())
    }

    private var currentVersion: String {
        sceneStore.context.versionLabel.replacingOccurrences(of: "v", with: "")
    }

    private func clearActiveIssue() {
        activeIssue = nil
    }

    private func presentIssue(
        _ error: Error,
        titleZh: String,
        titleEn: String,
        recoveryAction: WorkspaceIssueRecoveryAction? = nil
    ) {
        let message = error.localizedDescription
        settings.setSupportStatus(message)
        activeIssue = WorkspaceIssueBanner(
            tone: .error,
            title: t(titleZh, titleEn),
            message: message,
            recoveryAction: recoveryAction
        )
    }

    private func localizedUpdateStatus(from result: NativeUpdateCheckResult) -> String {
        if result.updateAvailable {
            if let asset = result.asset {
                return "\(t("发现新版本", "New version available")) \(result.latestVersion)\(t("，可下载更新包", ", download available for")) \(asset.name)\(t("。", "."))"
            }
            return "\(t("发现新版本", "New version available")) \(result.latestVersion)\(t("，但当前没有可下载的 mac 安装包。", ", but no downloadable mac installer is available right now."))"
        }
        return "\(t("当前已是最新版本", "You are already up to date"))（\(result.currentVersion)）"
    }

    private func diagnosticLine(_ zh: String, _ en: String, _ value: String) -> String {
        "\(t(zh, en)): \(value)"
    }

    private func refreshShellAvailability() {
        let exportableCurrent = currentExportSnapshot != nil
        shell.updateSelectionAvailability(
            hasSelection: sidebar.selectedCorpusID != nil,
            hasPreviewableCorpus: canQuickLookCurrentCorpus,
            corpusCount: sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: kwic.primaryLocatorSource != nil,
            hasExportableContent: exportableCurrent
        )
    }

    private func applySyncedGraph(rebuildRootScene: Bool, rebuildWelcomeScene: Bool) {
        sceneGraph = sceneGraphStore.graph
        if rebuildRootScene {
            rootScene = rootSceneBuilder.build(
                windowTitle: windowTitle,
                activeTab: shell.selectedTab,
                toolbar: shell.scene.toolbar,
                languageMode: settings.languageMode
            )
        }
        if rebuildWelcomeScene {
            syncWelcomeScene()
        }
    }
}
