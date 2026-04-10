import Foundation

@MainActor
final class LibraryManagementCoordinator: LibraryManagementCoordinating {
    let repository: any WorkspaceRepository
    let dialogService: NativeDialogServicing
    let sessionStore: WorkspaceSessionStore

    init(
        repository: any WorkspaceRepository,
        dialogService: NativeDialogServicing,
        sessionStore: WorkspaceSessionStore
    ) {
        self.repository = repository
        self.dialogService = dialogService
        self.sessionStore = sessionStore
    }
    func refreshLibraryState(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws {
        let nextLibrary = try await repository.listLibrary(folderId: "all")
        let nextRecycle = try await repository.listRecycleBin()
        sidebar.librarySnapshot = nextLibrary
        library.applyLibrarySnapshot(nextLibrary)
        library.applyRecycleSnapshot(nextRecycle)
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }
}
