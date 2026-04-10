import Foundation

struct SceneSyncCallbackMask: OptionSet {
    let rawValue: Int

    static let navigation = SceneSyncCallbackMask(rawValue: 1 << 0)
    static let librarySelection = SceneSyncCallbackMask(rawValue: 1 << 1)
    static let all: SceneSyncCallbackMask = [.navigation, .librarySelection]
}

@MainActor
extension MainWorkspaceViewModel {
    var isNavigationSceneSyncSuppressed: Bool {
        suppressedNavigationSceneSyncDepth > 0
    }

    var isLibrarySelectionSceneSyncSuppressed: Bool {
        suppressedLibrarySelectionSceneSyncDepth > 0
    }

    func performWithoutSceneSyncCallbacks<T>(
        _ callbacks: SceneSyncCallbackMask = .all,
        _ operation: () throws -> T
    ) rethrows -> T {
        if callbacks.contains(.navigation) {
            suppressedNavigationSceneSyncDepth += 1
        }
        if callbacks.contains(.librarySelection) {
            suppressedLibrarySelectionSceneSyncDepth += 1
        }
        defer {
            if callbacks.contains(.librarySelection) {
                suppressedLibrarySelectionSceneSyncDepth -= 1
            }
            if callbacks.contains(.navigation) {
                suppressedNavigationSceneSyncDepth -= 1
            }
        }
        return try operation()
    }

    func performWithoutSceneSyncCallbacks<T>(
        _ callbacks: SceneSyncCallbackMask = .all,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        if callbacks.contains(.navigation) {
            suppressedNavigationSceneSyncDepth += 1
        }
        if callbacks.contains(.librarySelection) {
            suppressedLibrarySelectionSceneSyncDepth += 1
        }
        defer {
            if callbacks.contains(.librarySelection) {
                suppressedLibrarySelectionSceneSyncDepth -= 1
            }
            if callbacks.contains(.navigation) {
                suppressedNavigationSceneSyncDepth -= 1
            }
        }
        return try await operation()
    }
}
