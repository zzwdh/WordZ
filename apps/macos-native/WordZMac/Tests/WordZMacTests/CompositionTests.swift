import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class CompositionTests: XCTestCase {
    func testRuntimeDependencyFactoryUsesCoordinatorFactoryResult() {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        let sessionStore = WorkspaceSessionStore()
        let dialogService = FakeDialogService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let hostActionService = FakeHostActionService()
        let updateService = FakeUpdateService()
        let notificationService = FakeNotificationService()
        let applicationActivityInspector = FakeApplicationActivityInspector()
        let buildMetadataProvider = FakeBuildMetadataProvider()
        let taskCenter = NativeTaskCenter()

        let libraryCoordinator = FakeLibraryCoordinator()
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: dialogService,
            hostActionService: hostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            libraryCoordinator: libraryCoordinator,
            libraryManagementCoordinator: LibraryManagementCoordinator(
                repository: repository,
                dialogService: dialogService,
                sessionStore: sessionStore
            ),
            exportCoordinator: WorkspaceExportCoordinator(dialogService: dialogService),
            taskCenter: taskCenter
        )
        let appCoordinator = AppCoordinator(
            repository: repository,
            bootstrapApplier: FakeBootstrapApplier()
        )
        let coordinatorFactory = FakeWorkspaceCoordinatorFactory(
            result: WorkspaceCoordinatorSet(
                libraryCoordinator: libraryCoordinator,
                flowCoordinator: flowCoordinator,
                appCoordinator: appCoordinator
            )
        )

        let dependencies = MainWorkspaceRuntimeDependencyFactory().make(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
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
            coordinatorFactory: coordinatorFactory
        )

        XCTAssertEqual(coordinatorFactory.makeCallCount, 1)
        XCTAssertTrue(dependencies.hostActionService as AnyObject === hostActionService)
        XCTAssertTrue(dependencies.updateService as AnyObject === updateService)
        XCTAssertTrue(dependencies.notificationService as AnyObject === notificationService)
        XCTAssertTrue(dependencies.applicationActivityInspector as AnyObject === applicationActivityInspector)
        XCTAssertTrue(dependencies.libraryCoordinator as AnyObject === libraryCoordinator)
        XCTAssertTrue(dependencies.flowCoordinator === flowCoordinator)
        XCTAssertTrue(dependencies.appCoordinator === appCoordinator)
    }

    func testWorkspaceCoordinatorFactoryCanInjectFeatureWorkflowFactory() async {
        let repository = FakeWorkspaceRepository()
        let sessionStore = WorkspaceSessionStore()
        let dialogService = FakeDialogService()
        let hostActionService = FakeHostActionService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let buildMetadataProvider = FakeBuildMetadataProvider()
        let taskCenter = NativeTaskCenter()
        let libraryCoordinator = FakeLibraryCoordinator()
        let sentimentWorkflow = SpySentimentWorkflowService()
        let featureWorkflowFactory = SpyWorkspaceFeatureWorkflowFactory(
            sentimentWorkflow: sentimentWorkflow
        )
        let coordinatorFactory = WorkspaceCoordinatorFactory(
            featureWorkflowFactory: featureWorkflowFactory
        )

        let coordinators = coordinatorFactory.make(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: WorkspaceSceneStore(),
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: dialogService,
            hostActionService: hostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            buildMetadataProvider: buildMetadataProvider,
            taskCenter: taskCenter,
            libraryCoordinator: libraryCoordinator
        )

        let features = WorkspaceFeatureSet(
            sidebar: LibrarySidebarViewModel(),
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )
        features.sentiment.source = .pastedText
        features.sentiment.manualText = "Injected sentiment workflow"

        await coordinators.flowCoordinator.runSentiment(features: features)

        XCTAssertEqual(featureWorkflowFactory.makeCallCount, 1)
        XCTAssertEqual(sentimentWorkflow.runSentimentCallCount, 1)
        XCTAssertEqual(sentimentWorkflow.lastManualText, "Injected sentiment workflow")
        XCTAssertEqual(repository.runSentimentCallCount, 0)
    }

    func testNativeAppContainerBuildsWorkspaceFromRuntimeDependencyFactory() {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let hostActionService = FakeHostActionService()
        let updateService = FakeUpdateService()
        let notificationService = FakeNotificationService()
        let applicationActivityInspector = FakeApplicationActivityInspector()
        let buildMetadataProvider = FakeBuildMetadataProvider()
        let diagnosticsBundleService = NativeDiagnosticsBundleService()
        let sceneStore = WorkspaceSceneStore()
        let sceneGraphStore = WorkspaceSceneGraphStore()
        let rootSceneBuilder = RootContentSceneBuilder()
        let taskCenter = NativeTaskCenter()
        let sessionStore = WorkspaceSessionStore()
        let quickLookPreview = QuickLookPreviewFileService(rootDirectory: FileManager.default.temporaryDirectory)
        let reportBundleService = AnalysisReportBundleService()
        let topics = TopicsPageViewModel()
        let sentiment = SentimentPageViewModel()
        let evidenceWorkbench = EvidenceWorkbenchViewModel()

        let libraryCoordinator = FakeLibraryCoordinator()
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: dialogService,
            hostActionService: hostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            libraryCoordinator: libraryCoordinator,
            libraryManagementCoordinator: LibraryManagementCoordinator(
                repository: repository,
                dialogService: dialogService,
                sessionStore: sessionStore
            ),
            exportCoordinator: WorkspaceExportCoordinator(dialogService: dialogService),
            taskCenter: taskCenter
        )
        let appCoordinator = AppCoordinator(
            repository: repository,
            bootstrapApplier: FakeBootstrapApplier()
        )
        let windowDocumentController = NativeWindowDocumentController()
        let runtimeFactory = FakeRuntimeDependencyFactory(
            result: MainWorkspaceRuntimeDependencies(
                hostActionService: hostActionService,
                updateService: updateService,
                notificationService: notificationService,
                applicationActivityInspector: applicationActivityInspector,
                windowDocumentController: windowDocumentController,
                libraryCoordinator: libraryCoordinator,
                flowCoordinator: flowCoordinator,
                appCoordinator: appCoordinator
            )
        )

        let container = NativeAppContainer(
            makeRepository: { repository },
            makeFeaturePages: {
                WorkspaceFeaturePageBundle(
                    topics: topics,
                    sentiment: sentiment,
                    evidenceWorkbench: evidenceWorkbench
                )
            },
            makeWindowDocumentController: { windowDocumentController },
            makeWorkspacePersistence: { WorkspacePersistenceService() },
            makeWorkspacePresentation: { WorkspacePresentationService() },
            makeSceneStore: { sceneStore },
            makeSceneGraphStore: { sceneGraphStore },
            makeRootSceneBuilder: { rootSceneBuilder },
            makeSessionStore: { sessionStore },
            makeTaskCenter: { taskCenter },
            makeCoordinatorFactory: {
                FakeWorkspaceCoordinatorFactory(
                    result: WorkspaceCoordinatorSet(
                        libraryCoordinator: libraryCoordinator,
                        flowCoordinator: flowCoordinator,
                        appCoordinator: appCoordinator
                    )
                )
            },
            makeDialogService: { dialogService },
            makeHostPreferencesStore: { hostPreferencesStore },
            makeHostActionService: { _ in hostActionService },
            makeUpdateService: { updateService },
            makeNotificationService: { notificationService },
            makeApplicationActivityInspector: { applicationActivityInspector },
            makeBuildMetadataProvider: { buildMetadataProvider },
            makeQuickLookPreviewFileService: { quickLookPreview },
            makeReportBundleService: { reportBundleService },
            makeDiagnosticsBundleService: { diagnosticsBundleService },
            makeRuntimeDependencyFactory: { runtimeFactory }
        )

        let workspace = container.makeMainWorkspaceViewModel()

        XCTAssertEqual(runtimeFactory.makeCallCount, 1)
        XCTAssertTrue(workspace.hostActionService as AnyObject === hostActionService)
        XCTAssertTrue(workspace.updateService as AnyObject === updateService)
        XCTAssertTrue(workspace.notificationService as AnyObject === notificationService)
        XCTAssertTrue(workspace.applicationActivityInspector as AnyObject === applicationActivityInspector)
        XCTAssertTrue(workspace.flowCoordinator === flowCoordinator)
        XCTAssertTrue(workspace.appCoordinator === appCoordinator)
        XCTAssertTrue(workspace.taskCenter === taskCenter)
        XCTAssertTrue(workspace.topics === topics)
        XCTAssertTrue(workspace.sentiment === sentiment)
        XCTAssertTrue(workspace.evidenceWorkbench === evidenceWorkbench)
    }

    func testMainWorkspaceAssemblyHelperUsesProvidedRuntimeDependencyFactory() {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let hostActionService = FakeHostActionService()
        let updateService = FakeUpdateService()
        let notificationService = FakeNotificationService()
        let applicationActivityInspector = FakeApplicationActivityInspector()
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: WorkspaceSceneStore(),
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: dialogService,
            hostActionService: hostActionService,
            sessionStore: WorkspaceSessionStore(),
            hostPreferencesStore: hostPreferencesStore,
            libraryCoordinator: FakeLibraryCoordinator(),
            libraryManagementCoordinator: LibraryManagementCoordinator(
                repository: repository,
                dialogService: dialogService,
                sessionStore: WorkspaceSessionStore()
            ),
            exportCoordinator: WorkspaceExportCoordinator(dialogService: dialogService),
            taskCenter: NativeTaskCenter()
        )
        let windowDocumentController = NativeWindowDocumentController()
        let runtimeFactory = FakeRuntimeDependencyFactory(
            result: MainWorkspaceRuntimeDependencies(
                hostActionService: hostActionService,
                updateService: updateService,
                notificationService: notificationService,
                applicationActivityInspector: applicationActivityInspector,
                windowDocumentController: windowDocumentController,
                libraryCoordinator: FakeLibraryCoordinator(),
                flowCoordinator: flowCoordinator,
                appCoordinator: AppCoordinator(
                    repository: repository,
                    bootstrapApplier: FakeBootstrapApplier()
                )
            )
        )

        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService,
            hostPreferencesStore: hostPreferencesStore,
            runtimeDependencyFactory: runtimeFactory
        )

        XCTAssertEqual(runtimeFactory.makeCallCount, 1)
        XCTAssertTrue(workspace.hostActionService as AnyObject === hostActionService)
        XCTAssertTrue(workspace.updateService as AnyObject === updateService)
        XCTAssertTrue(workspace.notificationService as AnyObject === notificationService)
        XCTAssertTrue(workspace.applicationActivityInspector as AnyObject === applicationActivityInspector)
    }

    func testMainWorkspaceViewModelKeepsInjectedFeaturePagesBehindHandles() {
        let repository = FakeWorkspaceRepository()
        let topics = TopicsPageViewModel()
        let sentiment = SentimentPageViewModel()
        let evidenceWorkbench = EvidenceWorkbenchViewModel()

        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            topics: topics,
            sentiment: sentiment,
            evidenceWorkbench: evidenceWorkbench
        )

        XCTAssertTrue(workspace.topics === topics)
        XCTAssertTrue(workspace.sentiment === sentiment)
        XCTAssertTrue(workspace.evidenceWorkbench === evidenceWorkbench)
        XCTAssertTrue(workspace.featurePages.topics === topics)
        XCTAssertTrue(workspace.featurePages.sentiment === sentiment)
        XCTAssertTrue(workspace.featurePages.evidenceWorkbench === evidenceWorkbench)
        XCTAssertTrue(workspace.features.topics as AnyObject === topics)
        XCTAssertTrue(workspace.features.sentiment as AnyObject === sentiment)
        XCTAssertTrue(workspace.features.evidenceWorkbench as AnyObject === evidenceWorkbench)
    }
}
