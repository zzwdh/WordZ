import SwiftUI

extension CompareView {
    func compareTopicsSummaryCard(_ summary: CompareTopicsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(summary.headline, systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text("\(summary.topTopics.count) \(t("主题", "Topics"))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Text(summary.scopeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                compareSentimentSummaryMetric(
                    t("片段分布", "Segments"),
                    value: "T \(summary.targetSegmentCount) / R \(summary.referenceSegmentCount)"
                )
                compareSentimentSummaryMetric(
                    t("主题侧向", "Topic Balance"),
                    value: "shared \(summary.sharedTopicCount) · T \(summary.targetLeaningTopicCount) · R \(summary.referenceLeaningTopicCount)"
                )
            }

            Text(summary.note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.topTopics.prefix(3)) { topic in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topic.title)
                                .font(.caption2.weight(.medium))
                            Text(topic.keywordsText)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text(topic.balanceText(in: languageMode))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .monospacedDigit()
                    }
                }
            }

            HStack(spacing: 12) {
                Button(t("打开主题分析", "Open in Topics")) {
                    onAction(.openTopics)
                }
                .disabled(isBusy || !viewModel.canOpenTopicsCrossAnalysis)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WordZTheme.primarySurfaceSoft)
        )
    }
}
