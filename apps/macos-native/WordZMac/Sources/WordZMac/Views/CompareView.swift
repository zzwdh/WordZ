import SwiftUI

struct CompareView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: ComparePageViewModel
    let onAction: (ComparePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                Text(t("选择至少 2 条语料", "Select at least 2 corpora"))
                    .font(.headline)
                if viewModel.selectionItems.isEmpty {
                    Text(t("当前没有可用于对比的已保存语料。", "No saved corpora are available for comparison."))
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.selectionItems) { item in
                                Toggle(isOn: Binding(
                                    get: { viewModel.isCorpusSelected(item.id) },
                                    set: { _ in onAction(.toggleCorpusSelection(item.id)) }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.medium))
                                        Text(item.subtitle.isEmpty ? t("未分类", "Unfiled") : item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .padding(10)
                                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        searchField
                        referencePicker
                        selectedCountLabel
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            searchField
                            runButton
                        }
                        HStack(spacing: 12) {
                            referencePicker
                            selectedCountLabel
                        }
                    }
                }

                Text(t("自动模式会按每个词项选择主导语料；固定参考语料更适合做可复现的对比实验。", "Automatic mode chooses the dominant corpus per word; a fixed reference corpus is better for reproducible comparison studies."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SearchOptionTogglesView(options: $viewModel.searchOptions)
                StopwordControlsView(
                    filter: $viewModel.stopwordFilter,
                    isEditorPresented: $viewModel.isEditingStopwords
                )
            }

            if let scene = viewModel.scene {
                if !scene.corpusSummaries.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(scene.corpusSummaries) { corpus in
                                compareSummaryCard(corpus)
                            }
                        }
                    }
                }

                WorkbenchMethodNoteCard(
                    title: t("结果说明", "How to Read These Results"),
                    summary: scene.methodSummary,
                    notes: scene.methodNotes
                )

                WorkbenchToolbarSection {
                    WorkbenchResultHeaderRow {
                        Text(scene.query.isEmpty ? t("显示全部对比词项", "Showing all comparison rows") : t("过滤词：", "Filter: ") + scene.query)
                            .font(.headline)
                        Text(scene.referenceSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(t("Keyness 使用带方向的 log-likelihood，并同时给出 Log Ratio 作为效应值。", "Keyness uses signed log-likelihood and reports Log Ratio as the effect size."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !scene.searchError.isEmpty {
                            Text(scene.searchError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } trailing: {
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    WorkbenchResultControlsRow {
                        HStack(spacing: 12) {
                            Picker(
                                t("排序", "Sort"),
                                selection: Binding(
                                    get: { scene.sorting.selectedSort },
                                    set: { onAction(.changeSort($0)) }
                                )
                            ) {
                                ForEach(CompareSortMode.allCases) { mode in
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
                                ForEach(ComparePageSize.allCases) { size in
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
                                keys: CompareColumnKey.allCases,
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
                            guard let column = CompareColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = CompareColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        allowsMultipleSelection: false,
                        emptyMessage: t("当前对比结果没有可显示的词项。", "No comparison rows to display."),
                        accessibilityLabel: t("对比结果表格", "Compare results table"),
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
                                Text("Keyness \(selectedRow.keynessText) · Log Ratio \(selectedRow.effectText) · p \(selectedRow.pValueText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Spacer()
                                Text("\(t("主导语料", "Dominant")): \(selectedRow.dominantCorpus)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 16) {
                                compareDetailMetric(t("覆盖", "Spread"), value: selectedRow.spreadText)
                                compareDetailMetric(t("总频", "Total"), value: selectedRow.totalText)
                                compareDetailMetric(t("差异", "Range"), value: selectedRow.rangeText)
                                compareDetailMetric(t("参考标准频次", "Reference Norm Freq"), value: selectedRow.referenceNormFreqText)
                            }

                            HStack(spacing: 16) {
                                compareDetailMetric(t("参考语料", "Reference Corpus"), value: selectedRow.referenceLabelText)
                                compareDetailMetric(t("主导语料", "Dominant Corpus"), value: selectedRow.dominantCorpus)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(t("完整分布", "Full Distribution"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView {
                                    Text(selectedRow.distributionText)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(minHeight: 54, maxHeight: 96)
                            }
                        }
                    }
                }
            } else {
                WorkbenchEmptyStateCard(
                    title: t("尚未生成对比结果", "No comparison results yet"),
                    systemImage: "square.2.layers.3d.top.filled",
                    message: t("先选择至少两条语料，再运行对比。系统会用 Keyness 和 Log Ratio 帮你判断哪些词在哪个语料中更突出。", "Select at least two corpora and run Compare. WordZ will use Keyness and Log Ratio to show which words are most distinctive in each corpus."),
                    suggestions: [
                        t("优先选择体裁或来源差异明显的语料，结果更容易解释。", "Start with corpora that differ clearly by genre or source so the contrast is easier to interpret."),
                        t("需要做课堂演示时，先保留默认搜索设置，再逐步加入停用词过滤。", "For teaching demos, keep the default search settings first, then add stopword filtering step by step.")
                    ]
                ) {
                    HStack(spacing: 12) {
                        runButton
                        Text(t("至少选择 2 条语料后才可运行。", "Run becomes available after at least two corpora are selected."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private var searchField: some View {
        TextField(t("过滤词（留空显示全部）", "Filter term (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
    }

    private var referencePicker: some View {
        Picker(
            t("参考语料", "Reference Corpus"),
            selection: Binding(
                get: { viewModel.selectedReferenceOptionID },
                set: { onAction(.changeReferenceCorpus($0.isEmpty ? nil : $0)) }
            )
        ) {
            ForEach(viewModel.referenceOptions) { option in
                Text(option.title).tag(option.id)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 220, alignment: .leading)
        .disabled(viewModel.referenceOptions.isEmpty)
    }

    private var selectedCountLabel: some View {
        Text("\(t("已选", "Selected")) \(viewModel.selectedCorpusCount) \(t("条", "items"))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var runButton: some View {
        Button(t("开始对比", "Run Compare")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedCorpusCount < 2)
    }

    private func compareSummaryCard(_ corpus: CompareCorpusSummarySceneItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(corpus.title)
                .font(.headline)
            Text(corpus.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Token \(corpus.tokenCountText) · Type \(corpus.typeCountText)")
                .font(.caption)
                .monospacedDigit()
            Text("TTR \(corpus.ttrText) · STTR \(corpus.sttrText)")
                .font(.caption)
                .monospacedDigit()
            Text("Top \(corpus.topWordText)")
                .font(.caption)
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compareDetailMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
