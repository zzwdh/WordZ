import XCTest
@testable import WordZMac

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
        XCTAssertTrue(dependencies.libraryCoordinator as AnyObject === libraryCoordinator)
        XCTAssertTrue(dependencies.flowCoordinator === flowCoordinator)
        XCTAssertTrue(dependencies.appCoordinator === appCoordinator)
    }

    func testNativeAppContainerBuildsWorkspaceFromRuntimeDependencyFactory() {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let hostActionService = FakeHostActionService()
        let updateService = FakeUpdateService()
        let notificationService = FakeNotificationService()
        let buildMetadataProvider = FakeBuildMetadataProvider()
        let diagnosticsBundleService = NativeDiagnosticsBundleService()
        let sceneStore = WorkspaceSceneStore()
        let sceneGraphStore = WorkspaceSceneGraphStore()
        let rootSceneBuilder = RootContentSceneBuilder()
        let taskCenter = NativeTaskCenter()
        let sessionStore = WorkspaceSessionStore()
        let quickLookPreview = QuickLookPreviewFileService(rootDirectory: FileManager.default.temporaryDirectory)
        let reportBundleService = AnalysisReportBundleService()

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
        let runtimeFactory = FakeRuntimeDependencyFactory(
            result: MainWorkspaceRuntimeDependencies(
                hostActionService: hostActionService,
                updateService: updateService,
                notificationService: notificationService,
                libraryCoordinator: libraryCoordinator,
                flowCoordinator: flowCoordinator,
                appCoordinator: appCoordinator
            )
        )

        let container = NativeAppContainer(
            makeRepository: { repository },
            makeWindowDocumentController: { NativeWindowDocumentController() },
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
        XCTAssertTrue(workspace.flowCoordinator === flowCoordinator)
        XCTAssertTrue(workspace.appCoordinator === appCoordinator)
        XCTAssertTrue(workspace.taskCenter === taskCenter)
    }

    func testMainWorkspaceAssemblyHelperUsesProvidedRuntimeDependencyFactory() {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let hostPreferencesStore = InMemoryHostPreferencesStore()
        let hostActionService = FakeHostActionService()
        let updateService = FakeUpdateService()
        let notificationService = FakeNotificationService()
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
        let runtimeFactory = FakeRuntimeDependencyFactory(
            result: MainWorkspaceRuntimeDependencies(
                hostActionService: hostActionService,
                updateService: updateService,
                notificationService: notificationService,
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
    }
}
