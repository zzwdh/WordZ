import Foundation

@MainActor
final class WorkspaceSentimentReviewWorkflowService {
    private let repository: any WorkspaceRepository

    init(repository: any WorkspaceRepository) {
        self.repository = repository
    }

    func refreshSentimentReviewSamples(features: WorkspaceFeatureSet) async {
        do {
            let samples = try await repository.listSentimentReviewSamples()
            apply(samples, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func confirmSelectedSentimentRow(features: WorkspaceFeatureSet) async {
        await saveSelectedReview(decision: .confirmRaw, features: features)
    }

    func overrideSelectedSentimentRow(_ label: SentimentLabel, features: WorkspaceFeatureSet) async {
        let decision: SentimentReviewDecision
        switch label {
        case .positive:
            decision = .overridePositive
        case .neutral:
            decision = .overrideNeutral
        case .negative:
            decision = .overrideNegative
        }
        await saveSelectedReview(decision: decision, features: features)
    }

    func clearSelectedSentimentReview(features: WorkspaceFeatureSet) async {
        guard let sample = features.sentiment.selectedReviewSample else {
            features.library.setStatus(
                wordZText(
                    "当前条目还没有审校样本。",
                    "The selected row does not have a saved review yet.",
                    mode: .system
                )
            )
            features.sidebar.clearError()
            return
        }

        do {
            try await repository.deleteSentimentReviewSample(sampleID: sample.id)
            var samples = features.sentiment.reviewSamples
            samples.removeAll { $0.id == sample.id }
            apply(samples, features: features)
            features.library.setStatus(
                wordZText(
                    "已清除当前情感审校结果。",
                    "Cleared the saved sentiment review for the selected row.",
                    mode: .system
                )
            )
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func saveSelectedReview(
        decision: SentimentReviewDecision,
        features: WorkspaceFeatureSet
    ) async {
        guard let sample = features.sentiment.makeSelectedReviewSample(decision: decision) else {
            features.sidebar.setError(
                wordZText(
                    "请先运行情感分析并选择一条结果。",
                    "Run sentiment analysis and select a row first.",
                    mode: .system
                )
            )
            return
        }

        do {
            let saved = try await repository.saveSentimentReviewSample(sample)
            var samples = features.sentiment.reviewSamples.filter { $0.id != saved.id && $0.matchKey != saved.matchKey }
            samples.insert(saved, at: 0)
            apply(samples, features: features)
            features.library.setStatus(successMessage(for: decision))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func apply(
        _ samples: [SentimentReviewSample],
        features: WorkspaceFeatureSet
    ) {
        features.sentiment.applyReviewSamples(samples)
        if let presentationResult = features.sentiment.presentationResult {
            switch presentationResult.rawResult.request.source {
            case .corpusCompare:
                features.compare.applyCompareSentimentResult(presentationResult, languageMode: .system)
            case .topicSegments:
                features.topics.applySentimentPresentationResult(presentationResult, languageMode: .system)
            case .openedCorpus, .pastedText, .kwicVisible:
                break
            }
        }
    }

    private func successMessage(for decision: SentimentReviewDecision) -> String {
        switch decision {
        case .confirmRaw:
            return wordZText(
                "已保存当前条目的原判确认。",
                "Saved the raw confirmation for the selected row.",
                mode: .system
            )
        case .overridePositive:
            return wordZText(
                "已将当前条目标记为积极。",
                "Marked the selected row as positive.",
                mode: .system
            )
        case .overrideNeutral:
            return wordZText(
                "已将当前条目标记为中性。",
                "Marked the selected row as neutral.",
                mode: .system
            )
        case .overrideNegative:
            return wordZText(
                "已将当前条目标记为消极。",
                "Marked the selected row as negative.",
                mode: .system
            )
        }
    }
}
