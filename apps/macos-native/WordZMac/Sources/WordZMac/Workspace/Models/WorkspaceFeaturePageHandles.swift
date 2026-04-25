import Foundation

@MainActor
struct WorkspaceFeaturePageHandles {
    let topics: any WorkspaceTopicsPageState
    let sentiment: any WorkspaceSentimentPageState
    let evidenceWorkbench: any WorkspaceEvidenceWorkbenchState

    init(
        topics: any WorkspaceTopicsPageState,
        sentiment: any WorkspaceSentimentPageState,
        evidenceWorkbench: any WorkspaceEvidenceWorkbenchState
    ) {
        self.topics = topics
        self.sentiment = sentiment
        self.evidenceWorkbench = evidenceWorkbench
    }

    init(bundle: WorkspaceFeaturePageBundle) {
        self.init(
            topics: bundle.topics,
            sentiment: bundle.sentiment,
            evidenceWorkbench: bundle.evidenceWorkbench
        )
    }
}
