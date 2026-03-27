import SwiftUI

struct CompareView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: ComparePageViewModel
    let onAction: (ComparePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("对比", "Compare"), subtitle: t("多语料对照词项分布、范围与主导语料", "Compare distributions, spread, and dominant corpus across multiple corpora")) {
                Button(t("开始对比", "Run Compare")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedCorpusCount < 2)
            }

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

                HStack(spacing: 12) {
                    TextField(t("过滤词（留空显示全部）", "Filter term (leave blank for all)"), text: $viewModel.query)
                        .textFieldStyle(.roundedBorder)
                    Text("\(t("已选", "Selected")) \(viewModel.selectedCorpusCount) \(t("条", "items"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

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

                WorkbenchToolbarSection {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scene.query.isEmpty ? t("显示全部对比词项", "Showing all comparison rows") : t("过滤词：", "Filter: ") + scene.query)
                                .font(.headline)
                            if !scene.searchError.isEmpty {
                                Text(scene.searchError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer(minLength: 12)
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

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

                        WorkbenchColumnMenu(
                            title: t("列", "Columns"),
                            keys: CompareColumnKey.allCases,
                            label: { scene.columnTitle(for: $0, mode: languageMode) },
                            isVisible: { scene.column(for: $0)?.isVisible ?? false },
                            onToggle: { onAction(.toggleColumn($0)) }
                        )

                        Spacer()

                        WorkbenchPaginationControls(
                            canGoBackward: scene.pagination.canGoBackward,
                            canGoForward: scene.pagination.canGoForward,
                            rangeLabel: scene.pagination.rangeLabel,
                            onPrevious: { onAction(.previousPage) },
                            onNext: { onAction(.nextPage) }
                        )
                    }
                }

                WorkbenchSectionCard {
                    NativeTableView(
                        descriptor: scene.table,
                        rows: scene.tableRows,
                        onSortByColumn: { columnID in
                            guard let column = CompareColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = CompareColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前对比结果没有可显示的词项。", "No comparison rows to display."),
                        accessibilityLabel: t("对比结果表格", "Compare results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成对比结果", "No comparison results yet"),
                    systemImage: "square.2.layers.3d.top.filled",
                    description: Text(t("先在上方选择至少两条语料，再开始对比。", "Select at least two corpora above, then run compare."))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
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

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
