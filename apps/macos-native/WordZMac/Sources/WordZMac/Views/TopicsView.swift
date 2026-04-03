import SwiftUI

struct TopicsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: TopicsPageViewModel
    let onAction: (TopicsPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        queryField
                        minTopicSizeField
                        outlierToggle
                        runButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            queryField
                            runButton
                        }
                        HStack(spacing: 12) {
                            minTopicSizeField
                            outlierToggle
                            Spacer(minLength: 0)
                        }
                    }
                }

                SearchOptionTogglesView(options: $viewModel.searchOptions)
                StopwordControlsView(
                    filter: $viewModel.stopwordFilter,
                    isEditorPresented: $viewModel.isEditingStopwords
                )
            }

            if let scene = viewModel.scene {
                if scene.usesFallbackProvider {
                    WorkbenchIssueBanner(
                        tone: .warning,
                        title: t("主题模型已切换到稳定兜底模式", "Topics model is using a stable fallback mode"),
                        message: t(
                            "当前系统英文句向量不可用，因此 Topics 结果会退化为探索性近似结果；不过现在这个兜底模式已经保证跨启动稳定。",
                            "The system English sentence embedding is unavailable, so Topics results are using an approximate fallback mode. The fallback is now stable across launches, but quality may be lower."
                        )
                    )
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    WorkbenchMetricCard(
                        title: t("模型来源", "Model Provider"),
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
                        HStack(spacing: 12) {
                            Picker(
                                t("排序", "Sort"),
                                selection: Binding(
                                    get: { scene.controls.selectedSort },
                                    set: { onAction(.changeSort($0)) }
                                )
                            ) {
                                ForEach(TopicSegmentSortMode.allCases) { mode in
                                    Text(mode.title(in: languageMode)).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker(
                                t("页大小", "Page Size"),
                                selection: Binding(
                                    get: { scene.controls.selectedPageSize },
                                    set: { onAction(.changePageSize($0)) }
                                )
                            ) {
                                ForEach(TopicsPageSize.allCases) { size in
                                    Text(size.title(in: languageMode)).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)
                        }
                    } trailing: {
                        HStack(spacing: 12) {
                            Menu(t("导出", "Export")) {
                                Button(t("导出主题摘要", "Export Topics Summary")) { onAction(.exportSummary) }
                                    .disabled(scene.summaryExportSnapshot == nil)
                                Button(t("导出主题片段", "Export Topic Segments")) { onAction(.exportSegments) }
                                    .disabled(scene.segmentsExportSnapshot == nil)
                            }

                            WorkbenchColumnMenu(
                                title: t("列", "Columns"),
                                keys: TopicsColumnKey.allCases,
                                label: { scene.columnTitle(for: $0, mode: languageMode) },
                                isVisible: { scene.column(for: $0)?.isVisible ?? false },
                                onToggle: { onAction(.toggleColumn($0)) }
                            )

                            WorkbenchPaginationControls(
                                canGoBackward: scene.pagination.canGoBackward,
                                canGoForward: scene.pagination.canGoForward,
                                rangeLabel: scene.pagination.rangeLabel,
                                onPrevious: { onAction(.previousPage) },
                                onNext: { onAction(.nextPage) }
                            )
                        }
                    }
                }

                HSplitView {
                    WorkbenchPaneCard(
                        title: t("主题列表", "Topic List")
                    ) {
                        if scene.clusters.isEmpty {
                            ContentUnavailableView(
                                t("当前没有可显示的主题", "No topics available"),
                                systemImage: "square.stack.3d.down.right"
                            )
                        } else {
                            List(
                                scene.clusters,
                                selection: Binding(
                                    get: {
                                        guard let selectedClusterID = scene.selectedClusterID else { return Set<String>() }
                                        return [selectedClusterID]
                                    },
                                    set: { nextSelection in
                                        guard let clusterID = nextSelection.first else { return }
                                        onAction(.selectCluster(clusterID))
                                    }
                                )
                            ) { cluster in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(cluster.title)
                                            .font(.headline)
                                        if cluster.isOutlier {
                                            Text(t("离群", "Outlier"))
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(Color.orange.opacity(0.18), in: Capsule())
                                        }
                                        Spacer(minLength: 8)
                                        Text(cluster.sizeText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(t("当前可见片段", "Visible Segments")) \(cluster.visibleSegments)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
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
                                .padding(.vertical, 4)
                                .tag(cluster.id)
                            }
                            .listStyle(.inset)
                        }
                    }
                    .frame(minWidth: 260)

                    WorkbenchPaneCard(
                        title: scene.selectedCluster?.title ?? t("主题详情", "Topic Details"),
                        subtitle: scene.selectedCluster?.summary
                    ) {
                        if let selectedCluster = scene.selectedCluster {
                            VStack(alignment: .leading, spacing: 14) {
                                if selectedCluster.keywords.isEmpty {
                                    Text(t("当前主题暂无可展示关键词。", "No keywords are available for this topic yet."))
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(t("关键词", "Keywords"))
                                            .font(.headline)
                                        FlowLayout(data: selectedCluster.keywords) { keyword in
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(keyword.term)
                                                    .font(.callout.weight(.medium))
                                                Text(keyword.scoreText)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView(
                                t("尚未选中主题", "No topic selected"),
                                systemImage: "point.bottomleft.forward.to.point.topright.scurvepath"
                            )
                        }
                    }
                    .frame(minWidth: 320)

                    WorkbenchPaneCard(
                        title: t("主题片段", "Topic Segments")
                    ) {
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .layoutPriority(1)
                    }
                    .frame(minWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    t("尚未生成 Topics 结果", "No Topics results yet"),
                    systemImage: "square.stack.3d.up"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private var queryField: some View {
        TextField(
            t("搜索主题或片段（留空显示全部）", "Search topics or segments (leave blank for all)"),
            text: $viewModel.query
        )
        .textFieldStyle(.roundedBorder)
    }

    private var minTopicSizeField: some View {
        TextField(t("最小主题大小", "Min Topic Size"), text: $viewModel.minTopicSize)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
    }

    private var outlierToggle: some View {
        Toggle(t("显示离群点", "Show Outliers"), isOn: $viewModel.includeOutliers)
            .toggleStyle(.checkbox)
    }

    private var runButton: some View {
        Button(t("开始建模", "Run Topics")) {
            onAction(.run)
        }
        .buttonStyle(.borderedProminent)
    }

    private func providerLabel(for scene: TopicsSceneModel) -> String {
        if scene.usesFallbackProvider {
            return t("稳定兜底", "Stable Fallback")
        }
        switch scene.modelProvider {
        case "system-sentence-embedding":
            return t("系统句向量", "System Embedding")
        case "hashed-fallback":
            return t("稳定兜底", "Stable Fallback")
        default:
            return scene.modelProvider
        }
    }
}

private struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
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
