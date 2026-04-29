import SwiftUI

extension SentimentView {
    @ViewBuilder
    var sentimentResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                annotationState: viewModel.annotationState,
                annotationResultCount: scene.filteredRows,
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                columnKeys: SentimentColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前没有可显示的情感结果。", "No sentiment rows to display."),
                accessibilityLabel: t("情感结果表格", "Sentiment results table")
            ) {
                Text(scene.source.title(in: languageMode))
                    .font(.headline)
                Text("\(scene.unit.title(in: languageMode)) · \(scene.backend.title(in: languageMode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } headerTrailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                WorkbenchTablePrimaryControls(
                    sortTitle: t("排序", "Sort"),
                    selectedSort: Binding(
                        get: { scene.sorting.selectedSort },
                        set: { onAction(.changeSort($0)) }
                    ),
                    sortOptions: SentimentSortMode.allCases,
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.filteredRows,
                    pageSizeLabel: { $0.title(in: languageMode) }
                )
            } secondaryLeadingControls: {
                sentimentFilterControls
            } tableSupplement: {
                LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                    WorkbenchMetricCard(
                        title: t("总条数", "Total Texts"),
                        value: "\(scene.summary.totalTexts)",
                        subtitle: scene.unit.title(in: languageMode)
                    )
                    WorkbenchMetricCard(
                        title: t("积极", "Positive"),
                        value: "\(scene.summary.positiveCount)",
                        subtitle: formatPercent(scene.summary.positiveRatio)
                    )
                    WorkbenchMetricCard(
                        title: t("中性", "Neutral"),
                        value: "\(scene.summary.neutralCount)",
                        subtitle: formatPercent(scene.summary.neutralRatio)
                    )
                    WorkbenchMetricCard(
                        title: t("消极", "Negative"),
                        value: "\(scene.summary.negativeCount)",
                        subtitle: formatPercent(scene.summary.negativeRatio)
                    )
                }

                Text(reviewSummaryLine(scene))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                WorkbenchPaneCard(title: t("分布图", "Distribution"), subtitle: chartSubtitle(scene)) {
                    chartView(scene)
                }

                if !scene.groupSummaries.isEmpty {
                    WorkbenchPaneCard(
                        title: t("分组统计", "Grouped Summaries"),
                        subtitle: t("Target / Reference 或输入源分组统计", "Grouped counts for targets, references, or sources")
                    ) {
                        LazyVGrid(columns: summaryColumns, alignment: .leading, spacing: 12) {
                            ForEach(scene.groupSummaries) { group in
                                WorkbenchMetricCard(
                                    title: group.title,
                                    value: "+\(group.positiveCount) / =\(group.neutralCount) / -\(group.negativeCount)",
                                    subtitle: "\(t("总计", "Total")) \(group.totalTexts)"
                                )
                            }
                        }
                    }
                }
            } paginationFallback: {
                EmptyView()
            }

            WorkbenchPaneCard(
                title: t("示例与证据", "Examples and Evidence"),
                subtitle: t("查看当前结果中的代表性文本与命中证据", "Inspect representative rows and the matched evidence")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    exampleSection(title: SentimentLabel.positive.title(in: languageMode), rows: scene.positiveExamples)
                    exampleSection(title: SentimentLabel.neutral.title(in: languageMode), rows: scene.neutralExamples)
                    exampleSection(title: SentimentLabel.negative.title(in: languageMode), rows: scene.negativeExamples)

                    Divider()

                    if let selectedRow = viewModel.selectedSceneRow {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedRow.text)
                                .font(.headline)
                            Text(inspectorHeadline(for: selectedRow))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            reviewInspectorSection(for: selectedRow)
                            rawEvidenceSection(for: selectedRow, scene: scene)
                        }
                    }
                }
            }

            WorkbenchToolbarSection {
                HStack(spacing: 12) {
                    Button(t("打开原文视图", "Open Source View")) {
                        onAction(.openSourceReader)
                    }
                    .disabled(isBusy || !viewModel.canOpenSelectedRowSourceReader)

                    Button(t("加入摘录", "Add to Clips")) {
                        onAction(.addCurrentRowToEvidenceWorkbench)
                    }
                    .disabled(isBusy || !viewModel.canOpenSelectedRowSourceReader)

                    Button(t("导出摘要 TXT", "Export Summary TXT")) {
                        onAction(.exportSummary)
                    }
                    .disabled(isBusy)

                    Button(t("导出结构化 JSON", "Export Structured JSON")) {
                        onAction(.exportStructuredJSON)
                    }
                    .disabled(isBusy)
                }
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成 Sentiment 结果", "No Sentiment results yet"),
                systemImage: "waveform.path.ecg.text",
                message: t(
                    "选择输入源与分析单位后运行，这里会显示 neutrality / positivity / negativity 的分布、表格和示例。",
                    "Choose an input source and analysis unit, then run to see neutrality / positivity / negativity distributions, tables, and examples."
                )
            )
        }
    }

    var sentimentFilterControls: some View {
        WorkbenchAdaptiveControls {
            HStack(spacing: 12) {
                sentimentLabelFilterPicker
                sentimentFilterTextField
                sentimentReviewFilterPicker
                sentimentReviewStatusFilterPicker
                sentimentHardCasesToggle
            }
        } compact: {
            VStack(alignment: .leading, spacing: 10) {
                sentimentLabelFilterPicker
                    .frame(maxWidth: 340, alignment: .leading)
                sentimentFilterTextField
                    .frame(maxWidth: 280, alignment: .leading)
                HStack(spacing: 10) {
                    sentimentReviewFilterPicker
                    sentimentReviewStatusFilterPicker
                    sentimentHardCasesToggle
                }
            }
        }
    }

    var sentimentLabelFilterPicker: some View {
        Picker(t("筛选", "Filter"), selection: Binding(
            get: { viewModel.labelFilter },
            set: { onAction(.changeLabelFilter($0)) }
        )) {
            Text(t("全部", "All")).tag(Optional<SentimentLabel>.none)
            ForEach(SentimentLabel.allCases) { label in
                Text(label.title(in: languageMode)).tag(Optional(label))
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 340)
    }

    var sentimentFilterTextField: some View {
        TextField(
            t("筛选文本或证据", "Filter text or evidence"),
            text: Binding(
                get: { viewModel.rowFilterQuery },
                set: { onAction(.changeFilterQuery($0)) }
            )
        )
        .textFieldStyle(.roundedBorder)
        .frame(width: 220)
    }

    var sentimentReviewFilterPicker: some View {
        WorkbenchMenuPicker(
            title: t("Review", "Review"),
            selection: Binding(
                get: { viewModel.reviewFilter },
                set: { onAction(.changeReviewFilter($0)) }
            ),
            options: SentimentReviewFilter.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var sentimentReviewStatusFilterPicker: some View {
        WorkbenchMenuPicker(
            title: t("审校状态", "Review Status"),
            selection: Binding(
                get: { viewModel.reviewStatusFilter },
                set: { onAction(.changeReviewStatusFilter($0)) }
            ),
            options: SentimentReviewStatusFilter.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    var sentimentHardCasesToggle: some View {
        Toggle(
            t("仅难例", "Hard Cases"),
            isOn: Binding(
                get: { viewModel.showOnlyHardCases },
                set: { onAction(.toggleShowOnlyHardCases($0)) }
            )
        )
        .toggleStyle(.switch)
    }

    @ViewBuilder
    func exampleSection(title: String, rows: [SentimentSceneRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            if rows.isEmpty {
                Text(t("暂无示例。", "No examples yet."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.text)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("\(row.sourceTitle) · \(row.evidencePreview)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    func reviewSummaryLine(_ scene: SentimentSceneModel) -> String {
        [
            "\(t("已审校", "Reviewed")) \(scene.reviewSummary.reviewedCount)",
            "\(t("人工改标", "Overrides")) \(scene.reviewSummary.overriddenCount)",
            "\(t("确认原判", "Confirmed")) \(scene.reviewSummary.confirmedRawCount)",
            "\(t("待复核难例", "Pending Hard Cases")) \(scene.reviewSummary.pendingHardCaseCount)"
        ]
        .joined(separator: " · ")
    }
}
