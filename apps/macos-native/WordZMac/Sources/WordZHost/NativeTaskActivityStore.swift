import Foundation

package struct NativeTaskActivitySnapshot: Equatable {
    package let items: [NativeBackgroundTaskItem]
    package let runningCount: Int
    package let completedCount: Int
    package let failedCount: Int
    package let aggregateProgress: Double?
    package let highlightedItems: [NativeBackgroundTaskItem]

    package static let empty = NativeTaskActivitySnapshot(
        items: [],
        runningCount: 0,
        completedCount: 0,
        failedCount: 0,
        aggregateProgress: nil,
        highlightedItems: []
    )

    package init(
        items: [NativeBackgroundTaskItem],
        runningCount: Int,
        completedCount: Int,
        failedCount: Int,
        aggregateProgress: Double?,
        highlightedItems: [NativeBackgroundTaskItem]
    ) {
        self.items = items
        self.runningCount = runningCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.aggregateProgress = aggregateProgress
        self.highlightedItems = highlightedItems
    }
}

@MainActor
package final class NativeTaskActivityStore {
    package var onSnapshotChange: ((NativeTaskActivitySnapshot) -> Void)?
    package var onHistoryChange: (([PersistedNativeBackgroundTaskItem]) -> Void)?
    package var onTerminalEvent: ((NativeBackgroundTaskItem) -> Void)?

    package private(set) var snapshot = NativeTaskActivitySnapshot.empty

    private var items: [NativeBackgroundTaskItem] = []
    private var cancelHandlers: [UUID: () -> Void] = [:]

    package init() {}

    @discardableResult
    package func beginTask(title: String, detail: String, progress: Double? = nil) -> UUID {
        let item = NativeBackgroundTaskItem(
            id: UUID(),
            title: title,
            detail: detail,
            state: .running,
            progress: progress,
            startedAt: Date(),
            updatedAt: Date(),
            primaryAction: nil
        )
        items.insert(item, at: 0)
        syncSnapshot(emitHistory: true)
        return item.id
    }

    package func updateTask(id: UUID, detail: String? = nil, progress: Double? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let current = items[index]
        items[index] = NativeBackgroundTaskItem(
            id: current.id,
            title: current.title,
            detail: detail ?? current.detail,
            state: current.state,
            progress: progress ?? current.progress,
            startedAt: current.startedAt,
            updatedAt: Date(),
            primaryAction: current.primaryAction
        )
        syncSnapshot(emitHistory: false)
    }

    package func completeTask(id: UUID, detail: String, action: NativeBackgroundTaskAction? = nil) {
        cancelHandlers[id] = nil
        if let item = mutateTask(
            id: id,
            state: .completed,
            detail: detail,
            progress: 1,
            action: action,
            emitHistory: true
        ) {
            onTerminalEvent?(item)
        }
    }

    package func failTask(id: UUID, detail: String) {
        cancelHandlers[id] = nil
        if let item = mutateTask(
            id: id,
            state: .failed,
            detail: detail,
            progress: nil,
            action: nil,
            emitHistory: true
        ) {
            onTerminalEvent?(item)
        }
    }

    package func clearFinished() {
        let runningIDs = Set(items.filter { $0.state == .running }.map(\.id))
        cancelHandlers = cancelHandlers.filter { runningIDs.contains($0.key) }
        items.removeAll { $0.state != .running }
        syncSnapshot(emitHistory: true)
    }

    package func restoreHistory(
        _ persistedItems: [PersistedNativeBackgroundTaskItem],
        interruptedDetail: String
    ) {
        cancelHandlers = [:]
        items = persistedItems.map { $0.restoredItem(interruptedDetail: interruptedDetail) }
        syncSnapshot(emitHistory: true)
    }

    package func persistedHistory(limit: Int = 50) -> [PersistedNativeBackgroundTaskItem] {
        let sortedItems = items.sorted { $0.updatedAt > $1.updatedAt }
        return persistedHistory(from: sortedItems, limit: limit)
    }

    package func registerCancelHandler(id: UUID, handler: @escaping () -> Void) {
        cancelHandlers[id] = handler
        _ = mutateTask(
            id: id,
            state: .running,
            detail: items.first(where: { $0.id == id })?.detail ?? "",
            progress: items.first(where: { $0.id == id })?.progress,
            action: .cancelTask(id: id),
            emitHistory: false
        )
    }

    package func cancelTask(id: UUID, cancelledDetail: String) {
        guard let handler = cancelHandlers[id] else { return }
        cancelHandlers[id] = nil
        handler()
        failTask(id: id, detail: cancelledDetail)
    }

    private func mutateTask(
        id: UUID,
        state: NativeBackgroundTaskState,
        detail: String,
        progress: Double?,
        action: NativeBackgroundTaskAction?,
        emitHistory: Bool
    ) -> NativeBackgroundTaskItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        let current = items[index]
        items[index] = NativeBackgroundTaskItem(
            id: current.id,
            title: current.title,
            detail: detail,
            state: state,
            progress: progress,
            startedAt: current.startedAt,
            updatedAt: Date(),
            primaryAction: action
        )
        syncSnapshot(emitHistory: emitHistory)
        return items[index]
    }

    private func syncSnapshot(emitHistory: Bool) {
        let sortedItems = items.sorted { $0.updatedAt > $1.updatedAt }
        let runningItems = sortedItems.filter { $0.state == .running }
        let aggregateProgress: Double? = {
            let values = runningItems.compactMap(\.normalizedProgress)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }()
        snapshot = NativeTaskActivitySnapshot(
            items: sortedItems,
            runningCount: runningItems.count,
            completedCount: sortedItems.filter { $0.state == .completed }.count,
            failedCount: sortedItems.filter { $0.state == .failed }.count,
            aggregateProgress: aggregateProgress,
            highlightedItems: Array(runningItems.prefix(2))
        )
        onSnapshotChange?(snapshot)
        if emitHistory {
            onHistoryChange?(persistedHistory(from: sortedItems, limit: 50))
        }
    }

    private func persistedHistory(
        from items: [NativeBackgroundTaskItem],
        limit: Int
    ) -> [PersistedNativeBackgroundTaskItem] {
        Array(items.prefix(limit)).map(PersistedNativeBackgroundTaskItem.init(item:))
    }
}
