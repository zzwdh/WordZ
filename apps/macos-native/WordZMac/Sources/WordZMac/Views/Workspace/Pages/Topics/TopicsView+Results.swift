import SwiftUI

extension TopicsView {
    func topicsResults(
        _ scene: TopicsSceneModel,
        availableWidth: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: WordZTheme.sectionSpacing) {
            if scene.usesFallbackProvider {
                WorkbenchIssueBanner(
                    tone: .warning,
                    title: t("主题分析已切换到备用方式", "Topic analysis is using a backup method"),
                    message: t(
                        "当前系统分析方式不可用，因此主题结果会使用近似方式生成；结果可用于探索，但建议结合原文复核。",
                        "The system analysis method is unavailable, so topic results are generated with an approximate method. Use them for exploration and review the source text when needed."
                    )
                )
            }

            if !scene.warnings.isEmpty {
                topicsWarningsSection(scene.warnings)
            }

            topicsMetricGrid(scene)

            topicsToolbar(scene)
            topicsSplitView(scene, availableWidth: availableWidth)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    func topicsMetricGrid(_ scene: TopicsSceneModel) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
            WorkbenchMetricCard(
                title: t("分析方式", "Analysis Method"),
                value: providerLabel(for: scene),
                subtitle: scene.modelVersion
            )
            WorkbenchMetricCard(
                title: t("已聚类片段", "Clustered Segments"),
                value: "\(scene.clusteredSegments)",
                subtitle: "\(t("总片段", "Total Segments")) \(scene.totalSegments)"
            )
            WorkbenchMetricCard(
                title: t("离群片段", "Outliers"),
                value: "\(scene.outlierCount)",
                subtitle: "\(t("显示主题", "Visible Topics")) \(scene.visibleClusters)"
            )
            WorkbenchMetricCard(
                title: t("当前片段", "Visible Segments"),
                value: "\(scene.visibleSegments)",
                subtitle: scene.pagination.rangeLabel
            )
        }
    }

    func topicsWarningsSection(_ warnings: [String]) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(t("结果提示", "Result Notes"))
                    .font(.headline)
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    func topicsToolbar(_ scene: TopicsSceneModel) -> some View {
        WorkbenchToolbarSection {
            WorkbenchResultHeaderRow {
                Text(
                    scene.selectedCluster?.title
                    ?? t("选择一个主题查看详情", "Select a topic to inspect details")
                )
                .font(.headline)
                Text("\(t("主题", "Topics")) \(scene.visibleClusters) / \(scene.totalClusters) · \(t("片段", "Segments")) \(scene.visibleSegments) / \(scene.totalSegments)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } trailing: {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(scene.modelVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(scene.selectedCluster?.summary ?? t("当前显示全部匹配的主题片段。", "Showing all matching topic segments."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            WorkbenchResultControlsRow {
                WorkbenchTablePrimaryControls(
                    sortTitle: t("排序", "Sort"),
                    selectedSort: Binding(
                        get: { scene.controls.selectedSort },
                        set: { onAction(.changeSort($0)) }
                    ),
                    sortOptions: Array(TopicSegmentSortMode.allCases),
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.controls.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.totalSegments,
                    pageSizeLabel: { $0.title(in: languageMode) }
                )
            } trailing: {
                WorkbenchTableSecondaryControls(
                    columnMenuTitle: t("列", "Columns"),
                    keys: TopicsColumnKey.allCases,
                    label: { scene.columnTitle(for: $0, mode: languageMode) },
                    isVisible: { scene.column(for: $0)?.isVisible ?? false },
                    onToggle: { onAction(.toggleColumn($0)) },
                    canGoBackward: scene.pagination.canGoBackward,
                    canGoForward: scene.pagination.canGoForward,
                    rangeLabel: scene.pagination.rangeLabel,
                    onPrevious: { onAction(.previousPage) },
                    onNext: { onAction(.nextPage) },
                    leading: {
                        Menu(t("导出", "Export")) {
                            Button(t("导出主题摘要", "Export Topics Summary")) { onAction(.exportSummary) }
                                .disabled(scene.summaryExportSnapshot == nil)
                            Button(t("导出主题片段", "Export Topic Segments")) { onAction(.exportSegments) }
                                .disabled(scene.segmentsExportSnapshot == nil)
                        }
                    }
                )
            }

            AnnotationFilterStatusStrip(
                state: viewModel.annotationState,
                resultCount: scene.visibleSegments
            )
        }
    }
}
