import Foundation

@MainActor
package struct WorkspaceFeaturePageBundle {
    package let topics: TopicsPageViewModel
    package let sentiment: SentimentPageViewModel

    package init(
        topics: TopicsPageViewModel,
        sentiment: SentimentPageViewModel
    ) {
        self.topics = topics
        self.sentiment = sentiment
    }
}
