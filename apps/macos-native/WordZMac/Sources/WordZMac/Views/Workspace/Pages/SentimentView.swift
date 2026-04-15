import Charts
import SwiftUI

struct SentimentView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: SentimentPageViewModel
    let isBusy: Bool
    let onAction: (SentimentPageAction) -> Void

    private let summaryColumns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        UtilityPageScaffold(
            title: t("情感", "Sentiment"),
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                sentimentControlsSection
            } scrolling: {
                sentimentResultsSection
            }
        }
    }

    private var sentimentControlsSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    WorkbenchAdaptiveControls {
                        HStack(spacing: 12) {
                            sourcePicker
                            unitPicker
                            if viewModel.source == .kwicVisible {
                                contextPicker
                            }
                            if viewModel.showsBackendPicker {
                                backendPicker
                            }
                            presetPicker
                            chartPicker
                        }
                    } compact: {
                        VStack(alignment: .leading, spacing: 12) {
                            sourcePicker
                            unitPicker
                            if viewModel.source == .kwicVisible {
                                contextPicker
                            }
                            if viewModel.showsBackendPicker {
                                backendPicker
                            }
                            HStack(spacing: 12) {
                                presetPicker
                                chartPicker
                            }
                        }
                    }
                } actions: {
                    Button(t("运行情感分析", "Run Sentiment")) {
                        onAction(.run)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                }

                if viewModel.backend == .lexicon {
                    thresholdControls
                } else {
                    Text(t("本地模型使用内置校准，不显示规则阈值。", "The local model uses built-in calibration, so rule thresholds are hidden."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.source == .pastedText {
                    manualTextEditor
                }

                if viewModel.source == .corpusCompare {
                    corpusSelectionSection
                }

                if let backendNotice = viewModel.backendNotice, !backendNotice.isEmpty {
                    Text(backendNotice)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text(methodSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var sentimentResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
                Text(scene.source.title(in: languageMode))
                    .font(.headline)
                Text("\(scene.unit.title(in: languageMode)) · \(scene.backend.title(in: languageMode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } trailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                HStack(spacing: 12) {
                    WorkbenchMenuPicker(
                        title: t("排序", "Sort"),
                        selection: Binding(
                            get: { scene.sorting.selectedSort },
                            set: { onAction(.changeSort($0)) }
                        ),
                        options: SentimentSortMode.allCases
                    ) {
                        $0.title(in: languageMode)
                    }

                    WorkbenchGuardedPageSizePicker(
                        title: t("页大小", "Page Size"),
                        selection: Binding(
                            get: { scene.sorting.selectedPageSize },
                            set: { onAction(.changePageSize($0)) }
                        ),
                        totalRows: scene.filteredRows
                    ) {
                        $0.title(in: languageMode)
                    }
                }
            } trailingControls: {
                HStack(spacing: 12) {
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
            }

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

            WorkbenchPaneCard(
                title: t("分布图", "Distribution"),
                subtitle: chartSubtitle(scene)
            ) {
                chartView(scene)
                    .frame(minHeight: 260)
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

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onSortByColumn: { columnID in
                        guard let column = SentimentColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = SentimentColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前没有可显示的情感结果。", "No sentiment rows to display."),
                    accessibilityLabel: t("情感结果表格", "Sentiment results table")
                )
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
                            if selectedRow.mixedEvidence {
                                Text(t("正负证据接近，已按中性处理。", "Positive and negative evidence are mixed, so this row is treated as neutral."))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            if let ruleSummary = selectedRow.diagnostics.ruleSummary,
                               !ruleSummary.isEmpty {
                                Text(ruleSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !selectedRow.diagnostics.scopeNotes.isEmpty {
                                Text(selectedRow.diagnostics.scopeNotes.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            if scene.supportsEvidenceHits, selectedRow.evidence.isEmpty {
                                Text(t("没有命中显著情感证据。", "No salient sentiment evidence was matched."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if scene.supportsEvidenceHits {
                                ForEach(selectedRow.evidence) { hit in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(hit.surface)
                                            .font(.subheadline.weight(.semibold))
                                        Text("base \(format(hit.baseScore)) → \(format(hit.adjustedScore))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        Text(hit.ruleTags.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            } else {
                                modelDiagnosticsSection(for: selectedRow)
                            }
                        }
                    }
                }
            }

            WorkbenchToolbarSection {
                HStack(spacing: 12) {
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

    private var sourcePicker: some View {
        WorkbenchMenuPicker(
            title: t("来源", "Source"),
            selection: Binding(
                get: { viewModel.source },
                set: { onAction(.changeSource($0)) }
            ),
            options: SentimentInputSource.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var unitPicker: some View {
        WorkbenchMenuPicker(
            title: t("单位", "Unit"),
            selection: Binding(
                get: { viewModel.unit },
                set: { onAction(.changeUnit($0)) }
            ),
            options: viewModel.supportedUnits
        ) {
            $0.title(in: languageMode)
        }
    }

    private var contextPicker: some View {
        WorkbenchMenuPicker(
            title: t("上下文", "Context"),
            selection: Binding(
                get: { viewModel.contextBasis },
                set: { onAction(.changeContextBasis($0)) }
            ),
            options: SentimentContextBasis.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var backendPicker: some View {
        WorkbenchMenuPicker(
            title: t("后端", "Backend"),
            selection: Binding(
                get: { viewModel.backend },
                set: { onAction(.changeBackend($0)) }
            ),
            options: viewModel.availableBackends
        ) {
            $0.title(in: languageMode)
        }
    }

    private var presetPicker: some View {
        WorkbenchMenuPicker(
            title: t("阈值", "Preset"),
            selection: Binding(
                get: { viewModel.thresholdPreset },
                set: { onAction(.changeThresholdPreset($0)) }
            ),
            options: SentimentThresholdPreset.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var chartPicker: some View {
        WorkbenchMenuPicker(
            title: t("图表", "Chart"),
            selection: Binding(
                get: { viewModel.chartKind },
                set: { onAction(.changeChartKind($0)) }
            ),
            options: SentimentChartKind.allCases
        ) {
            $0.title(in: languageMode)
        }
    }

    private var thresholdControls: some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                thresholdSlider(
                    title: t("决策阈值", "Decision"),
                    binding: Binding(
                        get: { viewModel.decisionThreshold },
                        set: { viewModel.decisionThreshold = $0 }
                    ),
                    range: 0.1...0.8
                )
                thresholdSlider(
                    title: t("最小证据", "Evidence"),
                    binding: Binding(
                        get: { viewModel.minimumEvidence },
                        set: { viewModel.minimumEvidence = $0 }
                    ),
                    range: 0.1...2.0
                )
                thresholdSlider(
                    title: t("中性偏置", "Neutral Bias"),
                    binding: Binding(
                        get: { viewModel.neutralBias },
                        set: { viewModel.neutralBias = $0 }
                    ),
                    range: 0.4...1.8
                )
            }
        }
    }

    private func thresholdSlider(
        title: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title): \(format(binding.wrappedValue))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: binding, in: range)
            .frame(maxWidth: 220)
        }
    }

    private var manualTextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("输入英文文本", "Input English Text"))
                .font(.subheadline.weight(.semibold))
            TextEditor(text: Binding(
                get: { viewModel.manualText },
                set: { onAction(.changeManualText($0)) }
            ))
            .font(.body.monospaced())
            .frame(minHeight: 140)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.18))
            )
            Text("\(viewModel.manualTextCharacterCount) \(t("字符", "chars")) · \(viewModel.manualTextSentenceCountEstimate) \(t("句", "sentences"))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var corpusSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("选择目标语料", "Select Target Corpora"))
                .font(.subheadline.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(viewModel.selectionItems) { item in
                    Toggle(
                        isOn: Binding(
                            get: { item.isSelected },
                            set: { _ in onAction(.toggleCorpusSelection(item.id)) }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }

            Picker(
                t("参照语料", "Reference Corpus"),
                selection: Binding(
                    get: { viewModel.selectedReferenceCorpusID },
                    set: { onAction(.changeReferenceCorpus($0.isEmpty ? nil : $0)) }
                )
            ) {
                Text(t("不设参照", "None")).tag("")
                ForEach(viewModel.referenceOptions) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private func chartView(_ scene: SentimentSceneModel) -> some View {
        switch scene.chartKind {
        case .distributionBar:
            Chart(scene.chartSegments) { segment in
                BarMark(
                    x: .value("Label", segment.label.title(in: languageMode)),
                    y: .value("Count", segment.count)
                )
                .foregroundStyle(color(for: segment.label))
            }
            .chartYAxisLabel(t("条数", "Count"))
        case .distributionDonut:
            Chart(scene.chartSegments) { segment in
                SectorMark(
                    angle: .value("Count", segment.count),
                    innerRadius: .ratio(0.58),
                    angularInset: 2
                )
                .foregroundStyle(color(for: segment.label))
                .annotation(position: .overlay) {
                    EmptyView()
                }
            }
        case .trendLine:
            Chart(scene.trendPoints) { point in
                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Net", point.netScore)
                )
                .foregroundStyle(Color.accentColor)
                PointMark(
                    x: .value("Index", point.index),
                    y: .value("Net", point.netScore)
                )
                .foregroundStyle(color(for: point.label))
                .symbolSize(40)
            }
            .chartYAxisLabel("Net")
        }
    }

    @ViewBuilder
    private func exampleSection(title: String, rows: [SentimentSceneRow]) -> some View {
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

    private func chartSubtitle(_ scene: SentimentSceneModel) -> String {
        "\(scene.summary.totalTexts) \(t("条分析单位", "analysis units")) · \(scene.chartKind.title(in: languageMode))"
    }

    private var methodSummary: String {
        "\(t("当前后端", "Selected backend")): \(viewModel.backend.title(in: languageMode)) · neutrality / positivity / negativity"
    }

    private func color(for label: SentimentLabel) -> Color {
        switch label {
        case .positive:
            return .green
        case .neutral:
            return .gray
        case .negative:
            return .red
        }
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func inspectorHeadline(for row: SentimentSceneRow) -> String {
        if let confidence = row.diagnostics.confidence {
            return "\(row.finalLabel.title(in: languageMode)) · \(t("置信度", "Confidence")) \(formatPercent(confidence))"
        }
        return "\(row.finalLabel.title(in: languageMode)) · Net \(format(row.netScore))"
    }

    @ViewBuilder
    private func modelDiagnosticsSection(for row: SentimentSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let confidence = row.diagnostics.confidence {
                Text("\(t("置信度", "Confidence")): \(formatPercent(confidence))")
                    .font(.caption.monospacedDigit())
            }
            if let topMargin = row.diagnostics.topMargin {
                Text("\(t("边际差", "Top Margin")): \(format(topMargin))")
                    .font(.caption.monospacedDigit())
            }
            if let subunitCount = row.diagnostics.subunitCount {
                Text("\(t("聚合子单元", "Aggregated Subunits")): \(subunitCount)")
                    .font(.caption.monospacedDigit())
            }
            if let modelRevision = row.diagnostics.modelRevision, !modelRevision.isEmpty {
                Text("\(t("模型版本", "Model Revision")): \(modelRevision)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let aggregatedFrom = row.diagnostics.aggregatedFrom {
                Text("\(t("聚合方式", "Aggregation")): \(aggregationTitle(for: aggregatedFrom))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func aggregationTitle(for mode: SentimentAggregationMode) -> String {
        switch mode {
        case .direct:
            return t("直接判别", "Direct classification")
        case .sentenceMean:
            return t("句级平均", "Sentence mean")
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
