import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func logPerformanceBaseline(
        taskName: String,
        taskKey: WorkspaceRuntimeTaskKey?,
        durationMs: Int
    ) {
        guard let taskKey else { return }
        let budget = WorkspaceRuntimeBudgetPolicy.budget(for: taskKey)
        let status = budget.status(for: durationMs)
        analysisLogger.info(
            "run.performanceBaseline task=\(taskName, privacy: .public) key=\(taskKey.rawValue, privacy: .public) status=\(status.rawValue, privacy: .public) durationMs=\(durationMs, privacy: .public) targetMs=\(budget.targetDurationMs, privacy: .public) softLimitMs=\(budget.softDurationLimitMs, privacy: .public) concurrency=\(budget.maxConcurrentWorkItems, privacy: .public) batchSize=\(budget.recommendedBatchSize, privacy: .public) memoryLimitMB=\(budget.memoryLimitMB, privacy: .public) conserve=\(budget.shouldConserveResources, privacy: .public) hardware=\(budget.hardwareSummary, privacy: .public)"
        )
    }
}
