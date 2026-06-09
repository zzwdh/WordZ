import Foundation

@MainActor
extension WorkspaceTopicsWorkflowService {
    func runTopics(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let descriptor = WorkspaceRunTaskDescriptor.topics
        let startedAt = Date()
        let taskName = descriptor.title(in: .english)
        let featureSet = features.withFeatureSet { $0 }
        if let compareContext = features.topics.compareDrilldownContext {
            await runCompareTopics(
                context: compareContext,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            return
        }

        guard !isRunningTopicsAnalysis else { return }
        isRunningTopicsAnalysis = true
        var taskID: UUID?
        defer { isRunningTopicsAnalysis = false }

        do {
            analysisLogger.info("run.started task=\(taskName, privacy: .public)")
            let corpus = try await analysisWorkflow.ensureOpenedCorpus(
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            )
            analysisWorkflow.setBusy(true, features: featureSet)
            defer { analysisWorkflow.setBusy(false, features: featureSet) }

            let options = topicAnalysisOptions(for: features.topics, text: corpus.content)
            let createdTaskID = taskCenter.beginTask(
                title: descriptor.title(in: .system),
                detail: descriptor.detail(in: .system),
                progress: 0
            )
            taskID = createdTaskID

            let analysisTask = Task { () throws -> TopicAnalysisResult in
                if let progressRepository = repository as? TopicProgressReportingRepository {
                    return try await progressRepository.runTopics(text: corpus.content, options: options) { [weak taskCenter] progress in
                        Task { @MainActor in
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: self.analysisWorkflow.localizedTopicProgressDetail(progress),
                                progress: progress.progress
                            )
                        }
                    }
                }
                return try await repository.runTopics(text: corpus.content, options: options)
            }
            taskCenter.registerCancelHandler(id: createdTaskID) {
                analysisTask.cancel()
            }

            let result = try await analysisTask.value
            features.topics.apply(result)
            analysisWorkflow.completeRun(
                selecting: .topics,
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            )
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: createdTaskID,
                detail: descriptor.success(in: .system)
            )
            logTopicsRunOutcome(
                .completed,
                descriptor: descriptor,
                startedAt: startedAt
            )
        } catch is CancellationError {
            features.sidebar.clearError()
            logTopicsRunOutcome(
                .cancelled,
                descriptor: descriptor,
                startedAt: startedAt
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
            logTopicsRunOutcome(
                .failed(error.localizedDescription),
                descriptor: descriptor,
                startedAt: startedAt
            )
        }
    }
}
