import SwiftUI

extension LocatorView {
    @ViewBuilder
    var locatorResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchToolbarSection {
                WorkbenchResultHeaderRow {
                    Text(t("句", "Sentence") + " \(scene.source.sentenceId + 1) · " + t("节点词", "Node") + " \(scene.source.keyword)")
                        .font(.headline)
                    if let selectedRow = viewModel.selectedSceneRow {
                        Text(t("当前选择：句", "Selected: sentence") + " \(selectedRow.sentenceId + 1) · \(selectedRow.nodeWord.isEmpty ? t("无节点词", "No node") : selectedRow.nodeWord)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(selectedRow.text)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                } trailing: {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)（\(t("共", "Across")) \(scene.sentenceCount) \(t("句", "sentences"))）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchResultControlsRow {
                    WorkbenchGuardedPageSizePicker(
                        title: t("页大小", "Page Size"),
                        selection: Binding(
                            get: { scene.selectedPageSize },
                            set: { onAction(.changePageSize($0)) }
                        ),
                        totalRows: scene.totalRows
                    ) {
                        $0.title(in: languageMode)
                    }
                } trailing: {
                    WorkbenchResultTrailingControls(
                        columnMenuTitle: t("列", "Columns"),
                        keys: LocatorColumnKey.allCases,
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
                    onToggleColumnFromHeader: { columnID in
                        guard let column = LocatorColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前定位结果没有可显示的句子。", "No locator rows to display."),
                    accessibilityLabel: t("定位结果表格", "Locator results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 或空格可重新定位当前句子。", "Use arrow keys to browse results, then press Return or Space to relaunch Locator from the selected sentence.")
                )
            }

            if let selectedRow = viewModel.selectedSceneRow {
                locatorSelectedRowSection(selectedRow)
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成定位结果", "No locator results yet"),
                systemImage: "scope",
                message: t("先从 KWIC 选择一条索引行，再运行定位器，这里会显示句内位置、完整句子和可复制的研究引文。", "Choose a concordance line from KWIC, then run Locator to inspect its sentence position, full sentence, and a citation-ready excerpt."),
                suggestions: [
                    t("定位器适合确认节点词是否真的是你要研究的用法。", "Use Locator to verify whether the node really shows the usage you want to study."),
                    t("双击任意句子可以把它作为新的定位源继续展开。", "Double-click any sentence to promote it as the next locator source.")
                ]
            )
        }
    }

    func locatorSelectedRowSection(_ selectedRow: LocatorSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(t("句内定位视图", "Sentence Locator View"))
                        .font(.headline)
                    Spacer()
                    if !selectedRow.status.isEmpty {
                        Text(selectedRow.status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchConcordanceLineView(
                    leftContext: selectedRow.leftWords,
                    keyword: selectedRow.nodeWord,
                    rightContext: selectedRow.rightWords
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("完整原句", "Full Sentence"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selectedRow.text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

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
                        Label(t("以此句继续定位", "Continue from This Sentence"), systemImage: "arrowshape.turn.up.right")
                    }
                    Spacer()
                }
            }
        }
    }
}
