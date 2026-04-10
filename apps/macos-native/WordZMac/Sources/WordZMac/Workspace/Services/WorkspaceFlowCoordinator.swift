import AppKit
import Foundation

@MainActor
final class WorkspaceFlowCoordinator {
    struct WorkspaceRunTaskDescriptor {
        let titleZh: String
        let titleEn: String
        let detailZh: String
        let detailEn: String
        let successZh: String
        let successEn: String

        func title(in mode: AppLanguageMode) -> String {
            wordZText(titleZh, titleEn, mode: mode)
        }

        func detail(in mode: AppLanguageMode) -> String {
            wordZText(detailZh, detailEn, mode: mode)
        }

        func success(in mode: AppLanguageMode) -> String {
            wordZText(successZh, successEn, mode: mode)
        }
    }

    let repository: any WorkspaceRepository
    let workspacePersistence: WorkspacePersistenceService
    let workspacePresentation: WorkspacePresentationService
    let sceneStore: WorkspaceSceneStore
    let windowDocumentController: NativeWindowDocumentController
    let dialogService: NativeDialogServicing
    let hostActionService: any NativeHostActionServicing
    let sessionStore: WorkspaceSessionStore
    let hostPreferencesStore: any NativeHostPreferencesStoring
    let libraryCoordinator: any LibraryCoordinating
    let libraryManagementCoordinator: any LibraryManagementCoordinating
    let exportCoordinator: any WorkspaceExportCoordinating
    let taskCenter: NativeTaskCenter
    var isRunningTopicsAnalysis = false

    init(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: NativeWindowDocumentController,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        libraryCoordinator: any LibraryCoordinating,
        libraryManagementCoordinator: any LibraryManagementCoordinating,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter
    ) {
        self.repository = repository
        self.workspacePersistence = workspacePersistence
        self.workspacePresentation = workspacePresentation
        self.sceneStore = sceneStore
        self.windowDocumentController = windowDocumentController
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.sessionStore = sessionStore
        self.hostPreferencesStore = hostPreferencesStore
        self.libraryCoordinator = libraryCoordinator
        self.libraryManagementCoordinator = libraryManagementCoordinator
        self.exportCoordinator = exportCoordinator
        self.taskCenter = taskCenter
    }
}
