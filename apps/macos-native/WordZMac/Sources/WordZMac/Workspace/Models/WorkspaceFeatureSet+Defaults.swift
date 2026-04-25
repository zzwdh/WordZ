import Foundation

enum WorkspaceFeatureSetDefaultPages {
    @MainActor
    static func bundle() -> WorkspaceFeaturePageBundle {
        WorkspaceFeaturePageBundle(
            topics: TopicsPageViewModel.makeFeaturePage(),
            sentiment: SentimentPageViewModel.makeFeaturePage(),
            evidenceWorkbench: EvidenceWorkbenchViewModel.makeFeaturePage()
        )
    }

    @MainActor
    static func topics() -> any WorkspaceTopicsPageState {
        TopicsPageViewModel.makeFeaturePage()
    }

    @MainActor
    static func sentiment() -> any WorkspaceSentimentPageState {
        SentimentPageViewModel.makeFeaturePage()
    }

    @MainActor
    static func evidenceWorkbench() -> any WorkspaceEvidenceWorkbenchState {
        EvidenceWorkbenchViewModel.makeFeaturePage()
    }
}
