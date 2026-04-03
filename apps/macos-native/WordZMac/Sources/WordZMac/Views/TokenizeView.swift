import SwiftUI

struct TokenizeView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: TokenizePageViewModel
    let onAction: (TokenizePageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        searchField
                        actionButtons
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        searchField
                        HStack(spacing: 12) {
                            actionButtons
                            Spacer(minLength: 0)
                        }
                    }
                }
                SearchOptionTogglesView(options: $viewModel.searchOptions)
                StopwordControlsView(
                    filter: $viewModel.stopwordFilter,
                    isEditorPresented: $viewModel.isEditingStopwords
                )
                Text(t("分词基于 Apple NaturalLanguage 的句子切分与词切分；仅保留包含字母或数字的片段，规范词统一转为小写。", "Tokenization uses Apple NaturalLanguage for sentence and word segmentation; only segments containing letters or digits are kept, and normalized tokens are lowercased."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let scene = viewModel.scene {
                WorkbenchToolbarSection {
                    WorkbenchResultHeaderRow {
                        Text(scene.query.isEmpty ? t("显示全部 token", "Showing all tokens") : t("过滤 token：", "Filter: ") + scene.query)
                            .font(.headline)
                        Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let selectedRow = viewModel.selectedSceneRow {
                            Text(t("当前句子：", "Current sentence: ") + selectedRow.sentenceText)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        if !scene.searchError.isEmpty {
                            Text(scene.searchError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } trailing: {
                        Text("\(t("显示", "Showing")) \(scene.visibleTokens) / \(scene.filteredTokens)（\(t("总计", "Total")) \(scene.totalTokens)）")
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
                                ForEach(TokenizeSortMode.allCases) { mode in
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
                                ForEach(TokenizePageSize.allCases) { size in
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
                                keys: TokenizeColumnKey.allCases,
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

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 12)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(scene.metrics) { item in
                        WorkbenchMetricCard(title: item.title, value: item.value)
                    }
                }

                WorkbenchSectionCard {
                    NativeTableView(
                        descriptor: scene.table,
                        rows: scene.tableRows,
                        selectedRowID: viewModel.selectedRowID,
                        onSelectionChange: { onAction(.selectRow($0)) },
                        onSortByColumn: { columnID in
                            guard let column = TokenizeColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = TokenizeColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前分词结果没有可显示的 token。", "No token rows to display."),
                        accessibilityLabel: t("分词结果表格", "Tokenization results table"),
                        activationHint: t("使用方向键浏览分词结果。", "Use arrow keys to browse tokenization results.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成分词结果", "No tokenization results yet"),
                    systemImage: "text.word.spacing"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private var searchField: some View {
        TextField(t("搜索 token（留空显示全部）", "Search tokens (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
            .layoutPriority(1)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(t("开始分词", "Run Tokenize")) { onAction(.run) }
                .buttonStyle(.borderedProminent)
            Button(t("导出 UTF-8 TXT", "Export UTF-8 TXT")) { onAction(.exportText) }
                .buttonStyle(.bordered)
                .disabled(viewModel.exportDocument == nil)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
