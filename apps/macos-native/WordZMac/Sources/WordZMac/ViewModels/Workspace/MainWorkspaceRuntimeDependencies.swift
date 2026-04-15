import Foundation

@MainActor
struct MainWorkspaceRuntimeDependencies {
    let hostActionService: any NativeHostActionServicing
    let updateService: any NativeUpdateServicing
    let notificationService: any NativeNotificationServicing
    let applicationActivityInspector: any ApplicationActivityInspecting
    let windowDocumentController: any WindowDocumentAttaching
    let libraryCoordinator: any LibraryCoordinating
    let flowCoordinator: WorkspaceFlowCoordinator
    let appCoordinator: AppCoordinator

    init(
        hostActionService: any NativeHostActionServicing,
        updateService: any NativeUpdateServicing,
        notificationService: any NativeNotificationServicing,
        applicationActivityInspector: any ApplicationActivityInspecting,
        windowDocumentController: any WindowDocumentAttaching,
        libraryCoordinator: any LibraryCoordinating,
        flowCoordinator: WorkspaceFlowCoordinator,
        appCoordinator: AppCoordinator
    ) {
        self.hostActionService = hostActionService
        self.updateService = updateService
        self.notificationService = notificationService
        self.applicationActivityInspector = applicationActivityInspector
        self.windowDocumentController = windowDocumentController
        self.libraryCoordinator = libraryCoordinator
        self.flowCoordinator = flowCoordinator
        self.appCoordinator = appCoordinator
    }
}
