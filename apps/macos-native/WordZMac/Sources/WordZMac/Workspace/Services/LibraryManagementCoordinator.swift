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
        let folderID = library.selectedFolderID ?? "all"
        let metadataFilterState = sidebar.metadataFilterState
        let sidebarLibrary: LibrarySnapshot
        if let repository = repository as? any MetadataFilteringLibraryRepository {
            sidebarLibrary = try await repository.listLibrary(
                folderId: folderID,
                metadataFilterState: metadataFilterState
            )
        } else {
            sidebarLibrary = try await self.repository.listLibrary(folderId: folderID)
        }

        let nextLibrary: LibrarySnapshot
        if !library.normalizedSearchQuery.isEmpty,
           let repository = repository as? any FullTextSearchingLibraryRepository {
            nextLibrary = try await repository.listLibrary(
                folderId: folderID,
                metadataFilterState: metadataFilterState,
                searchQuery: library.normalizedSearchQuery
            )
        } else {
            nextLibrary = sidebarLibrary
        }
        let nextRecycle = try await repository.listRecycleBin()
        sidebar.librarySnapshot = sidebarLibrary
        library.applyLibrarySnapshot(nextLibrary)
        library.applyRecycleSnapshot(nextRecycle)
        library.syncSidebarSelection(sidebar.selectedCorpusID)
    }
}
