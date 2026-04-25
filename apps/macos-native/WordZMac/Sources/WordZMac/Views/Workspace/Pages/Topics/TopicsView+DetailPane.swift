import SwiftUI

extension TopicsView {
    func topicDetailsPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: scene.selectedCluster?.title ?? t("主题详情", "Topic Details"),
            subtitle: scene.selectedCluster?.summary
        ) {
            if let selectedCluster = scene.selectedCluster {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        topicDetailsSummaryStrip(selectedCluster, scene: scene)

                        if let sentimentCluster = scene.sentimentExplainer?.cluster(id: selectedCluster.id) {
                            topicSentimentExplainerCard(sentimentCluster)
                        }

                        if selectedCluster.keywords.isEmpty {
                            Text(t("当前主题暂无可展示关键词。", "No keywords are available for this topic yet."))
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(t("关键词", "Keywords"))
                                    .font(.headline)
                                FlowLayout(data: selectedCluster.keywords) { keyword in
                                    topicKeywordChip(keyword)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("代表片段", "Representative Segments"))
                                .font(.headline)
                            if selectedCluster.representativeSegments.isEmpty {
                                Text(t("当前主题暂无代表片段。", "No representative segments are available for this topic yet."))
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(selectedCluster.representativeSegments.enumerated()), id: \.offset) { index, segment in
                                    Text("\(index + 1). \(segment)")
                                        .font(.callout)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(.quaternary.opacity(0.18))
                                        )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    t("尚未选中主题", "No topic selected"),
                    systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    func topicDetailsSummaryStrip(
        _ selectedCluster: TopicsSelectedClusterSceneModel,
        scene: TopicsSceneModel
    ) -> some View {
        HStack(spacing: 8) {
            topicBadge(
                title: selectedCluster.isOutlier ? t("离群主题", "Outlier Topic") : t("标准主题", "Clustered Topic"),
                tone: selectedCluster.isOutlier ? .orange : .blue
            )
            topicBadge(
                title: "\(selectedCluster.keywords.count) \(t("关键词", "Keywords"))",
                tone: .secondary
            )
            topicBadge(
                title: "\(selectedCluster.representativeSegments.count) \(t("代表片段", "Examples"))",
                tone: .secondary
            )
            if let contrastSummary = selectedCluster.contrastSummary {
                topicBadge(
                    title: contrastSummary,
                    tone: .secondary
                )
            }
            if viewModel.canOpenSelectedTopicInKWIC {
                Button {
                    onAction(.openKWIC)
                } label: {
                    Label(
                        t("在 KWIC 中打开当前主题", "Open Current Topic in KWIC"),
                        systemImage: "text.magnifyingglass"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
            if viewModel.canAnalyzeSelectedTopicInSentiment {
                Button {
                    onAction(.openSentiment(.selectedTopic))
                } label: {
                    Label(
                        t("分析当前主题情感", "Analyze Current Topic Sentiment"),
                        systemImage: "waveform.path.ecg"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
            }
            Spacer(minLength: 0)
            Text("\(scene.visibleSegments) \(t("片段", "Segments"))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    func topicKeywordChip(_ keyword: TopicKeywordSceneItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(keyword.term)
                .font(.callout.weight(.semibold))
                .foregroundStyle(WordZTheme.textPrimary)
            Spacer(minLength: 6)
            Text(keyword.scoreText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.18))
        )
    }
}
