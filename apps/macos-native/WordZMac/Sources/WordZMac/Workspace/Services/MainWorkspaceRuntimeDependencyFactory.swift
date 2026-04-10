import Foundation

@MainActor
struct MainWorkspaceRuntimeDependencyFactory: MainWorkspaceRuntimeDependencyBuilding {
    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: NativeWindowDocumentController,
        dialogService: NativeDialogServicing,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        hostActionService: (any NativeHostActionServicing)?,
        updateService: (any NativeUpdateServicing)?,
        notificationService: (any NativeNotificationServicing)?,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: (any LibraryCoordinating)?,
        coordinatorFactory: (any WorkspaceCoordinatorBuilding)?
    ) -> MainWorkspaceRuntimeDependencies {
        let resolvedHostActionService = hostActionService ?? NativeHostActionService(dialogService: dialogService)
        let resolvedUpdateService = updateService ?? GitHubReleaseUpdateService()
        let resolvedNotificationService = notificationService ?? Self.makeNotificationService()
        let resolvedCoordinatorFactory = coordinatorFactory ?? WorkspaceCoordinatorFactory()
        let coordinators = resolvedCoordinatorFactory.make(
            repository: repository,
            workspacePersistence: workspacePersistence,
            workspacePresentation: workspacePresentation,
            sceneStore: sceneStore,
            windowDocumentController: windowDocumentController,
            dialogService: dialogService,
            hostActionService: resolvedHostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            buildMetadataProvider: buildMetadataProvider,
            taskCenter: taskCenter,
            libraryCoordinator: libraryCoordinator
        )

        return MainWorkspaceRuntimeDependencies(
            hostActionService: resolvedHostActionService,
            updateService: resolvedUpdateService,
            notificationService: resolvedNotificationService,
            libraryCoordinator: coordinators.libraryCoordinator,
            flowCoordinator: coordinators.flowCoordinator,
            appCoordinator: coordinators.appCoordinator
        )
    }

    private static func makeNotificationService() -> any NativeNotificationServicing {
        if !NativeNotificationEnvironment.supportsUserNotifications {
            return NoOpNotificationService()
        }
        return NativeNotificationService()
    }
}
