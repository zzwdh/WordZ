import Foundation

@MainActor
protocol MainWorkspaceRuntimeDependencyBuilding {
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
    ) -> MainWorkspaceRuntimeDependencies
}
