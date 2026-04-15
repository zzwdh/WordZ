import Foundation

@MainActor
final class WorkspaceFlowCoordinator {
    let persistenceWorkflow: WorkspacePersistenceWorkflowService
    let sessionWorkflow: WorkspaceSessionWorkflowService
    let libraryWorkflow: WorkspaceLibraryWorkflowService
    let analysisWorkflow: WorkspaceAnalysisWorkflowService
    let evidenceWorkflow: WorkspaceEvidenceWorkflowService
    let exportWorkflow: WorkspaceExportWorkflowService

    init(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        libraryCoordinator: any LibraryCoordinating,
        libraryManagementCoordinator: any LibraryManagementCoordinating,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter
    ) {
        self.persistenceWorkflow = WorkspacePersistenceWorkflowService(
            repository: repository,
            workspacePersistence: workspacePersistence,
            workspacePresentation: workspacePresentation,
            sceneStore: sceneStore,
            windowDocumentController: windowDocumentController,
            sessionStore: sessionStore,
            hostPreferencesStore: hostPreferencesStore,
            hostActionService: hostActionService
        )
        self.sessionWorkflow = WorkspaceSessionWorkflowService(
            repository: repository,
            sessionStore: sessionStore,
            sceneStore: sceneStore,
            libraryCoordinator: libraryCoordinator,
            persistenceWorkflow: self.persistenceWorkflow
        )
        self.libraryWorkflow = WorkspaceLibraryWorkflowService(
            repository: repository,
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator,
            libraryManagementCoordinator: libraryManagementCoordinator,
            dialogService: dialogService,
            taskCenter: taskCenter,
            persistenceWorkflow: self.persistenceWorkflow
        )
        self.analysisWorkflow = WorkspaceAnalysisWorkflowService(
            repository: repository,
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator,
            dialogService: dialogService,
            hostActionService: hostActionService,
            exportCoordinator: exportCoordinator,
            taskCenter: taskCenter,
            persistenceWorkflow: self.persistenceWorkflow
        )
        self.evidenceWorkflow = WorkspaceEvidenceWorkflowService(
            repository: repository,
            sessionStore: sessionStore,
            dialogService: dialogService,
            hostActionService: hostActionService,
            exportCoordinator: exportCoordinator
        )
        self.exportWorkflow = WorkspaceExportWorkflowService(
            sceneStore: sceneStore,
            exportCoordinator: exportCoordinator
        )
    }
}
