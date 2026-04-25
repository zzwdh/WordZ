import Foundation

@MainActor
final class WorkspaceEvidenceWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let dialogService: NativeDialogServicing
    let hostActionService: any NativeHostActionServicing
    let exportCoordinator: any WorkspaceExportCoordinating

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.exportCoordinator = exportCoordinator
    }
}

extension WorkspaceEvidenceWorkflowService: WorkspaceEvidenceWorkflowServing {}
