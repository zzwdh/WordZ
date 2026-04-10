import Foundation

@MainActor
struct WorkspaceCoordinatorSet {
    let libraryCoordinator: any LibraryCoordinating
    let flowCoordinator: WorkspaceFlowCoordinator
    let appCoordinator: AppCoordinator
}
