import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func launch(_ operation: @escaping @MainActor () async -> Void) {
        Task { await operation() }
    }
}
