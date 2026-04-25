import Foundation

struct StorageMigrationCoordinator {
    let catalogStore: LibraryCatalogStore
    let workspaceStore: WorkspaceStateStore

    func ensureInitialized() throws {
        try catalogStore.ensureInitialized()
        try workspaceStore.ensureInitialized()
    }
}
