import SwiftUI

struct LocatorView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: LocatorPageViewModel
    let onAction: (LocatorPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        leftWindowField
                        rightWindowField
                        sourceStatus
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            leftWindowField
                            rightWindowField
                            runButton
                        }
                        sourceStatus
                    }
                }
            }

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
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)（\(t("共", "Across")) \(scene.sentenceCount) \(t("句", "sentences") )")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    WorkbenchResultControlsRow {
                        Picker(
                            t("页大小", "Page Size"),
                            selection: Binding(
                                get: { scene.selectedPageSize },
                                set: { onAction(.changePageSize($0)) }
                            )
                        ) {
                            ForEach(LocatorPageSize.allCases) { size in
                                Text(size.title(in: languageMode)).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    } trailing: {
                        HStack(spacing: 12) {
                            WorkbenchColumnMenu(
                                title: t("列", "Columns"),
                                keys: LocatorColumnKey.allCases,
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
                        onToggleColumnFromHeader: { columnID in
                            guard let column = LocatorColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前定位结果没有可显示的句子。", "No locator rows to display."),
                        accessibilityLabel: t("定位结果表格", "Locator results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 或空格可重新定位当前句子。", "Use arrow keys to browse results, then press Return or Space to relaunch Locator from the selected sentence.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }

                if let selectedRow = viewModel.selectedSceneRow {
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
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    @ViewBuilder
    private var sourceStatus: some View {
        if let source = viewModel.currentSource {
            Text(t("当前源：句", "Current Source: sentence") + " \(source.sentenceId + 1) · " + t("节点词", "Node") + " \(source.keyword)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(t("请先运行 KWIC。", "Run KWIC first."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var runButton: some View {
        Button(t("定位当前 KWIC", "Locate Current KWIC")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasSource)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
