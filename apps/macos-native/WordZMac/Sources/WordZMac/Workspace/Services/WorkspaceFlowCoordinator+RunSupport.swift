import Foundation

private let analysisLogger = WordZTelemetry.logger(category: "Analysis")

@MainActor
extension WorkspaceFlowCoordinator {
    func ensureOpenedCorpus(features: WorkspaceFeatureSet) async throws -> OpenedCorpus {
        let corpus = try await libraryCoordinator.ensureOpenedCorpus(
            selectedCorpusID: features.sidebar.selectedCorpusID
        )
        applyWorkspacePresentation(features: features)
        refreshRecentDocuments(features: features)
        syncWindowDocumentState(features: features)
        return corpus
    }

    func performWorkspaceRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
        let startedAt = Date()
        let taskName = descriptor.title(in: .english)
        analysisLogger.info("run.started task=\(taskName, privacy: .public)")
        let taskID = taskCenter.beginTask(
            title: descriptor.title(in: .system),
            detail: descriptor.detail(in: .system)
        )
        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            try await operation()
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: taskID,
                detail: descriptor.success(in: .system)
            )
            analysisLogger.info(
                "run.completed task=\(taskName, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public)"
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            analysisLogger.error(
                "run.failed task=\(taskName, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt), privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func performResultRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
        await performWorkspaceRunTask(descriptor, features: features) {
            try await operation()
            self.completeRun(selecting: tab, features: features)
        }
    }

    func performOpenedCorpusRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        operation: (OpenedCorpus) async throws -> Void
    ) async {
        await performResultRunTask(descriptor, selecting: tab, features: features) {
            let corpus = try await self.ensureOpenedCorpus(features: features)
            try await operation(corpus)
        }
    }

    func completeRun(selecting tab: WorkspaceDetailTab, features: WorkspaceFeatureSet) {
        features.shell.selectedTab = tab
        applyWorkspacePresentation(features: features)
        persistWorkspaceState(features: features)
    }

    func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }

    func buildComparisonEntries(from selectedCorpora: [LibraryCorpusItem]) async throws -> [CompareRequestEntry] {
        var entries: [CompareRequestEntry] = []
        var seenCorpusIDs: Set<String> = []
        for corpus in selectedCorpora {
            guard seenCorpusIDs.insert(corpus.id).inserted else { continue }
            let opened = try await repository.openSavedCorpus(corpusId: corpus.id)
            entries.append(
                CompareRequestEntry(
                    corpusId: corpus.id,
                    corpusName: corpus.name,
                    folderId: corpus.folderId,
                    folderName: corpus.folderName,
                    sourceType: opened.sourceType,
                    content: opened.content
                )
            )
        }
        return entries
    }

    func localizedTopicProgressDetail(_ progress: TopicAnalysisProgress) -> String {
        switch progress.stage {
        case .preparing:
            return wordZText("正在加载 Topics 模型…", "Loading the Topics model…", mode: .system)
        case .segmenting:
            return wordZText("正在切分英文段落…", "Segmenting English paragraphs…", mode: .system)
        case .embedding:
            return wordZText("正在生成段落向量…", "Embedding paragraph vectors…", mode: .system)
        case .clustering:
            return wordZText("正在聚类主题…", "Clustering topics…", mode: .system)
        case .summarizing:
            return wordZText("正在生成关键词与代表片段…", "Building keywords and representative segments…", mode: .system)
        }
    }
}
