import Foundation
import WordZEngine

@MainActor
struct MainWorkspaceRuntimeDependencyFactory: MainWorkspaceRuntimeDependencyBuilding {
    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing & WindowDocumentAttaching,
        dialogService: NativeDialogServicing,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        hostActionService: (any NativeHostActionServicing)?,
        updateService: (any NativeUpdateServicing)?,
        notificationService: (any NativeNotificationServicing)?,
        applicationActivityInspector: (any ApplicationActivityInspecting)?,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: (any LibraryCoordinating)?,
        coordinatorFactory: (any WorkspaceCoordinatorBuilding)?
    ) -> MainWorkspaceRuntimeDependencies {
        let resolvedHostActionService = hostActionService ?? Self.makeHostActionService(dialogService: dialogService)
        let resolvedUpdateService = updateService ?? Self.makeUpdateService()
        let resolvedNotificationService = notificationService ?? Self.makeNotificationService()
        let resolvedApplicationActivityInspector = applicationActivityInspector ?? NativeApplicationActivityInspector()
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
            applicationActivityInspector: resolvedApplicationActivityInspector,
            windowDocumentController: windowDocumentController,
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

    private static func makeUpdateService() -> any NativeUpdateServicing {
        GitHubReleaseUpdateService(downloadsDirectoryProvider: {
            EnginePaths.defaultUserDataURL()
                .appendingPathComponent("downloads", isDirectory: true)
                .appendingPathComponent("updates", isDirectory: true)
        })
    }

    private static func makeHostActionService(dialogService: NativeDialogServicing) -> any NativeHostActionServicing {
        NativeHostActionService(
            dialogService: dialogService,
            sharingService: NativeSharingService(anchorWindowProvider: {
                NativeWindowRouting.window(for: .mainWorkspace)
            })
        )
    }
}
