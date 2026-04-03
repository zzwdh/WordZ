import Foundation

@MainActor
final class NativeTaskCenter: ObservableObject {
    @Published private(set) var scene = NativeTaskCenterSceneModel.empty

    var onSceneChange: ((NativeTaskCenterSceneModel) -> Void)?
    var onHistoryChange: (([PersistedNativeBackgroundTaskItem]) -> Void)?

    private var items: [NativeBackgroundTaskItem] = []
    private var cancelHandlers: [UUID: () -> Void] = [:]

    @discardableResult
    func beginTask(title: String, detail: String, progress: Double? = nil) -> UUID {
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
        syncScene()
        return item.id
    }

    func updateTask(id: UUID, detail: String? = nil, progress: Double? = nil) {
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
        syncScene()
    }

    func completeTask(id: UUID, detail: String, action: NativeBackgroundTaskAction? = nil) {
        cancelHandlers[id] = nil
        mutateTask(id: id, state: .completed, detail: detail, progress: 1, action: action)
    }

    func failTask(id: UUID, detail: String) {
        cancelHandlers[id] = nil
        mutateTask(id: id, state: .failed, detail: detail, progress: nil, action: nil)
    }

    func clearFinished() {
        let runningIDs = Set(items.filter { $0.state == .running }.map(\.id))
        cancelHandlers = cancelHandlers.filter { runningIDs.contains($0.key) }
        items.removeAll { $0.state != .running }
        syncScene()
    }

    func restoreHistory(_ persistedItems: [PersistedNativeBackgroundTaskItem]) {
        cancelHandlers = [:]
        let interruptedDetail = wordZText("上次会话已中断。", "Interrupted in the previous session.", mode: .system)
        items = persistedItems.map { $0.restoredItem(interruptedDetail: interruptedDetail) }
        syncScene()
    }

    func persistedHistory(limit: Int = 50) -> [PersistedNativeBackgroundTaskItem] {
        let sortedItems = items.sorted { $0.updatedAt > $1.updatedAt }
        return persistedHistory(from: sortedItems, limit: limit)
    }

    func registerCancelHandler(id: UUID, handler: @escaping () -> Void) {
        cancelHandlers[id] = handler
        mutateTask(
            id: id,
            state: .running,
            detail: items.first(where: { $0.id == id })?.detail ?? "",
            progress: items.first(where: { $0.id == id })?.progress,
            action: .cancelTask(id: id)
        )
    }

    func cancelTask(id: UUID) {
        guard let handler = cancelHandlers[id] else { return }
        cancelHandlers[id] = nil
        handler()
        failTask(id: id, detail: wordZText("任务已取消。", "Task cancelled.", mode: .system))
    }

    private func mutateTask(
        id: UUID,
        state: NativeBackgroundTaskState,
        detail: String,
        progress: Double?,
        action: NativeBackgroundTaskAction?
    ) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
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
        syncScene()
    }

    private func syncScene() {
        let sortedItems = items.sorted { $0.updatedAt > $1.updatedAt }
        let runningItems = sortedItems.filter { $0.state == .running }
        let runningCount = runningItems.count
        let completedCount = sortedItems.filter { $0.state == .completed }.count
        let failedCount = sortedItems.filter { $0.state == .failed }.count
        let aggregateProgress: Double? = {
            let values = runningItems.compactMap(\.normalizedProgress)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }()
        let summary: String
        if sortedItems.isEmpty {
            summary = wordZText("当前没有后台任务。", "No background tasks right now.", mode: .system)
        } else if runningCount > 0, let aggregateProgress {
            summary = String(
                format: wordZText(
                    "共 %d 个任务，进行中 %d 个，整体进度 %d%%。",
                    "%d tasks total, %d running, %d%% overall progress.",
                    mode: .system
                ),
                sortedItems.count,
                runningCount,
                Int((aggregateProgress * 100).rounded())
            )
        } else {
            summary = String(
                format: wordZText(
                    "共 %d 个任务，进行中 %d 个，已完成 %d 个，失败 %d 个。",
                    "%d tasks total, %d running, %d completed, %d failed.",
                    mode: .system
                ),
                sortedItems.count,
                runningCount,
                completedCount,
                failedCount
            )
        }
        scene = NativeTaskCenterSceneModel(
            items: sortedItems,
            runningCount: runningCount,
            completedCount: completedCount,
            failedCount: failedCount,
            summary: summary,
            aggregateProgress: aggregateProgress,
            highlightedItems: Array(runningItems.prefix(2))
        )
        onSceneChange?(scene)
        onHistoryChange?(persistedHistory(from: sortedItems, limit: 50))
    }

    private func persistedHistory(from items: [NativeBackgroundTaskItem], limit: Int) -> [PersistedNativeBackgroundTaskItem] {
        Array(items.prefix(limit)).map(PersistedNativeBackgroundTaskItem.init(item:))
    }
}
