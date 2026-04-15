import Foundation

@MainActor
package final class NativeAppContainer {
    typealias RepositoryFactory = () -> any WorkspaceRepository
    typealias WindowDocumentControllerFactory = () -> NativeWindowDocumentController
    typealias WorkspacePersistenceFactory = () -> WorkspacePersistenceService
    typealias WorkspacePresentationFactory = () -> WorkspacePresentationService
    typealias SceneStoreFactory = () -> WorkspaceSceneStore
    typealias SceneGraphStoreFactory = () -> WorkspaceSceneGraphStore
    typealias RootSceneBuilderFactory = () -> any RootContentSceneBuilding
    typealias SessionStoreFactory = () -> WorkspaceSessionStore
    typealias TaskCenterFactory = () -> NativeTaskCenter
    typealias CoordinatorFactoryFactory = () -> any WorkspaceCoordinatorBuilding
    typealias DialogServiceFactory = () -> NativeDialogServicing
    typealias HostPreferencesStoreFactory = () -> any NativeHostPreferencesStoring
    typealias HostActionServiceFactory = (_ dialogService: NativeDialogServicing) -> any NativeHostActionServicing
    typealias UpdateServiceFactory = () -> any NativeUpdateServicing
    typealias NotificationServiceFactory = () -> any NativeNotificationServicing
    typealias ApplicationActivityInspectorFactory = () -> any ApplicationActivityInspecting
    typealias BuildMetadataFactory = () -> any NativeBuildMetadataProviding
    typealias QuickLookPreviewFactory = () -> any QuickLookPreviewFilePreparing
    typealias ReportBundleFactory = () -> any AnalysisReportBundleServicing
    typealias DiagnosticsBundleFactory = () -> any NativeDiagnosticsBundleServicing
    typealias RuntimeDependencyFactory = () -> any MainWorkspaceRuntimeDependencyBuilding

    private let makeRepository: RepositoryFactory
    private let makeWindowDocumentController: WindowDocumentControllerFactory
    private let makeWorkspacePersistence: WorkspacePersistenceFactory
    private let makeWorkspacePresentation: WorkspacePresentationFactory
    private let makeSceneStore: SceneStoreFactory
    private let makeSceneGraphStore: SceneGraphStoreFactory
    private let makeRootSceneBuilder: RootSceneBuilderFactory
    private let makeSessionStore: SessionStoreFactory
    private let makeTaskCenter: TaskCenterFactory
    private let makeCoordinatorFactory: CoordinatorFactoryFactory
    private let makeDialogService: DialogServiceFactory
    private let makeHostPreferencesStore: HostPreferencesStoreFactory
    private let makeHostActionService: HostActionServiceFactory
    private let makeUpdateService: UpdateServiceFactory
    private let makeNotificationService: NotificationServiceFactory
    private let makeApplicationActivityInspector: ApplicationActivityInspectorFactory
    private let makeBuildMetadataProvider: BuildMetadataFactory
    private let makeQuickLookPreviewFileService: QuickLookPreviewFactory
    private let makeReportBundleService: ReportBundleFactory
    private let makeDiagnosticsBundleService: DiagnosticsBundleFactory
    private let makeRuntimeDependencyFactory: RuntimeDependencyFactory

    convenience init(composition: NativeAppLiveComposition) {
        self.init(
            makeRepository: composition.storage.makeRepository,
            makeWindowDocumentController: composition.workspace.makeWindowDocumentController,
            makeWorkspacePersistence: composition.storage.makeWorkspacePersistence,
            makeWorkspacePresentation: composition.workspace.makeWorkspacePresentation,
            makeSceneStore: composition.workspace.makeSceneStore,
            makeSceneGraphStore: composition.workspace.makeSceneGraphStore,
            makeRootSceneBuilder: composition.workspace.makeRootSceneBuilder,
            makeSessionStore: composition.workspace.makeSessionStore,
            makeTaskCenter: composition.workspace.makeTaskCenter,
            makeCoordinatorFactory: composition.workspace.makeCoordinatorFactory,
            makeDialogService: composition.host.makeDialogService,
            makeHostPreferencesStore: composition.host.makeHostPreferencesStore,
            makeHostActionService: composition.host.makeHostActionService,
            makeUpdateService: composition.host.makeUpdateService,
            makeNotificationService: composition.host.makeNotificationService,
            makeApplicationActivityInspector: composition.host.makeApplicationActivityInspector,
            makeBuildMetadataProvider: composition.host.makeBuildMetadataProvider,
            makeQuickLookPreviewFileService: composition.host.makeQuickLookPreviewFileService,
            makeReportBundleService: composition.export.makeReportBundleService,
            makeDiagnosticsBundleService: composition.diagnostics.makeDiagnosticsBundleService,
            makeRuntimeDependencyFactory: composition.workspace.makeRuntimeDependencyFactory
        )
    }

    init(
        makeRepository: @escaping RepositoryFactory = { NativeWorkspaceRepository() },
        makeWindowDocumentController: @escaping WindowDocumentControllerFactory = { NativeWindowDocumentController() },
        makeWorkspacePersistence: @escaping WorkspacePersistenceFactory = { WorkspacePersistenceService() },
        makeWorkspacePresentation: @escaping WorkspacePresentationFactory = { WorkspacePresentationService() },
        makeSceneStore: @escaping SceneStoreFactory = { WorkspaceSceneStore() },
        makeSceneGraphStore: @escaping SceneGraphStoreFactory = { WorkspaceSceneGraphStore() },
        makeRootSceneBuilder: @escaping RootSceneBuilderFactory = { RootContentSceneBuilder() },
        makeSessionStore: @escaping SessionStoreFactory = { WorkspaceSessionStore() },
        makeTaskCenter: @escaping TaskCenterFactory = { NativeTaskCenter() },
        makeCoordinatorFactory: @escaping CoordinatorFactoryFactory = { WorkspaceCoordinatorFactory() },
        makeDialogService: @escaping DialogServiceFactory = { NativeSheetDialogService() },
        makeHostPreferencesStore: @escaping HostPreferencesStoreFactory = { NativeHostPreferencesStore() },
        makeHostActionService: @escaping HostActionServiceFactory = {
            NativeHostActionService(
                dialogService: $0,
                sharingService: NativeSharingService(anchorWindowProvider: {
                    NativeWindowRouting.window(for: .mainWorkspace)
                })
            )
        },
        makeUpdateService: @escaping UpdateServiceFactory = {
            GitHubReleaseUpdateService(downloadsDirectoryProvider: {
                NativeAppContainer.defaultUpdateDownloadsDirectory()
            })
        },
        makeNotificationService: @escaping NotificationServiceFactory = {
            if !NativeNotificationEnvironment.supportsUserNotifications {
                return NoOpNotificationService()
            }
            return NativeNotificationService()
        },
        makeApplicationActivityInspector: @escaping ApplicationActivityInspectorFactory = { NativeApplicationActivityInspector() },
        makeBuildMetadataProvider: @escaping BuildMetadataFactory = { NativeBuildMetadataService() },
        makeQuickLookPreviewFileService: @escaping QuickLookPreviewFactory = { QuickLookPreviewFileService() },
        makeReportBundleService: @escaping ReportBundleFactory = { AnalysisReportBundleService() },
        makeDiagnosticsBundleService: @escaping DiagnosticsBundleFactory = { NativeDiagnosticsBundleService() },
        makeRuntimeDependencyFactory: @escaping RuntimeDependencyFactory = { MainWorkspaceRuntimeDependencyFactory() }
    ) {
        self.makeRepository = makeRepository
        self.makeWindowDocumentController = makeWindowDocumentController
        self.makeWorkspacePersistence = makeWorkspacePersistence
        self.makeWorkspacePresentation = makeWorkspacePresentation
        self.makeSceneStore = makeSceneStore
        self.makeSceneGraphStore = makeSceneGraphStore
        self.makeRootSceneBuilder = makeRootSceneBuilder
        self.makeSessionStore = makeSessionStore
        self.makeTaskCenter = makeTaskCenter
        self.makeCoordinatorFactory = makeCoordinatorFactory
        self.makeDialogService = makeDialogService
        self.makeHostPreferencesStore = makeHostPreferencesStore
        self.makeHostActionService = makeHostActionService
        self.makeUpdateService = makeUpdateService
        self.makeNotificationService = makeNotificationService
        self.makeApplicationActivityInspector = makeApplicationActivityInspector
        self.makeBuildMetadataProvider = makeBuildMetadataProvider
        self.makeQuickLookPreviewFileService = makeQuickLookPreviewFileService
        self.makeReportBundleService = makeReportBundleService
        self.makeDiagnosticsBundleService = makeDiagnosticsBundleService
        self.makeRuntimeDependencyFactory = makeRuntimeDependencyFactory
    }

    package static func live() -> NativeAppContainer {
        NativeAppContainer(composition: .live())
    }

    nonisolated private static func defaultUpdateDownloadsDirectory() -> URL {
        EnginePaths.defaultUserDataURL()
            .appendingPathComponent("downloads", isDirectory: true)
            .appendingPathComponent("updates", isDirectory: true)
    }

    package func makeMainWorkspaceViewModel() -> MainWorkspaceViewModel {
        let dialogService = makeDialogService()
        let sceneStore = makeSceneStore()
        let sessionStore = makeSessionStore()
        let taskCenter = makeTaskCenter()
        let repository = makeRepository()
        let workspacePersistence = makeWorkspacePersistence()
        let workspacePresentation = makeWorkspacePresentation()
        let windowDocumentController = makeWindowDocumentController()
        let hostPreferencesStore = makeHostPreferencesStore()
        let hostActionService = makeHostActionService(dialogService)
        let updateService = makeUpdateService()
        let notificationService = makeNotificationService()
        let applicationActivityInspector = makeApplicationActivityInspector()
        let buildMetadataProvider = makeBuildMetadataProvider()
        let runtimeDependencies = makeRuntimeDependencyFactory().make(
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
            libraryCoordinator: nil,
            coordinatorFactory: makeCoordinatorFactory()
        )
        return MainWorkspaceViewModel(
            repository: repository,
            runtimeDependencies: runtimeDependencies,
            sceneStore: sceneStore,
            sceneGraphStore: makeSceneGraphStore(),
            rootSceneBuilder: makeRootSceneBuilder(),
            dialogService: dialogService,
            hostPreferencesStore: hostPreferencesStore,
            quickLookPreviewFileService: makeQuickLookPreviewFileService(),
            reportBundleService: makeReportBundleService(),
            buildMetadataProvider: buildMetadataProvider,
            diagnosticsBundleService: makeDiagnosticsBundleService(),
            taskCenter: taskCenter,
            sessionStore: sessionStore,
            sidebar: LibrarySidebarViewModel(),
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            word: WordPageViewModel(),
            tokenize: TokenizePageViewModel(),
            topics: TopicsPageViewModel(),
            compare: ComparePageViewModel(),
            sentiment: SentimentPageViewModel(),
            keyword: KeywordPageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            plot: PlotPageViewModel(),
            ngram: NgramPageViewModel(),
            cluster: ClusterPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )
    }
}
