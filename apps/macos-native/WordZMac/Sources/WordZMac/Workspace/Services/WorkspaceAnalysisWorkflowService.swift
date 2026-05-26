import Foundation

let analysisLogger = WordZTelemetry.logger(category: "Analysis")

@MainActor
final class WorkspaceAnalysisWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let libraryCoordinator: any LibraryCoordinating
    let dialogService: NativeDialogServicing
    let hostActionService: any NativeHostActionServicing
    let exportCoordinator: any WorkspaceExportCoordinating
    let taskCenter: NativeTaskCenter
    let persistenceWorkflow: WorkspacePersistenceWorkflowService

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: any LibraryCoordinating,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter,
        persistenceWorkflow: WorkspacePersistenceWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.libraryCoordinator = libraryCoordinator
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.exportCoordinator = exportCoordinator
        self.taskCenter = taskCenter
        self.persistenceWorkflow = persistenceWorkflow
    }
}
