import Foundation

@MainActor
struct WorkspaceFeaturePageHandles {
    let topics: any WorkspaceTopicsPageState
    let sentiment: any WorkspaceSentimentPageState

    init(
        topics: any WorkspaceTopicsPageState,
        sentiment: any WorkspaceSentimentPageState
    ) {
        self.topics = topics
        self.sentiment = sentiment
    }

    init(bundle: WorkspaceFeaturePageBundle) {
        self.init(
            topics: bundle.topics,
            sentiment: bundle.sentiment
        )
    }
}
