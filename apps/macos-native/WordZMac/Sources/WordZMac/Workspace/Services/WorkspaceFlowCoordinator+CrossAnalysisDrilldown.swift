import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func prepareCompareDrilldown(
        target: CompareDrilldownTarget,
        features: WorkspaceFeatureSet
    ) async -> Bool {
        if target == .topics {
            return topicsWorkflow.prepareCompareTopics(
                features: features.topicsWorkflowContext,
                markWorkspaceEdited: markWorkspaceEdited
            )
        }

        return await analysisWorkflow.prepareCompareDrilldown(
            target: target,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func prepareCollocateKWIC(features: WorkspaceFeatureSet) async -> Bool {
        await analysisWorkflow.prepareCollocateKWIC(
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func prepareTopicsSentiment(
        scope: TopicsSentimentDrilldownScope,
        features: WorkspaceFeatureSet
    ) async -> Bool {
        await topicsWorkflow.prepareTopicsSentiment(
            scope: scope,
            features: features.topicsWorkflowContext,
            markWorkspaceEdited: markWorkspaceEdited
        )
    }

    func prepareTopicsKWIC(features: WorkspaceFeatureSet) async -> Bool {
        await topicsWorkflow.prepareTopicsKWIC(
            features: features.topicsWorkflowContext,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            markWorkspaceEdited: markWorkspaceEdited,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
