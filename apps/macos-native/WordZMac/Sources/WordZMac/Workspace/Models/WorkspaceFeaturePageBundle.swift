import Foundation

@MainActor
package struct WorkspaceFeaturePageBundle {
    package let topics: TopicsPageViewModel
    package let sentiment: SentimentPageViewModel
    package let evidenceWorkbench: EvidenceWorkbenchViewModel

    package init(
        topics: TopicsPageViewModel,
        sentiment: SentimentPageViewModel,
        evidenceWorkbench: EvidenceWorkbenchViewModel
    ) {
        self.topics = topics
        self.sentiment = sentiment
        self.evidenceWorkbench = evidenceWorkbench
    }
}
