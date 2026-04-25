import Foundation

enum AnalysisSceneBuildScheduling {
    static func schedule<Scene>(
        build: @escaping @Sendable () -> Scene,
        apply: @escaping @MainActor @Sendable (Scene) -> Void
    ) {
        LargeResultSceneBuildSupport.queue.async {
            let nextScene = build()
            DispatchQueue.main.async {
                apply(nextScene)
            }
        }
    }

    static func schedule<Scene>(
        owner: any AnyObject,
        context: AnalysisPerformanceTelemetry.SceneBuildContext,
        build: @escaping @Sendable () throws -> Scene,
        apply: @escaping @MainActor @Sendable (Scene) -> Bool
    ) {
        let startedAt = Date()
        let ownerID = ObjectIdentifier(owner)
        let taskID = UUID()
        AnalysisPerformanceTelemetry.logSceneBuildStarted(context)
        let task = Task.detached(priority: .userInitiated) {
            defer {
                AnalysisSceneBuildTaskRegistry.shared.clear(ownerID: ownerID, taskID: taskID)
            }
            do {
                try Task.checkCancellation()
                let nextScene = try build()
                try Task.checkCancellation()
                if await apply(nextScene) {
                    AnalysisPerformanceTelemetry.logSceneBuildCompleted(context, startedAt: startedAt)
                } else {
                    AnalysisPerformanceTelemetry.logSceneBuildDiscarded(context, startedAt: startedAt)
                }
            } catch is CancellationError {
                AnalysisPerformanceTelemetry.logSceneBuildDiscarded(context, startedAt: startedAt)
            } catch {
                AnalysisPerformanceTelemetry.logSceneBuildDiscarded(context, startedAt: startedAt)
            }
        }
        AnalysisSceneBuildTaskRegistry.shared.replace(
            ownerID: ownerID,
            taskID: taskID,
            task: task
        )
    }

    static func cancel(owner: any AnyObject) {
        AnalysisSceneBuildTaskRegistry.shared.cancel(ownerID: ObjectIdentifier(owner))
    }
}

private final class AnalysisSceneBuildTaskRegistry: @unchecked Sendable {
    static let shared = AnalysisSceneBuildTaskRegistry()

    private struct Entry {
        let taskID: UUID
        let task: Task<Void, Never>
    }

    private let lock = NSLock()
    private var entries: [ObjectIdentifier: Entry] = [:]

    func replace(
        ownerID: ObjectIdentifier,
        taskID: UUID,
        task: Task<Void, Never>
    ) {
        let previousTask = withLock { () -> Task<Void, Never>? in
            let previousTask = entries[ownerID]?.task
            entries[ownerID] = Entry(taskID: taskID, task: task)
            return previousTask
        }
        previousTask?.cancel()
    }

    func cancel(ownerID: ObjectIdentifier) {
        let task = withLock { entries.removeValue(forKey: ownerID)?.task }
        task?.cancel()
    }

    func clear(ownerID: ObjectIdentifier, taskID: UUID) {
        withLock {
            guard let entry = entries[ownerID],
                  entry.taskID == taskID
            else { return }
            entries.removeValue(forKey: ownerID)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
