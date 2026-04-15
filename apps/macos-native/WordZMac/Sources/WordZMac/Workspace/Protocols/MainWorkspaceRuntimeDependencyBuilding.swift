import Foundation

@MainActor
protocol MainWorkspaceRuntimeDependencyBuilding {
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
    ) -> MainWorkspaceRuntimeDependencies
}
