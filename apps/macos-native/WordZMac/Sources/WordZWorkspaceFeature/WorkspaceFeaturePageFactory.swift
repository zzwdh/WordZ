import WordZWorkspaceCore

@MainActor
package enum WordZWorkspaceFeaturePageFactory {
    package static func makePageBundle() -> WorkspaceFeaturePageBundle {
        WorkspaceFeaturePageBundle(
            topics: TopicsPageViewModel.makeFeaturePage(),
            sentiment: SentimentPageViewModel.makeFeaturePage(),
            evidenceWorkbench: EvidenceWorkbenchViewModel.makeFeaturePage()
        )
    }
}
