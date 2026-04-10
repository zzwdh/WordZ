import Foundation

@MainActor
extension AppCoordinator {
    func shutdown() async {
        await repository.stop()
    }
}
