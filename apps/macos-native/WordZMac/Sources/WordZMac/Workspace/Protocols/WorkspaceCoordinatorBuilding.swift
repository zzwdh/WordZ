import Foundation

@MainActor
protocol WorkspaceCoordinatorBuilding {
    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        libraryCoordinator: (any LibraryCoordinating)?
    ) -> WorkspaceCoordinatorSet
}
