import Foundation

actor WorkspaceTaskSupervisor {
    private struct ManagedTaskEntry {
        let token: WorkspaceRequestToken
        let task: Task<Void, Never>
        let isBlocking: Bool
    }

    private let sessionActor: WorkspaceSessionActor
    private let onRunningStateChange: @MainActor @Sendable (WorkspaceRuntimeTaskKey, Bool) -> Void
    private let onBlockingOperationCountChange: @MainActor @Sendable (Int) -> Void

    private var managedTasks: [WorkspaceRuntimeTaskKey: ManagedTaskEntry] = [:]
    private var parallelTaskCounts: [WorkspaceRuntimeTaskKey: Int] = [:]
    private var blockingOperationCount = 0

    init(
        sessionActor: WorkspaceSessionActor,
        onRunningStateChange: @escaping @MainActor @Sendable (WorkspaceRuntimeTaskKey, Bool) -> Void,
        onBlockingOperationCountChange: @escaping @MainActor @Sendable (Int) -> Void
    ) {
        self.sessionActor = sessionActor
        self.onRunningStateChange = onRunningStateChange
        self.onBlockingOperationCountChange = onBlockingOperationCountChange
    }

    func perform(
        key: WorkspaceRuntimeTaskKey,
        policy: WorkspaceTaskExecutionPolicy,
        isBlocking: Bool = false,
        operation: @escaping @MainActor @Sendable (WorkspaceRequestToken) async -> Void
    ) async {
        switch policy {
        case .replaceLatest:
            if let existing = managedTasks[key] {
                existing.task.cancel()
            }
            let token = await sessionActor.beginRequest(for: key)
            let task = makeManagedTask(
                key: key,
                token: token,
                isBlocking: isBlocking,
                operation: operation
            )
            let wasRunning = managedTasks[key] != nil
            managedTasks[key] = ManagedTaskEntry(token: token, task: task, isBlocking: isBlocking)
            if !wasRunning {
                await onRunningStateChange(key, true)
                if isBlocking {
                    blockingOperationCount += 1
                    await onBlockingOperationCountChange(blockingOperationCount)
                }
            }
            await task.value
        case .singleFlight:
            if let existing = managedTasks[key] {
                await existing.task.value
                return
            }
            let token = await sessionActor.beginRequest(for: key)
            let task = makeManagedTask(
                key: key,
                token: token,
                isBlocking: isBlocking,
                operation: operation
            )
            managedTasks[key] = ManagedTaskEntry(token: token, task: task, isBlocking: isBlocking)
            await onRunningStateChange(key, true)
            if isBlocking {
                blockingOperationCount += 1
                await onBlockingOperationCountChange(blockingOperationCount)
            }
            await task.value
        case .parallel:
            let token = await sessionActor.beginRequest(for: key)
            let nextCount = (parallelTaskCounts[key] ?? 0) + 1
            parallelTaskCounts[key] = nextCount
            if nextCount == 1 {
                await onRunningStateChange(key, true)
            }
            if isBlocking {
                blockingOperationCount += 1
                await onBlockingOperationCountChange(blockingOperationCount)
            }
            let task = Task { @MainActor in
                await operation(token)
            }
            await task.value
            await finishParallelTask(key: key, isBlocking: isBlocking)
        }
    }

    private func makeManagedTask(
        key: WorkspaceRuntimeTaskKey,
        token: WorkspaceRequestToken,
        isBlocking: Bool,
        operation: @escaping @MainActor @Sendable (WorkspaceRequestToken) async -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            await operation(token)
            await self.finishManagedTask(key: key, token: token, isBlocking: isBlocking)
        }
    }

    private func finishManagedTask(
        key: WorkspaceRuntimeTaskKey,
        token: WorkspaceRequestToken,
        isBlocking: Bool
    ) async {
        guard let existing = managedTasks[key], existing.token == token else { return }
        managedTasks.removeValue(forKey: key)
        await onRunningStateChange(key, false)
        if isBlocking {
            blockingOperationCount = max(0, blockingOperationCount - 1)
            await onBlockingOperationCountChange(blockingOperationCount)
        }
    }

    private func finishParallelTask(
        key: WorkspaceRuntimeTaskKey,
        isBlocking: Bool
    ) async {
        let nextCount = max(0, (parallelTaskCounts[key] ?? 1) - 1)
        if nextCount == 0 {
            parallelTaskCounts.removeValue(forKey: key)
            await onRunningStateChange(key, false)
        } else {
            parallelTaskCounts[key] = nextCount
        }
        if isBlocking {
            blockingOperationCount = max(0, blockingOperationCount - 1)
            await onBlockingOperationCountChange(blockingOperationCount)
        }
    }
}
