import Foundation

@MainActor
protocol LibraryManagementCoordinating: AnyObject {
    func refreshLibraryState(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel) async throws
    func chooseImportPaths(preferredRoute: NativeWindowRoute?) async -> [String]?
    func createFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func saveCurrentCorpusSet(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func renameSelectedCorpus(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func moveSelectedCorpusToFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func deleteSelectedCorpus(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func updateSelectedCorpusMetadata(
        _ metadata: CorpusMetadataProfile,
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute?
    ) async throws
    func updateSelectedCorporaMetadata(
        _ patch: BatchCorpusMetadataPatch,
        into library: LibraryManagementViewModel,
        sidebar: LibrarySidebarViewModel,
        preferredRoute: NativeWindowRoute?
    ) async throws
    func renameSelectedFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func deleteSelectedFolder(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func deleteSelectedCorpusSet(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func backupLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func restoreLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func repairLibrary(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func restoreSelectedRecycleEntry(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
    func purgeSelectedRecycleEntry(into library: LibraryManagementViewModel, sidebar: LibrarySidebarViewModel, preferredRoute: NativeWindowRoute?) async throws
}
