import SwiftUI

extension TopicsView {
    func topicsSentimentOverviewCard(
        _ explainer: TopicsSentimentExplainer
    ) -> some View {
        let dominantLabel = topicDominantLabel(for: explainer.overallSummary)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(t("Topics x Sentiment", "Topics x Sentiment"), systemImage: "chart.bar.doc.horizontal")
                    .font(.caption.weight(.semibold))
                topicBadge(
                    title: dominantLabel.title(in: languageMode),
                    tone: topicBadgeTone(for: dominantLabel)
                )
                Spacer(minLength: 8)
                Text("\(explainer.clusters.count) \(t("主题", "Topics"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Text(explainer.scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                topicSentimentMetric(
                    t("整体分布", "Overall"),
                    value: topicSentimentDistribution(explainer.overallSummary)
                )
                topicSentimentMetric(
                    t("平均净分", "Average Net"),
                    value: String(format: "%.3f", explainer.overallSummary.averageNetScore)
                )
            }

            Text(topicSentimentReviewSummary(explainer.overallReviewImpact))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(explainer.clusters.prefix(3)) { cluster in
                    HStack(spacing: 8) {
                        Text(cluster.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(topicClusterPolaritySummary(cluster))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }

    func topicSentimentExplainerCard(
        _ cluster: TopicsSentimentClusterExplainer
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(t("情感解释", "Sentiment Explainer"))
                    .font(.headline)
                topicBadge(
                    title: cluster.dominantLabel.title(in: languageMode),
                    tone: topicBadgeTone(for: cluster.dominantLabel)
                )
                Spacer()
            }

            HStack(spacing: 12) {
                topicSentimentMetric(
                    t("分布", "Distribution"),
                    value: topicSentimentDistribution(cluster.summary)
                )
                topicSentimentMetric(
                    t("平均净分", "Average Net"),
                    value: String(format: "%.3f", cluster.summary.averageNetScore)
                )
            }

            Text(topicSentimentReviewSummary(cluster.reviewImpact))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if !cluster.topDrivers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("驱动线索", "Driver Cues"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(cluster.topDrivers) { driver in
                        Text(topicDriverLine(driver))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !cluster.exemplars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("代表样例", "Exemplars"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(cluster.exemplars) { exemplar in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(exemplar.effectiveLabel.title(in: languageMode))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.06), in: Capsule())
                                if exemplar.reviewStatus == .overridden {
                                    Text(t("人工改标", "Manual Override"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                                Spacer()
                            }

                            Text(exemplar.text)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Button(t("在情感分析中打开", "Open in Sentiment")) {
                                    onAction(.openSentimentExemplar(exemplar.id))
                                }
                                .buttonStyle(.borderless)
                                .disabled(isBusy)

                                Button(t("打开原文视图", "Open Source Reader")) {
                                    onAction(.openSentimentSourceReader(exemplar.id))
                                }
                                .buttonStyle(.borderless)
                                .disabled(isBusy || !exemplar.canOpenSourceReader)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }

    func topicSentimentMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func topicClusterPolaritySummary(_ cluster: TopicsSentimentClusterExplainer) -> String {
        "\(cluster.dominantLabel.title(in: languageMode)) · \(topicSentimentDistribution(cluster.summary))"
    }

    func topicSentimentDistribution(_ summary: SentimentAggregateSummary) -> String {
        "+\(summary.positiveCount) / =\(summary.neutralCount) / -\(summary.negativeCount)"
    }

    func topicSentimentReviewSummary(_ impact: SentimentReviewImpactSummary) -> String {
        "\(t("已审阅", "Reviewed")) \(impact.reviewedCount) · " +
            "\(t("人工改标", "Overridden")) \(impact.overriddenCount) · " +
            "\(t("生效改动", "Changed")) \(impact.changedCount)"
    }

    func topicDriverLine(_ driver: SentimentDriverCueSummary) -> String {
        "\(driver.cue) · \(driver.direction.title(in: languageMode)) · \(String(format: "%.2f", driver.totalWeight))"
    }

    func topicDominantLabel(for summary: SentimentAggregateSummary) -> SentimentLabel {
        [
            (SentimentLabel.positive, summary.positiveCount),
            (SentimentLabel.neutral, summary.neutralCount),
            (SentimentLabel.negative, summary.negativeCount)
        ]
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.rawValue < rhs.0.rawValue
            }
            return lhs.1 > rhs.1
        }
        .first?.0 ?? .neutral
    }

    func topicBadgeTone(for label: SentimentLabel) -> TopicBadgeTone {
        switch label {
        case .positive:
            return .blue
        case .neutral:
            return .secondary
        case .negative:
            return .orange
        }
    }
}
