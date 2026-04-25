import Foundation

@MainActor
final class WorkspaceTopicsWorkflowService {
    let repository: any WorkspaceRepository
    let sessionStore: WorkspaceSessionStore
    let taskCenter: NativeTaskCenter
    let analysisWorkflow: WorkspaceAnalysisWorkflowService
    var isRunningTopicsAnalysis = false

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        taskCenter: NativeTaskCenter,
        analysisWorkflow: WorkspaceAnalysisWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.taskCenter = taskCenter
        self.analysisWorkflow = analysisWorkflow
    }

    func runTopics(
        features: WorkspaceTopicsWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
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
            let corpus = try await analysisWorkflow.ensureOpenedCorpus(
                features: featureSet,
                syncFeatureContexts: syncFeatureContexts
            )
            analysisWorkflow.setBusy(true, features: featureSet)
            defer { analysisWorkflow.setBusy(false, features: featureSet) }

            let options = topicAnalysisOptions(for: features.topics)
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

    func prepareTopicsKWIC(
        features: WorkspaceTopicsWorkflowContext,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        let featureSet = features.withFeatureSet { $0 }
        guard let result = features.topics.result,
              let row = features.topics.kwicDrilldownRow(from: result) else {
            features.sidebar.setError(
                wordZText(
                    "请先选择一个带原文上下文的 Topics 片段。",
                    "Select a topic segment with source context before opening KWIC.",
                    mode: .system
                )
            )
            return false
        }

        guard let keyword = features.topics.kwicDrilldownKeyword() else {
            features.sidebar.setError(
                wordZText(
                    "当前 Topics 结果还没有可用于 KWIC 的聚焦词项。",
                    "The current Topics result does not have a usable focus term for KWIC yet.",
                    mode: .system
                )
            )
            return false
        }

        let corpusID = row.sourceID ?? features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError(
                wordZText(
                    "当前 Topics 片段没有可用的语料范围。",
                    "The selected topic segment does not have a usable corpus scope.",
                    mode: .system
                )
            )
            return false
        }

        do {
            try await analysisWorkflow.prepareDrilldownCorpusSelection(
                corpusID,
                features: featureSet,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = keyword
        features.kwic.searchOptions = features.topics.searchOptions
        if features.kwic.leftWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.leftWindow = "5"
        }
        if features.kwic.rightWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.rightWindow = "5"
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(featureSet)
        return true
    }

    func topicAnalysisOptions(for viewModel: any WorkspaceTopicsPageState) -> TopicAnalysisOptions {
        TopicAnalysisOptions(
            granularity: .paragraph,
            language: "english",
            minTopicSize: viewModel.minTopicSizeValue,
            includeOutliers: viewModel.includeOutliers,
            searchQuery: viewModel.normalizedQuery,
            searchOptions: viewModel.searchOptions,
            stopwordFilter: viewModel.stopwordFilter
        )
    }
}

extension WorkspaceTopicsWorkflowService: WorkspaceTopicsWorkflowServing {}
