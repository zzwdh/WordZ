import SwiftUI

struct KWICView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: KWICPageViewModel
    let onAction: (KWICPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: "KWIC", subtitle: t("关键词在上下文中的分布与原句入口", "Keyword-in-context results with a direct path to the source sentence")) {
                Button(t("开始检索", "Run KWIC")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
            }

            WorkbenchToolbarSection {
                HStack(spacing: 12) {
                    TextField(t("检索词", "Keyword"), text: $viewModel.keyword)
                        .textFieldStyle(.roundedBorder)
                    TextField(t("左窗口", "Left Window"), text: $viewModel.leftWindow)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    TextField(t("右窗口", "Right Window"), text: $viewModel.rightWindow)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }

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
                            Text(t("关键词：", "Keyword: ") + scene.query)
                                .font(.headline)
                            Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer(minLength: 12)

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

                    if let selectedRow = viewModel.selectedSceneRow {
                        HStack(spacing: 8) {
                            Label(t("定位源", "Locator Source"), systemImage: "scope")
                                .font(.caption.weight(.semibold))
                            Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1) · " + t("节点词", "Node") + " \(selectedRow.keyword)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                            Text(t("双击表格行可直接切到定位页", "Double-click a row to jump straight to Locator"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    HStack(spacing: 12) {
                        Picker(
                            t("排序", "Sort"),
                            selection: Binding(
                                get: { scene.sorting.selectedSort },
                                set: { onAction(.changeSort($0)) }
                            )
                        ) {
                            ForEach(KWICSortMode.allCases) { mode in
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
                            ForEach(KWICPageSize.allCases) { size in
                                Text(size.title(in: languageMode)).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)

                        WorkbenchColumnMenu(
                            title: t("列", "Columns"),
                            keys: KWICColumnKey.allCases,
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
                        selectedRowID: viewModel.selectedRowID,
                        onSelectionChange: { onAction(.selectRow($0)) },
                        onDoubleClick: { onAction(.activateRow($0)) },
                        onSortByColumn: { columnID in
                            guard let column = KWICColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = KWICColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前 KWIC 结果没有可显示的行。", "No KWIC rows to display."),
                        accessibilityLabel: "KWIC",
                        activationHint: t("使用方向键浏览结果，按 Return 或空格可定位当前选中行。", "Use arrow keys to browse results, then press Return or Space to locate the selected row.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成 KWIC 结果", "No KWIC results yet"),
                    systemImage: "text.magnifyingglass",
                    description: Text(t("打开语料后输入关键词，即可运行最小原生版 KWIC。", "Open a corpus, enter a keyword, and run KWIC."))
                )
            }
        }
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
