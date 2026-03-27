import SwiftUI

struct LocatorView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: LocatorPageViewModel
    let onAction: (LocatorPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("定位", "Locator"), subtitle: t("围绕当前 KWIC 结果查看原句与邻近上下文", "Inspect the source sentence and nearby context around the current KWIC result")) {
                Button(t("定位当前 KWIC", "Locate Current KWIC")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.hasSource)
            }

            WorkbenchToolbarSection {
                HStack(spacing: 12) {
                    TextField(t("左窗口", "Left Window"), text: $viewModel.leftWindow)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    TextField(t("右窗口", "Right Window"), text: $viewModel.rightWindow)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    if let source = viewModel.currentSource {
                        Text(t("当前源：句", "Current Source: sentence") + " \(source.sentenceId + 1) · " + t("节点词", "Node") + " \(source.keyword)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text(t("请先运行 KWIC，定位页会默认使用当前 KWIC 第一条结果。", "Run KWIC first. Locator will use the first current KWIC row by default."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let scene = viewModel.scene {
                WorkbenchToolbarSection {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
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
                        }
                        Spacer(minLength: 12)
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)（\(t("共", "Across")) \(scene.sentenceCount) \(t("句", "sentences") )")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack(spacing: 12) {
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

                        WorkbenchColumnMenu(
                            title: t("列", "Columns"),
                            keys: LocatorColumnKey.allCases,
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
            } else {
                ContentUnavailableView(
                    t("尚未生成定位结果", "No locator results yet"),
                    systemImage: "scope",
                    description: Text(t("运行 KWIC 后，定位页会默认打开当前 KWIC 第一条结果所在的原句。", "After KWIC runs, Locator opens the source sentence for the first current KWIC row by default."))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

}
