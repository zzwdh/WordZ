import Foundation
@testable import WordZWorkspaceCore

@MainActor
func makeWorkspaceFlowCoordinator(
    repository: any WorkspaceRepository,
    workspacePersistence: WorkspacePersistenceService = WorkspacePersistenceService(),
    workspacePresentation: WorkspacePresentationService = WorkspacePresentationService(),
    sceneStore: WorkspaceSceneStore = WorkspaceSceneStore(),
    windowDocumentController: NativeWindowDocumentController = NativeWindowDocumentController(),
    dialogService: NativeDialogServicing = NativeSheetDialogService(),
    hostActionService: (any NativeHostActionServicing)? = nil,
    sessionStore: WorkspaceSessionStore,
    hostPreferencesStore: (any NativeHostPreferencesStoring)? = nil,
    libraryCoordinator: any LibraryCoordinating,
    libraryManagementCoordinator: (any LibraryManagementCoordinating)? = nil,
    exportCoordinator: (any WorkspaceExportCoordinating)? = nil,
    taskCenter: NativeTaskCenter? = nil,
    featureWorkflowFactory: (any WorkspaceFeatureWorkflowBuilding)? = nil
) -> WorkspaceFlowCoordinator {
    let resolvedHostActionService = hostActionService ?? NativeHostActionService(dialogService: dialogService)
    let resolvedHostPreferencesStore = hostPreferencesStore ?? NativeHostPreferencesStore()
    let resolvedLibraryManagementCoordinator = libraryManagementCoordinator ?? LibraryManagementCoordinator(
        repository: repository,
        dialogService: dialogService,
        sessionStore: sessionStore
    )
    let resolvedExportCoordinator = exportCoordinator ?? WorkspaceExportCoordinator(dialogService: dialogService)
    let resolvedTaskCenter = taskCenter ?? NativeTaskCenter()

    return WorkspaceFlowCoordinator(
        repository: repository,
        workspacePersistence: workspacePersistence,
        workspacePresentation: workspacePresentation,
        sceneStore: sceneStore,
        windowDocumentController: windowDocumentController,
        dialogService: dialogService,
        hostActionService: resolvedHostActionService,
        sessionStore: sessionStore,
        hostPreferencesStore: resolvedHostPreferencesStore,
        libraryCoordinator: libraryCoordinator,
        libraryManagementCoordinator: resolvedLibraryManagementCoordinator,
        exportCoordinator: resolvedExportCoordinator,
        taskCenter: resolvedTaskCenter,
        featureWorkflowFactory: featureWorkflowFactory
    )
}

@MainActor
func makeAppCoordinator(
    repository: any WorkspaceRepository,
    sceneStore: WorkspaceSceneStore,
    sessionStore: WorkspaceSessionStore,
    flowCoordinator: WorkspaceFlowCoordinator,
    hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
    buildMetadataProvider: any NativeBuildMetadataProviding = NativeBuildMetadataService()
) -> AppCoordinator {
    AppCoordinator(
        repository: repository,
        bootstrapApplier: WorkspaceBootstrapApplier(
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: flowCoordinator,
            hostPreferencesStore: hostPreferencesStore,
            buildMetadataProvider: buildMetadataProvider
        )
    )
}

@MainActor
func makeMainWorkspaceViewModel(
    repository: any WorkspaceRepository,
    workspacePersistence: WorkspacePersistenceService = WorkspacePersistenceService(),
    workspacePresentation: WorkspacePresentationService = WorkspacePresentationService(),
    sceneStore: WorkspaceSceneStore = WorkspaceSceneStore(),
    sceneGraphStore: WorkspaceSceneGraphStore = WorkspaceSceneGraphStore(),
    rootSceneBuilder: any RootContentSceneBuilding = RootContentSceneBuilder(),
    windowDocumentController: NativeWindowDocumentController = NativeWindowDocumentController(),
    dialogService: NativeDialogServicing = NativeSheetDialogService(),
    hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
    hostActionService: (any NativeHostActionServicing)? = nil,
    quickLookPreviewFileService: any QuickLookPreviewFilePreparing = QuickLookPreviewFileService(),
    reportBundleService: any AnalysisReportBundleServicing = AnalysisReportBundleService(),
    updateService: (any NativeUpdateServicing)? = nil,
    notificationService: (any NativeNotificationServicing)? = nil,
    applicationActivityInspector: (any ApplicationActivityInspecting)? = nil,
    buildMetadataProvider: any NativeBuildMetadataProviding = NativeBuildMetadataService(),
    diagnosticsBundleService: any NativeDiagnosticsBundleServicing = NativeDiagnosticsBundleService(),
    taskCenter: NativeTaskCenter = NativeTaskCenter(),
    sessionStore: WorkspaceSessionStore = WorkspaceSessionStore(),
    libraryCoordinator: (any LibraryCoordinating)? = nil,
    coordinatorFactory: (any WorkspaceCoordinatorBuilding)? = nil,
    runtimeDependencyFactory: (any MainWorkspaceRuntimeDependencyBuilding)? = nil,
    sidebar: LibrarySidebarViewModel = LibrarySidebarViewModel(),
    shell: WorkspaceShellViewModel = WorkspaceShellViewModel(),
    library: LibraryManagementViewModel = LibraryManagementViewModel(),
    stats: StatsPageViewModel = StatsPageViewModel(),
    word: WordPageViewModel = WordPageViewModel(),
    tokenize: TokenizePageViewModel = TokenizePageViewModel(),
    topics: TopicsPageViewModel = TopicsPageViewModel(),
    compare: ComparePageViewModel = ComparePageViewModel(),
    sentiment: SentimentPageViewModel = SentimentPageViewModel(),
    keyword: KeywordPageViewModel = KeywordPageViewModel(),
    chiSquare: ChiSquarePageViewModel = ChiSquarePageViewModel(),
    plot: PlotPageViewModel = PlotPageViewModel(),
    ngram: NgramPageViewModel = NgramPageViewModel(),
    cluster: ClusterPageViewModel = ClusterPageViewModel(),
    kwic: KWICPageViewModel = KWICPageViewModel(),
    collocate: CollocatePageViewModel = CollocatePageViewModel(),
    locator: LocatorPageViewModel = LocatorPageViewModel(),
    evidenceWorkbench: EvidenceWorkbenchViewModel = EvidenceWorkbenchViewModel(),
    settings: WorkspaceSettingsViewModel = WorkspaceSettingsViewModel()
) -> MainWorkspaceViewModel {
    let resolvedRuntimeDependencyFactory = runtimeDependencyFactory ?? MainWorkspaceRuntimeDependencyFactory()
    let runtimeDependencies = resolvedRuntimeDependencyFactory.make(
        repository: repository,
        workspacePersistence: workspacePersistence,
        workspacePresentation: workspacePresentation,
        sceneStore: sceneStore,
        windowDocumentController: windowDocumentController,
        dialogService: dialogService,
        hostPreferencesStore: hostPreferencesStore,
        hostActionService: hostActionService,
        updateService: updateService,
        notificationService: notificationService,
        applicationActivityInspector: applicationActivityInspector,
        buildMetadataProvider: buildMetadataProvider,
        taskCenter: taskCenter,
        sessionStore: sessionStore,
        libraryCoordinator: libraryCoordinator,
        coordinatorFactory: coordinatorFactory
    )

    return MainWorkspaceViewModel(
        repository: repository,
        runtimeDependencies: runtimeDependencies,
        sceneStore: sceneStore,
        sceneGraphStore: sceneGraphStore,
        rootSceneBuilder: rootSceneBuilder,
        dialogService: dialogService,
        hostPreferencesStore: hostPreferencesStore,
        quickLookPreviewFileService: quickLookPreviewFileService,
        reportBundleService: reportBundleService,
        buildMetadataProvider: buildMetadataProvider,
        diagnosticsBundleService: diagnosticsBundleService,
        taskCenter: taskCenter,
        sessionStore: sessionStore,
        sidebar: sidebar,
        shell: shell,
        library: library,
        stats: stats,
        word: word,
        tokenize: tokenize,
        topics: topics,
        compare: compare,
        sentiment: sentiment,
        keyword: keyword,
        chiSquare: chiSquare,
        plot: plot,
        ngram: ngram,
        cluster: cluster,
        kwic: kwic,
        collocate: collocate,
        locator: locator,
        evidenceWorkbench: evidenceWorkbench,
        settings: settings
    )
}
