import SwiftUI

extension TopicsView {
    func topicSentimentExplainerCard(
        _ cluster: TopicsSentimentClusterExplainer
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(t("Sentiment Explainer", "Sentiment Explainer"))
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

            Text(
                "\(t("已审阅", "Reviewed")) \(cluster.reviewImpact.reviewedCount) · " +
                "\(t("人工改标", "Overridden")) \(cluster.reviewImpact.overriddenCount) · " +
                "\(t("生效改动", "Changed")) \(cluster.reviewImpact.changedCount)"
            )
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

    func topicDriverLine(_ driver: SentimentDriverCueSummary) -> String {
        "\(driver.cue) · \(driver.direction.title(in: languageMode)) · \(String(format: "%.2f", driver.totalWeight))"
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
