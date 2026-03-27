import SwiftUI

struct WordView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: WordPageViewModel
    let onAction: (WordPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("词表", "Word"), subtitle: t("在统计结果上继续做筛选、停用词和分页浏览", "Filter, paginate, and apply stopwords on top of stats results")) {
                Button(t("开始统计", "Run Stats")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
            }

            WorkbenchToolbarSection {
                TextField(t("搜索词（留空显示全部）", "Search term (leave blank for all)"), text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                SearchOptionTogglesView(options: $viewModel.searchOptions)
                StopwordControlsView(
                    filter: $viewModel.stopwordFilter,
                    isEditorPresented: $viewModel.isEditingStopwords
                )
            }

            if let scene = viewModel.scene {
                WorkbenchToolbarSection {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scene.query.isEmpty ? t("显示全部词项", "Showing all terms") : t("过滤词：", "Filter: ") + scene.query)
                                .font(.headline)
                            Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                            ForEach(WordSortMode.allCases) { mode in
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
                            ForEach(WordPageSize.allCases) { size in
                                Text(size.title(in: languageMode)).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        WorkbenchColumnMenu(
                            title: t("列", "Columns"),
                            keys: WordColumnKey.allCases,
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
                            guard let column = WordColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = WordColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前词表结果没有可显示的词项。", "No word rows to display."),
                        accessibilityLabel: t("词表结果表格", "Word results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成词表结果", "No word results yet"),
                    systemImage: "character.book.closed",
                    description: Text(t("打开语料后开始统计。词表视图会基于词频结果提供独立筛选。", "Open a corpus and run stats. The Word view adds its own filters on top of the frequency results."))
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
}
