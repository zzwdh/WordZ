import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func runTopics(features: WorkspaceFeatureSet) async {
        guard !isRunningTopicsAnalysis else { return }
        isRunningTopicsAnalysis = true
        var taskID: UUID?
        defer { isRunningTopicsAnalysis = false }
        do {
            let corpus = try await ensureOpenedCorpus(features: features)
            setBusy(true, features: features)
            defer { setBusy(false, features: features) }

            let options = TopicAnalysisOptions(
                granularity: .paragraph,
                language: "english",
                minTopicSize: features.topics.minTopicSizeValue,
                includeOutliers: features.topics.includeOutliers,
                searchQuery: features.topics.normalizedQuery,
                searchOptions: features.topics.searchOptions,
                stopwordFilter: features.topics.stopwordFilter
            )
            let createdTaskID = taskCenter.beginTask(
                title: wordZText("Topics 建模", "Run Topics", mode: .system),
                detail: wordZText("正在准备主题建模…", "Preparing topic modeling…", mode: .system),
                progress: 0
            )
            taskID = createdTaskID

            let analysisTask = Task { () throws -> TopicAnalysisResult in
                if let progressRepository = repository as? TopicProgressReportingRepository {
                    return try await progressRepository.runTopics(text: corpus.content, options: options) { [weak taskCenter] progress in
                        Task { @MainActor in
                            taskCenter?.updateTask(
                                id: createdTaskID,
                                detail: self.localizedTopicProgressDetail(progress),
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
            features.shell.selectedTab = .topics
            applyWorkspacePresentation(features: features)
            features.sidebar.clearError()
            persistWorkspaceState(features: features)
            taskCenter.completeTask(
                id: createdTaskID,
                detail: wordZText("Topics 结果已准备完成。", "Topics results are ready.", mode: .system)
            )
        } catch is CancellationError {
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
            if let taskID {
                taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            }
        }
    }
}
