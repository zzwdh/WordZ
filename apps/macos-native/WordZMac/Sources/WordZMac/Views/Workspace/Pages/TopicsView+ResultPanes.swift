import SwiftUI

extension TopicsView {
    func topicsSplitView(
        _ scene: TopicsSceneModel,
        availableWidth: CGFloat
    ) -> some View {
        let layout = TopicsPaneLayout.resolve(for: availableWidth)

        return topicsPaneLayout(scene, width: availableWidth, layout: layout)
            .frame(
                maxWidth: .infinity,
                minHeight: layout.preferredHeight,
                idealHeight: layout.preferredHeight,
                maxHeight: layout.preferredHeight,
                alignment: .topLeading
            )
    }

    @ViewBuilder
    private func topicsPaneLayout(
        _ scene: TopicsSceneModel,
        width: CGFloat,
        layout: TopicsPaneLayout
    ) -> some View {
        switch layout {
        case .threeColumn:
            HStack(alignment: .top, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(width: max(280, min(360, width * 0.24)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                topicDetailsPane(scene)
                    .frame(width: max(340, min(440, width * 0.31)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                topicSegmentsPane(scene)
                    .frame(minWidth: max(460, width * 0.36), maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        case .twoColumn:
            HStack(alignment: .top, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(width: max(280, min(360, width * 0.32)), alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)

                VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                    topicDetailsPane(scene)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: layout.detailsPanePreferredHeight,
                            idealHeight: layout.detailsPanePreferredHeight,
                            maxHeight: layout.detailsPanePreferredHeight,
                            alignment: .topLeading
                        )

                    topicSegmentsPane(scene)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        case .stacked:
            VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
                topicsListPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.listPanePreferredHeight,
                        idealHeight: layout.listPanePreferredHeight,
                        maxHeight: layout.listPanePreferredHeight,
                        alignment: .topLeading
                    )

                topicDetailsPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.detailsPanePreferredHeight,
                        idealHeight: layout.detailsPanePreferredHeight,
                        maxHeight: layout.detailsPanePreferredHeight,
                        alignment: .topLeading
                    )

                topicSegmentsPane(scene)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: layout.segmentsPanePreferredHeight,
                        idealHeight: layout.segmentsPanePreferredHeight,
                        maxHeight: layout.segmentsPanePreferredHeight,
                        alignment: .topLeading
                    )
            }
        }
    }

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

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(scene.clusters) { cluster in
                                topicClusterCard(
                                    cluster,
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

    func topicDetailsPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: scene.selectedCluster?.title ?? t("主题详情", "Topic Details"),
            subtitle: scene.selectedCluster?.summary
        ) {
            if let selectedCluster = scene.selectedCluster {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        topicDetailsSummaryStrip(selectedCluster, scene: scene)

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

    func topicSegmentsPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: t("主题片段", "Topic Segments")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.selectedCluster?.title ?? t("全部主题片段", "All Topic Segments"))
                            .font(.headline)
                        Text(scene.pagination.rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 12)
                    WorkbenchPinnedHeaderToggle()
                }

                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    onSortByColumn: { columnID in
                        guard let column = TopicsColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = TopicsColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前主题没有可显示的片段。", "No topic segments are available to display."),
                    accessibilityLabel: t("Topics 片段结果表格", "Topics segments results table"),
                    activationHint: t("使用方向键浏览主题片段。", "Use arrow keys to browse topic segments.")
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 320,
                    idealHeight: WorkbenchTablePreferences.defaultTableHeight,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(data) { item in
                content(item)
            }
        }
    }
}

private extension TopicsView {
    func topicClusterCard(
        _ cluster: TopicClusterSceneItem,
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

    func topicBadge(title: String, tone: TopicBadgeTone) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.background, in: Capsule())
    }
}

private enum TopicBadgeTone {
    case blue
    case orange
    case secondary

    var foreground: Color {
        switch self {
        case .blue:
            return WordZTheme.primary
        case .orange:
            return .orange
        case .secondary:
            return .secondary
        }
    }

    var background: Color {
        switch self {
        case .blue:
            return WordZTheme.primary.opacity(0.12)
        case .orange:
            return Color.orange.opacity(0.16)
        case .secondary:
            return Color.white.opacity(0.06)
        }
    }
}

enum TopicsPaneLayout: Equatable {
    case threeColumn
    case twoColumn
    case stacked

    var preferredHeight: CGFloat {
        switch self {
        case .threeColumn:
            return 760
        case .twoColumn:
            return 860
        case .stacked:
            return 1_220
        }
    }

    var listPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn, .twoColumn:
            return preferredHeight
        case .stacked:
            return 320
        }
    }

    var detailsPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn:
            return preferredHeight
        case .twoColumn:
            return 320
        case .stacked:
            return 360
        }
    }

    var segmentsPanePreferredHeight: CGFloat {
        switch self {
        case .threeColumn, .twoColumn:
            return preferredHeight
        case .stacked:
            return 520
        }
    }

    static func resolve(for width: CGFloat) -> TopicsPaneLayout {
        switch width {
        case ..<1080:
            return .stacked
        case ..<1500:
            return .twoColumn
        default:
            return .threeColumn
        }
    }
}
