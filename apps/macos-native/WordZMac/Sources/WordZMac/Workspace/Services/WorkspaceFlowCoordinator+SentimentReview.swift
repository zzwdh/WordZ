import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func refreshSentimentReviewSamples(features: WorkspaceFeatureSet) async {
        await sentimentReviewWorkflow.refreshSentimentReviewSamples(features: features)
    }

    func confirmSelectedSentimentRow(features: WorkspaceFeatureSet) async {
        await sentimentReviewWorkflow.confirmSelectedSentimentRow(features: features)
    }

    func overrideSelectedSentimentRow(_ label: SentimentLabel, features: WorkspaceFeatureSet) async {
        await sentimentReviewWorkflow.overrideSelectedSentimentRow(label, features: features)
    }

    func clearSelectedSentimentReview(features: WorkspaceFeatureSet) async {
        await sentimentReviewWorkflow.clearSelectedSentimentReview(features: features)
    }
}
