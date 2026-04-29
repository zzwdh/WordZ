import SwiftUI

extension TopicsView {
    func topicsListPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: t("主题列表", "Topic List")
        ) {
            if scene.clusters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        t("当前没有可显示的主题", "No topics available"),
                        systemImage: "square.stack.3d.down.right"
                    )
                    .font(.headline)
                    .foregroundStyle(.secondary)

                    Text(t("调整过滤条件或重新运行主题建模后，主题列表会显示在这里。", "Adjust filters or rerun topic modeling to populate this topic list."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    topicsListSummary(scene)

                    List(
                        scene.clusters,
                        selection: Binding(
                            get: { scene.selectedClusterID },
                            set: { clusterID in
                                guard let clusterID else { return }
                                onAction(.selectCluster(clusterID))
                            }
                        )
                    ) { cluster in
                        topicClusterRow(
                            cluster,
                            sentimentCluster: scene.sentimentExplainer?.cluster(id: cluster.id),
                            isSelected: scene.selectedClusterID == cluster.id
                        )
                        .tag(cluster.id)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .scrollIndicators(.visible)
                    .frame(minHeight: 320)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder
    private func topicsListSummary(_ scene: TopicsSceneModel) -> some View {
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
    }

    func topicClusterRow(
        _ cluster: TopicClusterSceneItem,
        sentimentCluster: TopicsSentimentClusterExplainer?,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cluster.title)
                        .font(.headline)
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
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
