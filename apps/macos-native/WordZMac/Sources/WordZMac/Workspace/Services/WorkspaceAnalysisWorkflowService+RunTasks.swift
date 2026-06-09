import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func ensureOpenedCorpus(
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws -> OpenedCorpus {
        let corpus: OpenedCorpus
        if let corpusSetID = features.sidebar.selectedCorpusSetID,
           let repository = repository as? any CorpusSetOpeningRepository {
            let sourceID = CorpusSetSourceID.sourceID(for: corpusSetID)
            if let openedCorpus = sessionStore.openedCorpus,
               sessionStore.matchesOpenedCorpusSource(sourceID) {
                corpus = openedCorpus
            } else {
                corpus = try await repository.openSavedCorpusSet(corpusSetID: corpusSetID)
                sessionStore.setOpenedCorpus(corpus, sourceID: sourceID)
            }
        } else {
            corpus = try await libraryCoordinator.ensureOpenedCorpus(
                selectedCorpusID: features.sidebar.selectedCorpusID
            )
        }
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.refreshRecentDocuments(features: features)
        persistenceWorkflow.syncWindowDocumentState(features: features)
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

        do {
            try await operation()
            features.sidebar.clearError()
            taskCenter.completeTask(
                id: taskID,
                detail: descriptor.success(in: .system)
            )
            let durationMs = WordZTelemetry.elapsedMilliseconds(since: startedAt)
            logPerformanceBaseline(
                taskName: taskName,
                taskKey: descriptor.runtimeTaskKey,
                durationMs: durationMs
            )
            analysisLogger.info(
                "run.completed task=\(taskName, privacy: .public) durationMs=\(durationMs, privacy: .public)"
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            taskCenter.failTask(id: taskID, detail: error.localizedDescription)
            let durationMs = WordZTelemetry.elapsedMilliseconds(since: startedAt)
            logPerformanceBaseline(
                taskName: taskName,
                taskKey: descriptor.runtimeTaskKey,
                durationMs: durationMs
            )
            analysisLogger.error(
                "run.failed task=\(taskName, privacy: .public) durationMs=\(durationMs, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func performResultRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        operation: () async throws -> Void
    ) async {
        await performWorkspaceRunTask(descriptor, features: features) {
            try await operation()
            self.completeRun(
                selecting: tab,
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
        }
    }

    func performOpenedCorpusRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        operation: (OpenedCorpus) async throws -> Void
    ) async {
        await performResultRunTask(
            descriptor,
            selecting: tab,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        ) {
            let corpus = try await self.ensureOpenedCorpus(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            try await operation(corpus)
        }
    }

    func completeRun(
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) {
        features.shell.selectedTab = tab
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }

}
