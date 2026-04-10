import Foundation

@MainActor
final class LibraryCoordinator: LibraryCoordinating {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
    }
}
