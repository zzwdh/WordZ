import Foundation

enum WorkspaceTopicsRunOutcome {
    case completed
    case cancelled
    case failed(String)
}

@MainActor
extension WorkspaceTopicsWorkflowService {
    func logTopicsRunOutcome(
        _ outcome: WorkspaceTopicsRunOutcome,
        descriptor: WorkspaceRunTaskDescriptor,
        startedAt: Date
    ) {
        let durationMs = WordZTelemetry.elapsedMilliseconds(since: startedAt)
        let taskName = descriptor.title(in: .english)
        analysisWorkflow.logPerformanceBaseline(
            taskName: taskName,
            taskKey: descriptor.runtimeTaskKey,
            durationMs: durationMs
        )

        switch outcome {
        case .completed:
            analysisLogger.info(
                "run.completed task=\(taskName, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        case .cancelled:
            analysisLogger.info(
                "run.cancelled task=\(taskName, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        case .failed(let message):
            analysisLogger.error(
                "run.failed task=\(taskName, privacy: .public) durationMs=\(durationMs, privacy: .public) error=\(message, privacy: .public)"
            )
        }
    }
}
