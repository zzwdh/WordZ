import Foundation

@MainActor
final class NativeTaskCenter: ObservableObject {
    @Published private(set) var scene = NativeTaskCenterSceneModel.empty

    var onSceneChange: ((NativeTaskCenterSceneModel) -> Void)?

    private var items: [NativeBackgroundTaskItem] = []

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
        mutateTask(id: id, state: .completed, detail: detail, progress: 1, action: action)
    }

    func failTask(id: UUID, detail: String) {
        mutateTask(id: id, state: .failed, detail: detail, progress: nil, action: nil)
    }

    func clearFinished() {
        items.removeAll { $0.state != .running }
        syncScene()
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
        let runningCount = items.filter { $0.state == .running }.count
        let completedCount = items.filter { $0.state == .completed }.count
        let failedCount = items.filter { $0.state == .failed }.count
        let summary: String
        if items.isEmpty {
            summary = "当前没有后台任务。"
        } else {
            summary = "共 \(items.count) 个任务，进行中 \(runningCount) 个，已完成 \(completedCount) 个，失败 \(failedCount) 个。"
        }
        scene = NativeTaskCenterSceneModel(
            items: items.sorted { $0.updatedAt > $1.updatedAt },
            runningCount: runningCount,
            completedCount: completedCount,
            failedCount: failedCount,
            summary: summary
        )
        onSceneChange?(scene)
    }
}
