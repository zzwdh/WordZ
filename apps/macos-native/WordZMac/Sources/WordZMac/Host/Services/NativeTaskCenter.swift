import Foundation

@MainActor
final class NativeTaskCenter: ObservableObject {
    @Published private(set) var scene: NativeTaskCenterSceneModel

    var onSceneChange: ((NativeTaskCenterSceneModel) -> Void)?
    var onHistoryChange: (([PersistedNativeBackgroundTaskItem]) -> Void)? {
        didSet { activityStore.onHistoryChange = onHistoryChange }
    }
    var onTerminalEvent: ((NativeBackgroundTaskItem) -> Void)? {
        didSet { activityStore.onTerminalEvent = onTerminalEvent }
    }

    private let activityStore: NativeTaskActivityStore

    init(activityStore: NativeTaskActivityStore = NativeTaskActivityStore()) {
        self.activityStore = activityStore
        self.scene = Self.makeScene(from: activityStore.snapshot)
        bindActivityStore()
    }

    @discardableResult
    func beginTask(title: String, detail: String, progress: Double? = nil) -> UUID {
        activityStore.beginTask(title: title, detail: detail, progress: progress)
    }

    func updateTask(id: UUID, detail: String? = nil, progress: Double? = nil) {
        activityStore.updateTask(id: id, detail: detail, progress: progress)
    }

    func completeTask(id: UUID, detail: String, action: NativeBackgroundTaskAction? = nil) {
        activityStore.completeTask(id: id, detail: detail, action: action)
    }

    func failTask(id: UUID, detail: String) {
        activityStore.failTask(id: id, detail: detail)
    }

    func clearFinished() {
        activityStore.clearFinished()
    }

    func restoreHistory(_ persistedItems: [PersistedNativeBackgroundTaskItem]) {
        let interruptedDetail = wordZText("上次会话已中断。", "Interrupted in the previous session.", mode: .system)
        activityStore.restoreHistory(persistedItems, interruptedDetail: interruptedDetail)
    }

    func persistedHistory(limit: Int = 50) -> [PersistedNativeBackgroundTaskItem] {
        activityStore.persistedHistory(limit: limit)
    }

    func registerCancelHandler(id: UUID, handler: @escaping () -> Void) {
        activityStore.registerCancelHandler(id: id, handler: handler)
    }

    func cancelTask(id: UUID) {
        activityStore.cancelTask(
            id: id,
            cancelledDetail: wordZText("任务已取消。", "Task cancelled.", mode: .system)
        )
    }

    private func bindActivityStore() {
        activityStore.onSnapshotChange = { [weak self] snapshot in
            self?.applyActivitySnapshot(snapshot)
        }
        activityStore.onHistoryChange = onHistoryChange
        activityStore.onTerminalEvent = onTerminalEvent
    }

    private func applyActivitySnapshot(_ snapshot: NativeTaskActivitySnapshot) {
        scene = Self.makeScene(from: snapshot)
        onSceneChange?(scene)
    }

    private static func makeScene(from snapshot: NativeTaskActivitySnapshot) -> NativeTaskCenterSceneModel {
        let summary: String
        if snapshot.items.isEmpty {
            summary = wordZText("当前没有后台任务。", "No background tasks right now.", mode: .system)
        } else if snapshot.runningCount > 0, let aggregateProgress = snapshot.aggregateProgress {
            summary = String(
                format: wordZText(
                    "共 %d 个任务，进行中 %d 个，整体进度 %d%%。",
                    "%d tasks total, %d running, %d%% overall progress.",
                    mode: .system
                ),
                snapshot.items.count,
                snapshot.runningCount,
                Int((aggregateProgress * 100).rounded())
            )
        } else {
            summary = String(
                format: wordZText(
                    "共 %d 个任务，进行中 %d 个，已完成 %d 个，失败 %d 个。",
                    "%d tasks total, %d running, %d completed, %d failed.",
                    mode: .system
                ),
                snapshot.items.count,
                snapshot.runningCount,
                snapshot.completedCount,
                snapshot.failedCount
            )
        }
        return NativeTaskCenterSceneModel(
            items: snapshot.items,
            runningCount: snapshot.runningCount,
            completedCount: snapshot.completedCount,
            failedCount: snapshot.failedCount,
            summary: summary,
            aggregateProgress: snapshot.aggregateProgress,
            highlightedItems: snapshot.highlightedItems
        )
    }
}
