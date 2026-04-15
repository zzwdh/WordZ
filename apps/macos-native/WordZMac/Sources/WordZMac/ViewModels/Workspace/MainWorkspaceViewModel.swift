import Foundation
import SwiftUI

@MainActor
package final class MainWorkspaceViewModel: ObservableObject {
    @Published var sidebar: LibrarySidebarViewModel
    @Published var shell: WorkspaceShellViewModel
    @Published var library: LibraryManagementViewModel
    @Published var stats: StatsPageViewModel
    @Published var word: WordPageViewModel
    @Published var tokenize: TokenizePageViewModel
    @Published var topics: TopicsPageViewModel
    @Published var compare: ComparePageViewModel
    @Published var sentiment: SentimentPageViewModel
    @Published var keyword: KeywordPageViewModel
    @Published var chiSquare: ChiSquarePageViewModel
    @Published var plot: PlotPageViewModel
    @Published var ngram: NgramPageViewModel
    @Published var cluster: ClusterPageViewModel
    @Published var kwic: KWICPageViewModel
    @Published var collocate: CollocatePageViewModel
    @Published var locator: LocatorPageViewModel
    @Published var evidenceWorkbench: EvidenceWorkbenchViewModel
    @Published var sourceReader: SourceReaderViewModel
    @Published var settings: WorkspaceSettingsViewModel
    @Published var sceneGraph = WorkspaceSceneGraph.empty
    @Published var rootScene = RootContentSceneModel.empty
    @Published var isWelcomePresented = false
    @Published var activeIssue: WorkspaceIssueBanner?
    @Published var welcomeScene = WelcomeSceneModel.empty
    @Published var analysisPresets: [AnalysisPresetItem] = []
    let taskCenter: NativeTaskCenter
    let menuBarStatus = WordZMenuBarStatusModel()

    let sceneStore: WorkspaceSceneStore
    let sceneGraphStore: WorkspaceSceneGraphStore
    let rootSceneBuilder: any RootContentSceneBuilding
    let flowCoordinator: WorkspaceFlowCoordinator
    let appCoordinator: AppCoordinator
    let sessionStore: WorkspaceSessionStore
    let dialogService: NativeDialogServicing
    let hostPreferencesStore: any NativeHostPreferencesStoring
    let hostActionService: any NativeHostActionServicing
    let windowDocumentController: any WindowDocumentAttaching
    let analysisPresetRepository: (any AnalysisPresetManagingRepository)?
    let quickLookPreviewFileService: any QuickLookPreviewFilePreparing
    let reportBundleService: any AnalysisReportBundleServicing
    let updateService: any NativeUpdateServicing
    let notificationService: any NativeNotificationServicing
    let applicationActivityInspector: any ApplicationActivityInspecting
    let buildMetadataProvider: any NativeBuildMetadataProviding
    let diagnosticsBundleService: any NativeDiagnosticsBundleServicing
    var initialized = false
    var inputChangeSyncTask: Task<Void, Never>?
    var updateState = NativeUpdateStateSnapshot.empty
    var isRunningUpdateCheck = false
    var isRunningUpdateDownload = false
    var latestCheckedUpdate: NativeUpdateCheckResult?
    var launchUpdateCheckTask: Task<Void, Never>?
    var hasScheduledLaunchUpdateWorkflow = false
    var lastPersistedTaskHistory: [PersistedNativeBackgroundTaskItem] = []
    var suppressedNavigationSceneSyncDepth = 0
    var suppressedLibrarySelectionSceneSyncDepth = 0
    var lastRootSceneBuildRequest: RootSceneBuildRequest?
    var lastWelcomeSceneBuildRequest: WelcomeSceneBuildRequest?
    var lastAppliedSceneGraphRevision = -1
    var isApplyingSceneSyncRequest = false
    var pendingSceneSyncRequest: SceneSyncRequest?
    var features: WorkspaceFeatureSet {
        WorkspaceFeatureSet(workspace: self)
    }

    init(
        repository: any WorkspaceRepository,
        runtimeDependencies: MainWorkspaceRuntimeDependencies,
        sceneStore: WorkspaceSceneStore,
        sceneGraphStore: WorkspaceSceneGraphStore,
        rootSceneBuilder: any RootContentSceneBuilding,
        dialogService: NativeDialogServicing,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        quickLookPreviewFileService: any QuickLookPreviewFilePreparing,
        reportBundleService: any AnalysisReportBundleServicing,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        diagnosticsBundleService: any NativeDiagnosticsBundleServicing,
        taskCenter: NativeTaskCenter,
        sessionStore: WorkspaceSessionStore,
        sidebar: LibrarySidebarViewModel,
        shell: WorkspaceShellViewModel,
        library: LibraryManagementViewModel,
        stats: StatsPageViewModel,
        word: WordPageViewModel,
        tokenize: TokenizePageViewModel,
        topics: TopicsPageViewModel,
        compare: ComparePageViewModel,
        sentiment: SentimentPageViewModel,
        keyword: KeywordPageViewModel,
        chiSquare: ChiSquarePageViewModel,
        plot: PlotPageViewModel,
        ngram: NgramPageViewModel,
        cluster: ClusterPageViewModel,
        kwic: KWICPageViewModel,
        collocate: CollocatePageViewModel,
        locator: LocatorPageViewModel,
        evidenceWorkbench: EvidenceWorkbenchViewModel = EvidenceWorkbenchViewModel(),
        sourceReader: SourceReaderViewModel = SourceReaderViewModel(),
        settings: WorkspaceSettingsViewModel
    ) {
        self.sceneStore = sceneStore
        self.sceneGraphStore = sceneGraphStore
        self.rootSceneBuilder = rootSceneBuilder
        self.sessionStore = sessionStore
        self.dialogService = dialogService
        self.hostPreferencesStore = hostPreferencesStore
        self.hostActionService = runtimeDependencies.hostActionService
        self.windowDocumentController = runtimeDependencies.windowDocumentController
        self.analysisPresetRepository = repository as? any AnalysisPresetManagingRepository
        self.quickLookPreviewFileService = quickLookPreviewFileService
        self.reportBundleService = reportBundleService
        self.updateService = runtimeDependencies.updateService
        self.notificationService = runtimeDependencies.notificationService
        self.applicationActivityInspector = runtimeDependencies.applicationActivityInspector
        self.buildMetadataProvider = buildMetadataProvider
        self.diagnosticsBundleService = diagnosticsBundleService
        self.taskCenter = taskCenter
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.stats = stats
        self.word = word
        self.tokenize = tokenize
        self.topics = topics
        self.compare = compare
        self.sentiment = sentiment
        self.keyword = keyword
        self.chiSquare = chiSquare
        self.plot = plot
        self.ngram = ngram
        self.cluster = cluster
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
        self.evidenceWorkbench = evidenceWorkbench
        self.sourceReader = sourceReader
        self.settings = settings
        self.flowCoordinator = runtimeDependencies.flowCoordinator
        self.appCoordinator = runtimeDependencies.appCoordinator

        applyInitialHostState()
        bindWorkspaceCallbacks()
        syncSceneGraph()
    }

}
