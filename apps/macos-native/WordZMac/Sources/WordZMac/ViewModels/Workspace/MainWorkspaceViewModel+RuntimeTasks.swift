import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func isFeatureBusy(_ key: WorkspaceFeatureKey) -> Bool {
        isFeatureBusy(key.runtimeTaskKey)
    }

    func isFeatureBusy(_ key: WorkspaceRuntimeTaskKey) -> Bool {
        shell.isBusy || runningTaskKeys.contains(key)
    }

    func performManagedTask(
        key: WorkspaceRuntimeTaskKey,
        policy: WorkspaceTaskExecutionPolicy,
        isBlocking: Bool = false,
        operation: @escaping @MainActor @Sendable (WorkspaceRequestToken) async -> Void
    ) async {
        await taskSupervisor.perform(
            key: key,
            policy: policy,
            isBlocking: isBlocking,
            operation: operation
        )
    }

    func applyRuntimeTaskState(
        key: WorkspaceRuntimeTaskKey,
        isRunning: Bool
    ) {
        if isRunning {
            runningTaskKeys.insert(key)
        } else {
            runningTaskKeys.remove(key)
        }
    }
}
