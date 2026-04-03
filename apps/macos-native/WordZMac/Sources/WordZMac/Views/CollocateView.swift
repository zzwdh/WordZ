import SwiftUI

struct CollocateView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: CollocatePageViewModel
    let onAction: (CollocatePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        keywordField
                        leftWindowField
                        rightWindowField
                        minFrequencyField
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            keywordField
                            runButton
                        }
                        HStack(spacing: 12) {
                            leftWindowField
                            rightWindowField
                            minFrequencyField
                            Spacer(minLength: 0)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CollocatePreset.allCases) { preset in
                            Button(preset.title(in: languageMode)) {
                                onAction(.applyPreset(preset))
                            }
                            .buttonStyle(.bordered)
                            .help(preset.summary(in: languageMode))
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
                if viewModel.hasPendingRunChanges {
                    WorkbenchIssueBanner(
                        tone: .info,
                        title: t("参数已修改，结果仍基于上次运行", "Inputs changed, results still reflect the previous run"),
                        message: t("你已经修改了节点词、窗口或最小频次。重新运行后，表格和统计指标才会按新参数刷新。", "You changed the keyword, window, or minimum frequency. Run the analysis again to refresh the table and metrics with the new settings.")
                    ) {
                        HStack(spacing: 10) {
                            runButton
                            Text(t("当前结果仍可用于查看旧参数下的排序与细节。", "The current results still describe the previous run and remain available for inspection."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                WorkbenchMethodNoteCard(
                    title: t("搭配指标说明", "How to Read the Association Metrics"),
                    summary: scene.focusMetricSummary,
                    notes: scene.methodNotes
                )

                WorkbenchToolbarSection {
                    WorkbenchResultHeaderRow {
                        Text(t("节点词：", "Node Word: ") + scene.query)
                            .font(.headline)
                        Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow) · " + t("最低共现：", "Min Co-occurrence: ") + "\(scene.minFreq)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } trailing: {
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows) / \(scene.totalRows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if !scene.searchError.isEmpty {
                        Text(scene.searchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    WorkbenchResultControlsRow {
                        HStack(spacing: 12) {
                            Picker(
                                t("重点指标", "Focus Metric"),
                                selection: Binding(
                                    get: { viewModel.focusMetricValue },
                                    set: { onAction(.changeFocusMetric($0)) }
                                )
                            ) {
                                ForEach(CollocateAssociationMetric.allCases) { metric in
                                    Text(metric.title(in: languageMode)).tag(metric)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker(
                                t("排序", "Sort"),
                                selection: Binding(
                                    get: { scene.sorting.selectedSort },
                                    set: { onAction(.changeSort($0)) }
                                )
                            ) {
                                ForEach(CollocateSortMode.allCases) { mode in
                                    Text(mode.title(in: languageMode)).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker(
                                t("页大小", "Page Size"),
                                selection: Binding(
                                    get: { scene.sorting.selectedPageSize },
                                    set: { onAction(.changePageSize($0)) }
                                )
                            ) {
                                ForEach(CollocatePageSize.allCases) { size in
                                    Text(size.title(in: languageMode)).tag(size)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 300)
                        }
                    } trailing: {
                        HStack(spacing: 12) {
                            WorkbenchColumnMenu(
                                title: t("列", "Columns"),
                                keys: CollocateColumnKey.allCases,
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

                WorkbenchSectionCard {
                    NativeTableView(
                        descriptor: scene.table,
                        rows: scene.tableRows,
                        selectedRowID: viewModel.selectedRowID,
                        onSelectionChange: { onAction(.selectRow($0)) },
                        onSortByColumn: { columnID in
                            guard let column = CollocateColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = CollocateColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前搭配词结果没有可显示的词项。", "No collocate rows to display."),
                        accessibilityLabel: t("搭配词结果表格", "Collocate results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }

                if let selectedRow = viewModel.selectedSceneRow {
                    WorkbenchSectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text(selectedRow.word)
                                    .font(.headline)
                                Text("LogDice \(selectedRow.logDiceText) · MI \(selectedRow.mutualInformationText) · T-Score \(selectedRow.tScoreText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Spacer()
                                Text("\(t("共现率", "Rate")) \(selectedRow.rateText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            HStack(spacing: 16) {
                                detailMetric(title: "FreqLR", value: selectedRow.totalText)
                                detailMetric(title: "FreqL", value: selectedRow.leftText)
                                detailMetric(title: "FreqR", value: selectedRow.rightText)
                                detailMetric(title: t("搭配词词频", "Collocate Freq"), value: selectedRow.wordFreqText)
                                detailMetric(title: t("节点词词频", "Keyword Freq"), value: selectedRow.keywordFreqText)
                            }

                            Text(metricInterpretation(for: scene.focusMetric))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                WorkbenchEmptyStateCard(
                    title: t("尚未生成搭配词结果", "No collocate results yet"),
                    systemImage: "point.3.filled.connected.trianglepath.dotted",
                    message: t("输入一个节点词，选择窗口范围，再运行搭配分析。WordZ 会同时提供频次、LogDice、MI 和 T-Score，方便课堂演示和研究判断。", "Enter a node word, choose the window, and run the collocate analysis. WordZ will report raw frequency, LogDice, MI, and T-Score for teaching and research workflows."),
                    suggestions: [
                        t("想先做稳定探索时，用“平衡探索”预设。", "Use the Balanced preset when you want a stable first-pass exploration."),
                        t("如果更关心专属性强的低频搭配，可以再切到“严格关联”。", "Switch to the Strict preset when you want to emphasize exclusive low-frequency associations.")
                    ]
                ) {
                    HStack(spacing: 12) {
                        runButton
                        Text(t("常见做法是先看 LogDice 或 T-Score，再检查原始频次。", "A common workflow is to inspect LogDice or T-Score first, then check raw frequency."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var keywordField: some View {
        TextField(t("节点词", "Node Word"), text: $viewModel.keyword)
            .textFieldStyle(.roundedBorder)
    }

    private var leftWindowField: some View {
        TextField(t("左窗口", "Left Window"), text: $viewModel.leftWindow)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    private var rightWindowField: some View {
        TextField(t("右窗口", "Right Window"), text: $viewModel.rightWindow)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    private var minFrequencyField: some View {
        TextField(t("最低共现", "Min Co-occurrence"), text: $viewModel.minFreq)
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
    }

    private var runButton: some View {
        Button(t("开始统计", "Run Collocate")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private func detailMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func metricInterpretation(for metric: CollocateAssociationMetric) -> String {
        switch metric {
        case .logDice:
            return t("当前重点指标是 LogDice。它通常更适合作为默认排序，因为对高频项更稳健，不会像 MI 那样偏爱极低频词。", "The current focus metric is LogDice. It is usually the best default ranking because it is more stable for higher-frequency items and less biased toward extremely rare words than MI.")
        case .mutualInformation:
            return t("当前重点指标是 MI。它更擅长发现专属性强的稀有搭配，但你需要结合原始频次一起判断。", "The current focus metric is MI. It is good at surfacing exclusive rare collocates, but it should be interpreted together with raw frequency.")
        case .tScore:
            return t("当前重点指标是 T-Score。它更偏向频次高且反复出现的稳定搭配。", "The current focus metric is T-Score. It favors more frequent and repeatedly attested stable collocates.")
        case .rate:
            return t("当前重点指标是共现率。它适合快速浏览节点词周边最常见的搭配。", "The current focus metric is Rate. It is useful for quickly browsing the most common neighbors around the keyword.")
        case .frequency:
            return t("当前重点指标是共现频次。它适合做粗排，但最好再结合关联度指标一起解释。", "The current focus metric is raw co-occurrence frequency. It works well for coarse ranking, but it is best interpreted together with association measures.")
        }
    }
}
