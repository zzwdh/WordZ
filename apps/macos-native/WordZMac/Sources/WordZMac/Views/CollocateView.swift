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

                SearchOptionTogglesView(options: $viewModel.searchOptions)
                StopwordControlsView(
                    filter: $viewModel.stopwordFilter,
                    isEditorPresented: $viewModel.isEditingStopwords
                )
            }

            if let scene = viewModel.scene {
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
            } else {
                ContentUnavailableView(
                    t("尚未生成搭配词结果", "No collocate results yet"),
                    systemImage: "point.3.filled.connected.trianglepath.dotted"
                )
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

}
