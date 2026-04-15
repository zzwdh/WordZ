import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func ensureOpenedCorpus(features: WorkspaceFeatureSet) async throws -> OpenedCorpus {
        try await analysisWorkflow.ensureOpenedCorpus(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func performWorkspaceRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
        await analysisWorkflow.performWorkspaceRunTask(
            descriptor,
            features: features,
            operation: operation
        )
    }

    func performResultRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        operation: () async throws -> Void
    ) async {
        await analysisWorkflow.performResultRunTask(
            descriptor,
            selecting: tab,
            features: features,
            syncFeatureContexts: syncFeatureContexts,
            operation: operation
        )
    }

    func performOpenedCorpusRunTask(
        _ descriptor: WorkspaceRunTaskDescriptor,
        selecting tab: WorkspaceDetailTab,
        features: WorkspaceFeatureSet,
        operation: (OpenedCorpus) async throws -> Void
    ) async {
        await analysisWorkflow.performOpenedCorpusRunTask(
            descriptor,
            selecting: tab,
            features: features,
            syncFeatureContexts: syncFeatureContexts,
            operation: operation
        )
    }

    func completeRun(selecting tab: WorkspaceDetailTab, features: WorkspaceFeatureSet) {
        analysisWorkflow.completeRun(
            selecting: tab,
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        analysisWorkflow.setBusy(isBusy, features: features)
    }

    func buildComparisonEntries(from selectedCorpora: [LibraryCorpusItem]) async throws -> [CompareRequestEntry] {
        try await analysisWorkflow.buildComparisonEntries(from: selectedCorpora)
    }

    func localizedTopicProgressDetail(_ progress: TopicAnalysisProgress) -> String {
        analysisWorkflow.localizedTopicProgressDetail(progress)
    }
}
