import SwiftUI

extension KWICView {
    @ViewBuilder
    var kwicResultsSection: some View {
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
                        WorkbenchMenuPicker(
                            title: t("排序", "Sort"),
                            selection: Binding(
                                get: { scene.sorting.selectedSort },
                                set: { onAction(.changeSort($0)) }
                            ),
                            options: Array(KWICSortMode.allCases)
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
                } trailing: {
                    WorkbenchResultTrailingControls(
                        columnMenuTitle: t("列", "Columns"),
                        keys: KWICColumnKey.allCases,
                        label: { scene.columnTitle(for: $0, mode: languageMode) },
                        isVisible: { scene.column(for: $0)?.isVisible ?? false },
                        onToggle: { onAction(.toggleColumn($0)) },
                        canGoBackward: scene.pagination.canGoBackward,
                        canGoForward: scene.pagination.canGoForward,
                        rangeLabel: scene.pagination.rangeLabel,
                        onPrevious: { onAction(.previousPage) },
                        onNext: { onAction(.nextPage) }
                    )
                }
            }

            WorkbenchTableCard {
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
            }

            if let selectedRow = viewModel.selectedSceneRow {
                kwicSelectedRowSection(selectedRow)
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

    func kwicSelectedRowSection(_ selectedRow: KWICSceneRow) -> some View {
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
                    Menu(t("阅读导出", "Reading Export")) {
                        Button(t("Copy Current · 索引行", "Copy Current · Concordance")) {
                            onAction(.copyCurrent(.concordance))
                        }
                        Button(t("Copy Current · 完整句", "Copy Current · Full Sentence")) {
                            onAction(.copyCurrent(.fullSentence))
                        }
                        Button(t("Copy Current · 引文格式", "Copy Current · Citation")) {
                            onAction(.copyCurrent(.citation))
                        }
                        Divider()
                        Button(t("Copy Visible · 索引行", "Copy Visible · Concordance")) {
                            onAction(.copyVisible(.concordance))
                        }
                        Button(t("Copy Visible · 完整句", "Copy Visible · Full Sentence")) {
                            onAction(.copyVisible(.fullSentence))
                        }
                        Button(t("Copy Visible · 引文格式", "Copy Visible · Citation")) {
                            onAction(.copyVisible(.citation))
                        }
                        Divider()
                        Button(t("Export Current · 索引行", "Export Current · Concordance")) {
                            onAction(.exportCurrent(.concordance))
                        }
                        Button(t("Export Current · 完整句", "Export Current · Full Sentence")) {
                            onAction(.exportCurrent(.fullSentence))
                        }
                        Button(t("Export Current · 引文格式", "Export Current · Citation")) {
                            onAction(.exportCurrent(.citation))
                        }
                        Divider()
                        Button(t("Export Visible · 索引行", "Export Visible · Concordance")) {
                            onAction(.exportVisible(.concordance))
                        }
                        Button(t("Export Visible · 完整句", "Export Visible · Full Sentence")) {
                            onAction(.exportVisible(.fullSentence))
                        }
                        Button(t("Export Visible · 引文格式", "Export Visible · Citation")) {
                            onAction(.exportVisible(.citation))
                        }
                    }
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
}
