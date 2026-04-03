import SwiftUI

struct NgramView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: NgramPageViewModel
    let onAction: (NgramPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        searchField
                        ngramSizeField
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            searchField
                            runButton
                        }
                        HStack(spacing: 12) {
                            ngramSizeField
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
                WorkbenchToolbarSection {
                    WorkbenchResultHeaderRow {
                        Text("\(scene.n)-Gram")
                            .font(.headline)
                        Text(scene.query.isEmpty ? t("显示全部结果", "Showing all results") : t("过滤词：", "Filter: ") + scene.query)
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
                                ForEach(NgramSortMode.allCases) { mode in
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
                                ForEach(NgramPageSize.allCases) { size in
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
                                keys: NgramColumnKey.allCases,
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
                        onSortByColumn: { columnID in
                            guard let column = NgramColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = NgramColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前 N-Gram 结果没有可显示的词串。", "No N-Gram rows to display."),
                        accessibilityLabel: t("N-Gram 结果表格", "N-Gram results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成 N-Gram 结果", "No N-Gram results yet"),
                    systemImage: "textformat.abc.dottedunderline"
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
        TextField(t("搜索词（留空显示全部）", "Search term (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
    }

    private var ngramSizeField: some View {
        TextField(t("N 值", "N size"), text: $viewModel.ngramSize)
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
    }

    private var runButton: some View {
        Button(t("开始统计", "Run N-Gram")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
