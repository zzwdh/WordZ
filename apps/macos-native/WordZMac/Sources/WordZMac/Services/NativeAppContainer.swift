import Foundation

@MainActor
final class NativeAppContainer {
    typealias RepositoryFactory = () -> any WorkspaceRepository
    typealias WindowDocumentControllerFactory = () -> NativeWindowDocumentController
    typealias WorkspacePersistenceFactory = () -> WorkspacePersistenceService
    typealias DialogServiceFactory = () -> NativeDialogServicing
    typealias HostPreferencesStoreFactory = () -> any NativeHostPreferencesStoring
    typealias HostActionServiceFactory = (_ dialogService: NativeDialogServicing) -> any NativeHostActionServicing
    typealias UpdateServiceFactory = () -> any NativeUpdateServicing

    private let makeRepository: RepositoryFactory
    private let makeWindowDocumentController: WindowDocumentControllerFactory
    private let makeWorkspacePersistence: WorkspacePersistenceFactory
    private let makeDialogService: DialogServiceFactory
    private let makeHostPreferencesStore: HostPreferencesStoreFactory
    private let makeHostActionService: HostActionServiceFactory
    private let makeUpdateService: UpdateServiceFactory

    init(
        makeRepository: @escaping RepositoryFactory = { NativeWorkspaceRepository() },
        makeWindowDocumentController: @escaping WindowDocumentControllerFactory = { NativeWindowDocumentController() },
        makeWorkspacePersistence: @escaping WorkspacePersistenceFactory = { WorkspacePersistenceService() },
        makeDialogService: @escaping DialogServiceFactory = { NativeSheetDialogService() },
        makeHostPreferencesStore: @escaping HostPreferencesStoreFactory = { NativeHostPreferencesStore() },
        makeHostActionService: @escaping HostActionServiceFactory = { NativeHostActionService(dialogService: $0) },
        makeUpdateService: @escaping UpdateServiceFactory = { GitHubReleaseUpdateService() }
    ) {
        self.makeRepository = makeRepository
        self.makeWindowDocumentController = makeWindowDocumentController
        self.makeWorkspacePersistence = makeWorkspacePersistence
        self.makeDialogService = makeDialogService
        self.makeHostPreferencesStore = makeHostPreferencesStore
        self.makeHostActionService = makeHostActionService
        self.makeUpdateService = makeUpdateService
    }

    static func live() -> NativeAppContainer {
        NativeAppContainer()
    }

    func makeMainWorkspaceViewModel() -> MainWorkspaceViewModel {
        let dialogService = makeDialogService()
        return MainWorkspaceViewModel(
            repository: makeRepository(),
            workspacePersistence: makeWorkspacePersistence(),
            windowDocumentController: makeWindowDocumentController(),
            dialogService: dialogService,
            hostPreferencesStore: makeHostPreferencesStore(),
            hostActionService: makeHostActionService(dialogService),
            updateService: makeUpdateService()
        )
    }
}
