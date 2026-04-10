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
        context: AnalysisPerformanceTelemetry.SceneBuildContext,
        build: @escaping @Sendable () -> Scene,
        apply: @escaping @MainActor @Sendable (Scene) -> Bool
    ) {
        let startedAt = Date()
        AnalysisPerformanceTelemetry.logSceneBuildStarted(context)
        LargeResultSceneBuildSupport.queue.async {
            let nextScene = build()
            DispatchQueue.main.async {
                if apply(nextScene) {
                    AnalysisPerformanceTelemetry.logSceneBuildCompleted(context, startedAt: startedAt)
                } else {
                    AnalysisPerformanceTelemetry.logSceneBuildDiscarded(context, startedAt: startedAt)
                }
            }
        }
    }
}
