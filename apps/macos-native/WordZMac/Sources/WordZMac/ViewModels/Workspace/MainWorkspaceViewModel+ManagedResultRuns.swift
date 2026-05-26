import Foundation

private let resultRunLogger = WordZTelemetry.logger(category: "Analysis")

private struct ManagedResultRunContext {
    let taskID: UUID
    let startedAt: Date
    let previousTab: WorkspaceDetailTab
}

@MainActor
extension MainWorkspaceViewModel {
    func performResultRun(
        label: String,
        taskKey: WorkspaceRuntimeTaskKey? = nil,
        operation: () async -> Void,
        afterSyncPreparation: (() -> Void)? = nil
    ) async {
        guard !shell.isBusy else {
            resultRunLogger.debug("performResultRun.skippedBusy task=\(label, privacy: .public)")
            return
        }
        let startedAt = Date()
        let previousTab = selectedTab
        if let taskKey {
            applyRuntimeTaskState(key: taskKey, isRunning: true)
        }
        defer {
            if let taskKey {
                applyRuntimeTaskState(key: taskKey, isRunning: false)
            }
        }
        resultRunLogger.info(
            "performResultRun.started task=\(label, privacy: .public) previousTab=\(previousTab.snapshotValue, privacy: .public)"
        )
        await performWithoutSceneSyncCallbacks(.navigation) {
            await operation()
        }
        afterSyncPreparation?()
        syncResultContentSceneGraph(rebuildRootScene: previousTab != selectedTab)
        resultRunLogger.info(
            "performResultRun.completed task=\(label, privacy: .public) selectedTab=\(self.selectedTab.snapshotValue, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public)"
        )
    }

    func performLatestResultRun<Result: Sendable>(
        token: WorkspaceRequestToken,
        label: String,
        descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        operation: () async throws -> Result,
        apply: (Result) -> Void
    ) async {
        let context = beginManagedResultRun(
            label: label,
            descriptor: descriptor
        )

        do {
            let result = try await operation()
            guard await sessionActor.isCurrent(token) else {
                finishManagedResultRunAsDiscarded(context: context, label: label)
                return
            }
            apply(result)
            completeManagedResultRun(
                context: context,
                label: label,
                descriptor: descriptor,
                selecting: tab
            )
        } catch {
            await failManagedResultRun(
                token: token,
                context: context,
                label: label,
                error: error
            )
        }
    }

    private func beginManagedResultRun(
        label: String,
        descriptor: WorkspaceRunTaskDescriptor
    ) -> ManagedResultRunContext {
        let startedAt = Date()
        let previousTab = selectedTab
        resultRunLogger.info(
            "performManagedResultRun.started task=\(label, privacy: .public) previousTab=\(previousTab.snapshotValue, privacy: .public)"
        )
        let taskID = taskCenter.beginTask(
            title: descriptor.title(in: .system),
            detail: descriptor.detail(in: .system)
        )
        return ManagedResultRunContext(
            taskID: taskID,
            startedAt: startedAt,
            previousTab: previousTab
        )
    }

    private func completeManagedResultRun(
        context: ManagedResultRunContext,
        label: String,
        descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab
    ) {
        flowCoordinator.completeRun(selecting: tab, features: features)
        syncResultContentSceneGraph(rebuildRootScene: context.previousTab != selectedTab)
        taskCenter.completeTask(
            id: context.taskID,
            detail: descriptor.success(in: .system)
        )
        resultRunLogger.info(
            "performManagedResultRun.completed task=\(label, privacy: .public) selectedTab=\(self.selectedTab.snapshotValue, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public)"
        )
    }

    private func finishManagedResultRunAsDiscarded(
        context: ManagedResultRunContext,
        label: String
    ) {
        taskCenter.completeTask(
            id: context.taskID,
            detail: wordZText("已丢弃过期结果。", "Discarded stale result.", mode: .system)
        )
        resultRunLogger.debug(
            "performManagedResultRun.discarded task=\(label, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public)"
        )
    }

    private func failManagedResultRun(
        token: WorkspaceRequestToken,
        context: ManagedResultRunContext,
        label: String,
        error: Error
    ) async {
        guard await sessionActor.isCurrent(token) else {
            finishManagedResultRunAsDiscarded(context: context, label: label)
            return
        }
        sidebar.setError(error.localizedDescription)
        taskCenter.failTask(id: context.taskID, detail: error.localizedDescription)
        resultRunLogger.error(
            "performManagedResultRun.failed task=\(label, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: context.startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
    }
}
