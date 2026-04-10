import Foundation

@MainActor
final class AppCoordinator {
    let repository: any WorkspaceRepository
    let bootstrapApplier: any WorkspaceBootstrapApplying

    init(
        repository: any WorkspaceRepository,
        bootstrapApplier: any WorkspaceBootstrapApplying
    ) {
        self.repository = repository
        self.bootstrapApplier = bootstrapApplier
    }
}
