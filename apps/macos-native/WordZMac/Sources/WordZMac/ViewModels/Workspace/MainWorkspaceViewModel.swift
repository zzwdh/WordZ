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
    @Published var compare: ComparePageViewModel
    @Published var keyword: KeywordPageViewModel
    @Published var chiSquare: ChiSquarePageViewModel
    @Published var plot: PlotPageViewModel
    @Published var ngram: NgramPageViewModel
    @Published var cluster: ClusterPageViewModel
    @Published var kwic: KWICPageViewModel
    @Published var collocate: CollocatePageViewModel
    @Published var locator: LocatorPageViewModel
    @Published var sourceReader: SourceReaderViewModel
    @Published var settings: WorkspaceSettingsViewModel
    @Published var sceneGraph = WorkspaceSceneGraph.empty
    @Published var rootScene = RootContentSceneModel.empty
    @Published var isWelcomePresented = false
    @Published var activeIssue: WorkspaceIssueBanner?
    @Published var welcomeScene = WelcomeSceneModel.empty
    @Published var analysisPresets: [AnalysisPresetItem] = []
    @Published var annotationState = WorkspaceAnnotationState.default
    @Published var runningTaskKeys: Set<WorkspaceRuntimeTaskKey> = []
    let lexicalAutocomplete: LexicalAutocompleteController
    let taskCenter: NativeTaskCenter
    let menuBarStatus = WordZMenuBarStatusModel()

    let sceneStore: WorkspaceSceneStore
    let sceneGraphStore: WorkspaceSceneGraphStore
    let rootSceneBuilder: any RootContentSceneBuilding
    let flowCoordinator: WorkspaceFlowCoordinator
    let appCoordinator: AppCoordinator
    let featurePages: WorkspaceFeaturePageHandles
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
    let sessionActor: WorkspaceSessionActor
    lazy var taskSupervisor = WorkspaceTaskSupervisor(
        sessionActor: sessionActor,
        onRunningStateChange: { [weak self] key, isRunning in
            self?.applyRuntimeTaskState(key: key, isRunning: isRunning)
        },
        onBlockingOperationCountChange: { [weak self] count in
            self?.shell.setBlockingOperationCount(count)
        }
    )
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
    var isApplyingWorkspaceAnnotationState = false
    var features: WorkspaceFeatureSet {
        WorkspaceFeatureSet(workspace: self)
    }

    var topics: TopicsPageViewModel { projectedFeaturePage(featurePages.topics) }
    var sentiment: SentimentPageViewModel { projectedFeaturePage(featurePages.sentiment) }
    var evidenceWorkbench: EvidenceWorkbenchViewModel { projectedFeaturePage(featurePages.evidenceWorkbench) }

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
        evidenceWorkbench: EvidenceWorkbenchViewModel = EvidenceWorkbenchViewModel.makeFeaturePage(),
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
        self.lexicalAutocomplete = LexicalAutocompleteController(
            repository: repository as? any StoredFrequencyArtifactReadingRepository
        )
        self.sessionActor = WorkspaceSessionActor()
        self.sidebar = sidebar
        self.shell = shell
        self.library = library
        self.stats = stats
        self.word = word
        self.tokenize = tokenize
        self.compare = compare
        self.keyword = keyword
        self.chiSquare = chiSquare
        self.plot = plot
        self.ngram = ngram
        self.cluster = cluster
        self.kwic = kwic
        self.collocate = collocate
        self.locator = locator
        self.sourceReader = sourceReader
        self.settings = settings
        self.featurePages = WorkspaceFeaturePageHandles(
            topics: topics,
            sentiment: sentiment,
            evidenceWorkbench: evidenceWorkbench
        )
        self.flowCoordinator = runtimeDependencies.flowCoordinator
        self.appCoordinator = runtimeDependencies.appCoordinator

        applyInitialHostState()
        bindWorkspaceCallbacks()
        syncSceneGraph()
    }

}

@MainActor
private func projectedFeaturePage<T>(_ page: AnyObject) -> T {
    guard let projected = page as? T else {
        preconditionFailure("Injected workspace feature page does not match the concrete SwiftUI view model.")
    }
    return projected
}
