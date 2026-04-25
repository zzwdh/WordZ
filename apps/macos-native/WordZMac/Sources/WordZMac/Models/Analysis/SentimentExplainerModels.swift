import Foundation

struct SentimentDriverCueSummary: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let cue: String
    let direction: SentimentLabel
    let totalWeight: Double
    let occurrenceCount: Int
    let primaryRuleTag: String
}

struct SentimentReviewImpactSummary: Equatable, Codable, Sendable {
    let reviewedCount: Int
    let confirmedRawCount: Int
    let overriddenCount: Int
    let changedCount: Int
    let rawPositiveCount: Int
    let rawNeutralCount: Int
    let rawNegativeCount: Int
    let effectivePositiveCount: Int
    let effectiveNeutralCount: Int
    let effectiveNegativeCount: Int

    static let empty = SentimentReviewImpactSummary(
        reviewedCount: 0,
        confirmedRawCount: 0,
        overriddenCount: 0,
        changedCount: 0,
        rawPositiveCount: 0,
        rawNeutralCount: 0,
        rawNegativeCount: 0,
        effectivePositiveCount: 0,
        effectiveNeutralCount: 0,
        effectiveNegativeCount: 0
    )
}

struct SentimentExemplarRowSummary: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let text: String
    let sourceTitle: String
    let rawLabel: SentimentLabel
    let effectiveLabel: SentimentLabel
    let reviewStatus: SentimentReviewStatus
    let groupID: String?
    let groupTitle: String?
    let sourceID: String?
    let sentenceID: Int?
    let tokenIndex: Int?

    var canOpenSourceReader: Bool {
        sourceID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            sentenceID != nil
    }
}

struct CompareSentimentExplainer: Equatable, Codable, Sendable {
    let focusTerm: String
    let headline: String
    let scopeSummary: String
    let targetSummary: SentimentAggregateSummary
    let referenceSummary: SentimentAggregateSummary?
    let positiveDeltaPoints: Double
    let neutralDeltaPoints: Double
    let negativeDeltaPoints: Double
    let averageNetDelta: Double
    let targetReviewImpact: SentimentReviewImpactSummary
    let referenceReviewImpact: SentimentReviewImpactSummary?
    let targetTopDrivers: [SentimentDriverCueSummary]
    let referenceTopDrivers: [SentimentDriverCueSummary]
    let targetExemplars: [SentimentExemplarRowSummary]
    let referenceExemplars: [SentimentExemplarRowSummary]

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        var lines = [
            "\(wordZText("情感解释", "Sentiment Explainer", mode: mode)): \(headline)",
            scopeSummary,
            distributionLine(prefix: wordZText("目标侧", "Target", mode: mode), summary: targetSummary),
            "\(wordZText("分布差值", "Distribution Delta", mode: mode)): +\(formatPoints(positiveDeltaPoints)) / =\(formatPoints(neutralDeltaPoints)) / -\(formatPoints(negativeDeltaPoints))",
            "\(wordZText("平均净分差值", "Average Net Delta", mode: mode)): \(String(format: "%.3f", averageNetDelta))",
            reviewImpactLine(prefix: wordZText("目标侧审校", "Target Review", mode: mode), impact: targetReviewImpact)
        ]
        if let referenceSummary {
            lines.append(distributionLine(prefix: wordZText("参考侧", "Reference", mode: mode), summary: referenceSummary))
        }
        if let referenceReviewImpact {
            lines.append(reviewImpactLine(prefix: wordZText("参考侧审校", "Reference Review", mode: mode), impact: referenceReviewImpact))
        }
        if !targetTopDrivers.isEmpty {
            lines.append("\(wordZText("目标侧驱动线索", "Target Drivers", mode: mode)): \(driverSummary(targetTopDrivers))")
        }
        if !referenceTopDrivers.isEmpty {
            lines.append("\(wordZText("参考侧驱动线索", "Reference Drivers", mode: mode)): \(driverSummary(referenceTopDrivers))")
        }
        return lines
    }

    private func distributionLine(prefix: String, summary: SentimentAggregateSummary) -> String {
        "\(prefix): +\(summary.positiveCount) / =\(summary.neutralCount) / -\(summary.negativeCount)"
    }

    private func reviewImpactLine(prefix: String, impact: SentimentReviewImpactSummary) -> String {
        "\(prefix): reviewed \(impact.reviewedCount) · overridden \(impact.overriddenCount) · changed \(impact.changedCount)"
    }

    private func driverSummary(_ drivers: [SentimentDriverCueSummary]) -> String {
        drivers.map { "\($0.cue) (\(String(format: "%.2f", $0.totalWeight)))" }
            .joined(separator: ", ")
    }

    private func formatPoints(_ value: Double) -> String {
        String(format: "%.1fpp", value)
    }
}

struct TopicsSentimentClusterExplainer: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let summary: SentimentAggregateSummary
    let dominantLabel: SentimentLabel
    let reviewImpact: SentimentReviewImpactSummary
    let topDrivers: [SentimentDriverCueSummary]
    let exemplars: [SentimentExemplarRowSummary]
}

struct TopicsSentimentExplainer: Equatable, Codable, Sendable {
    let scopeSummary: String
    let clusters: [TopicsSentimentClusterExplainer]
    let overallReviewImpact: SentimentReviewImpactSummary

    func cluster(id: String?) -> TopicsSentimentClusterExplainer? {
        guard let id else { return nil }
        return clusters.first(where: { $0.id == id })
    }

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        var lines = [
            "\(wordZText("情感解释", "Sentiment Explainer", mode: mode)): \(wordZText("Topics x Sentiment", "Topics x Sentiment", mode: mode))",
            scopeSummary,
            "\(wordZText("整体审校", "Overall Review", mode: mode)): reviewed \(overallReviewImpact.reviewedCount) · overridden \(overallReviewImpact.overriddenCount) · changed \(overallReviewImpact.changedCount)"
        ]
        for cluster in clusters.prefix(5) {
            lines.append(
                "\(cluster.title): +\(cluster.summary.positiveCount) / =\(cluster.summary.neutralCount) / -\(cluster.summary.negativeCount) · \(wordZText("主标签", "Dominant", mode: mode)) \(cluster.dominantLabel.title(in: mode))"
            )
        }
        return lines
    }
}
