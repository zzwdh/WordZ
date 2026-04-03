import SwiftUI

struct KWICView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: KWICPageViewModel
    let onAction: (KWICPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        keywordField
                        leftWindowField
                        rightWindowField
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
                        Text(t("关键词：", "Keyword: ") + scene.query)
                            .font(.headline)
                        Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow)")
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

                    if let selectedRow = viewModel.selectedSceneRow {
                        HStack(spacing: 8) {
                            Label(t("定位源", "Locator Source"), systemImage: "scope")
                                .font(.caption.weight(.semibold))
                            Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1) · " + t("节点词", "Node") + " \(selectedRow.keyword)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                        }
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
                        }
                    } trailing: {
                        HStack(spacing: 12) {
                            WorkbenchColumnMenu(
                                title: t("列", "Columns"),
                                keys: KWICColumnKey.allCases,
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
                        onDoubleClick: { onAction(.activateRow($0)) },
                        onSortByColumn: { columnID in
                            guard let column = KWICColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = KWICColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        allowsMultipleSelection: false,
                        emptyMessage: t("当前 KWIC 结果没有可显示的行。", "No KWIC rows to display."),
                        accessibilityLabel: "KWIC",
                        activationHint: t("使用方向键浏览结果，按 Return 或空格可定位当前选中行。", "Use arrow keys to browse results, then press Return or Space to locate the selected row.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }

                if let selectedRow = viewModel.selectedSceneRow {
                    WorkbenchSectionCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text(t("研究阅读视图", "Research Reading View"))
                                    .font(.headline)
                                Spacer()
                                Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            WorkbenchConcordanceLineView(
                                leftContext: selectedRow.leftContext,
                                keyword: selectedRow.keyword,
                                rightContext: selectedRow.rightContext
                            )

                            Text(selectedRow.concordanceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            HStack(spacing: 12) {
                                WorkbenchCopyTextButton(
                                    title: t("复制引文", "Copy Citation"),
                                    text: selectedRow.citationText
                                )
                                Button {
                                    onAction(.activateRow(selectedRow.id))
                                } label: {
                                    Label(t("发送到定位器", "Send to Locator"), systemImage: "scope")
                                }
                                Spacer()
                            }
                        }
                    }
                }
            } else {
                WorkbenchEmptyStateCard(
                    title: t("尚未生成 KWIC 结果", "No KWIC results yet"),
                    systemImage: "text.magnifyingglass",
                    message: t("输入检索词并运行后，这里会显示可阅读、可复制、可继续定位的索引行。", "Run a keyword search to see concordance lines that are ready for reading, citation copying, and follow-up locating."),
                    suggestions: [
                        t("较短的窗口更适合课堂演示，较长的窗口更适合研究解读。", "Shorter windows work well for teaching demos, while longer windows help with research interpretation."),
                        t("双击任意索引行或使用“发送到定位器”可继续查看句内位置。", "Double-click any row or use Send to Locator to continue from that concordance line.")
                    ]
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
        TextField(t("检索词", "Keyword"), text: $viewModel.keyword)
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

    private var runButton: some View {
        Button(t("开始检索", "Run KWIC")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
