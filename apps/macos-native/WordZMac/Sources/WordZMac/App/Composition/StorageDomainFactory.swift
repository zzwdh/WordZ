import Foundation

@MainActor
struct StorageDomainFactory {
    func makeRepository() -> any WorkspaceRepository {
        NativeWorkspaceRepository()
    }

    func makeWorkspacePersistence() -> WorkspacePersistenceService {
        WorkspacePersistenceService()
    }
}
