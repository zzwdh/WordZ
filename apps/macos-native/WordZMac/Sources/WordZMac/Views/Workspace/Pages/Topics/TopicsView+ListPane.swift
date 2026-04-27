import SwiftUI

extension TopicsView {
    func topicsListPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: t("主题列表", "Topic List")
        ) {
            if scene.clusters.isEmpty {
                ContentUnavailableView(
                    t("当前没有可显示的主题", "No topics available"),
                    systemImage: "square.stack.3d.down.right"
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Label("\(scene.visibleClusters)", systemImage: "square.grid.2x2")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(t("可见主题", "Visible Topics"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("\(scene.visibleSegments) \(t("片段", "Segments"))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }

                    if let crossAnalysisSummary = scene.crossAnalysisSummary {
                        Text(crossAnalysisSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let sentimentExplainer = scene.sentimentExplainer {
                        topicsSentimentOverviewCard(sentimentExplainer)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(scene.clusters) { cluster in
                                topicClusterCard(
                                    cluster,
                                    sentimentCluster: scene.sentimentExplainer?.cluster(id: cluster.id),
                                    isSelected: scene.selectedClusterID == cluster.id
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.visible)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    func topicClusterCard(
        _ cluster: TopicClusterSceneItem,
        sentimentCluster: TopicsSentimentClusterExplainer?,
        isSelected: Bool
    ) -> some View {
        Button {
            onAction(.selectCluster(cluster.id))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(cluster.title)
                            .font(.headline)
                            .foregroundStyle(isSelected ? .primary : WordZTheme.textPrimary)
                        Text(cluster.sizeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    if cluster.isOutlier {
                        topicBadge(
                            title: t("离群", "Outlier"),
                            tone: .orange
                        )
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WordZTheme.primary)
                    }
                }

                Text("\(t("当前可见片段", "Visible Segments")) \(cluster.visibleSegments)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                if let sentimentCluster {
                    Text(topicClusterPolaritySummary(sentimentCluster))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let contrastText = cluster.contrastText {
                    Text(contrastText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(cluster.keywordsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !cluster.representativePreview.isEmpty {
                    Text(cluster.representativePreview)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? WordZTheme.primarySurfaceStrong : WordZTheme.cardBackground.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? WordZTheme.primary.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
