import Foundation

@MainActor
struct WorkspaceCoordinatorFactory: WorkspaceCoordinatorBuilding {
    let featureWorkflowFactory: (any WorkspaceFeatureWorkflowBuilding)?

    init(featureWorkflowFactory: (any WorkspaceFeatureWorkflowBuilding)? = nil) {
        self.featureWorkflowFactory = featureWorkflowFactory
    }

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
    ) -> WorkspaceCoordinatorSet {
        let resolvedLibraryCoordinator = libraryCoordinator ?? LibraryCoordinator(
            repository: repository,
            sessionStore: sessionStore
        )
        let libraryManagementCoordinator = LibraryManagementCoordinator(
            repository: repository,
            dialogService: dialogService,
            sessionStore: sessionStore
        )
        let exportCoordinator = WorkspaceExportCoordinator(dialogService: dialogService)
        let resolvedFlowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: workspacePersistence,
            workspacePresentation: workspacePresentation,
            sceneStore: sceneStore,
            windowDocumentController: windowDocumentController,
            dialogService: dialogService,
            hostActionService: hostActionService,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            libraryCoordinator: resolvedLibraryCoordinator,
            libraryManagementCoordinator: libraryManagementCoordinator,
            exportCoordinator: exportCoordinator,
            taskCenter: taskCenter,
            featureWorkflowFactory: featureWorkflowFactory
        )
        let bootstrapApplier = WorkspaceBootstrapApplier(
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: resolvedFlowCoordinator,
            hostPreferencesStore: hostPreferencesStore,
            buildMetadataProvider: buildMetadataProvider
        )
        let resolvedAppCoordinator = AppCoordinator(
            repository: repository,
            bootstrapApplier: bootstrapApplier
        )
        return WorkspaceCoordinatorSet(
            libraryCoordinator: resolvedLibraryCoordinator,
            flowCoordinator: resolvedFlowCoordinator,
            appCoordinator: resolvedAppCoordinator
        )
    }
}
