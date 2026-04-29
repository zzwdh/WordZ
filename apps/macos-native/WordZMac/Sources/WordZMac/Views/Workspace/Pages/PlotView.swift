import SwiftUI

struct PlotView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var viewModel: PlotPageViewModel
    let isBusy: Bool
    let onAction: (PlotPageAction) -> Void

    var body: some View {
        UtilityPageScaffold(
            title: "Plot",
            scrollMode: .manual
        ) {
            WorkbenchFixedTopScrollContent {
                plotInputSection
            } scrolling: {
                plotResultsSection
            }
        }
    }

    private var plotInputSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    WorkbenchAdaptiveControls {
                        HStack(spacing: 12) {
                            searchField
                        }
                    } compact: {
                        VStack(alignment: .leading, spacing: 12) {
                            searchField
                        }
                    }
                } actions: {
                    HStack(spacing: 8) {
                        Button(t("运行", "Run Plot")) {
                            onAction(.run)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isBusy)

                        Button {
                            onAction(.openKWIC)
                        } label: {
                            Label(t("在 KWIC 中打开", "Open in KWIC"), systemImage: "quote.opening")
                        }
                        .disabled(viewModel.selectedSceneRow == nil || viewModel.normalizedQuery.isEmpty || isBusy)

                        Button {
                            onAction(.openSourceReader)
                        } label: {
                            Label(t("打开原文视图", "Open Source View"), systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(viewModel.selectedSceneRow?.markers.isEmpty != false || isBusy)
                    }
                }

                SearchOptionTogglesView(options: $viewModel.searchOptions)
            }
        }
    }

    @ViewBuilder
    private var plotResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
                Text(scene.query.isEmpty ? "Plot" : scene.query)
                    .font(.headline)
                Text(scene.scope.title(in: languageMode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } trailing: {
                Text("\(t("文件", "Files")) \(scene.totalFilesWithHits) / \(scene.totalFiles)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                EmptyView()
            } trailingControls: {
                EmptyView()
            }

            WorkbenchSectionCard {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        summaryCards(scene)
                    }
                    VStack(spacing: 12) {
                        summaryCards(scene)
                    }
                }
            }

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    snapshot: scene.tableSnapshot,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onDoubleClick: { _ in
                        onAction(.openKWIC)
                    },
                    columnKey: PlotColumnKey.self,
                    selectedMarkerID: viewModel.selectedMarkerID,
                    onMarkerSelectionChange: { rowID, markerID in
                        onAction(.selectMarker(rowID: rowID, markerID: markerID))
                    },
                    emptyMessage: t("当前 Plot 结果没有可显示的文件。", "No Plot rows to display."),
                    accessibilityLabel: t("Plot 分布结果表格", "Plot distribution results table"),
                    activationHint: t("按 Return 打开 KWIC。", "Press Return to open in KWIC.")
                )
            }

            if let selectedRow = viewModel.selectedSceneRow {
                WorkbenchSectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedRow.displayPath)
                            .font(.headline)
                            .lineLimit(2)
                        Text("FileID \(selectedRow.fileID) · Freq \(selectedRow.frequency) · NormFreq \(selectedRow.normalizedFrequencyText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let marker = viewModel.selectedSceneMarker {
                            Text("Sentence \(marker.sentenceId + 1) · Token \(marker.tokenIndex + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(t("选中 Plot 列中的命中线后，可在打开 KWIC 时预选对应命中。", "Select a hit marker in the Plot column to preselect that concordance line in KWIC."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            onAction(.openKWIC)
                        } label: {
                            Label(t("在 KWIC 中打开", "Open in KWIC"), systemImage: "quote.opening")
                        }
                        .disabled(viewModel.normalizedQuery.isEmpty || isBusy)

                        Button {
                            onAction(.openSourceReader)
                        } label: {
                            Label(t("打开原文视图", "Open Source View"), systemImage: "doc.text.magnifyingglass")
                        }
                        .disabled(selectedRow.markers.isEmpty || isBusy)
                    }
                }
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成 Plot 结果", "No Plot results yet"),
                systemImage: "chart.bar.xaxis",
                message: t("输入检索词并运行后，这里会显示它在当前语料或当前语料范围中的分布。", "Enter a query and run Plot to see its distribution in the current corpus or corpus range.")
            )
        }
    }

    @ViewBuilder
    private func summaryCards(_ scene: PlotSceneModel) -> some View {
        WorkbenchMetricCard(
            title: t("总命中", "Total Hits"),
            value: "\(scene.totalHits)"
        )
        WorkbenchMetricCard(
            title: t("有命中文件", "Files With Hits"),
            value: "\(scene.totalFilesWithHits)"
        )
        WorkbenchMetricCard(
            title: t("范围", "Scope"),
            value: scene.scope.title(in: languageMode)
        )
    }

    private var searchField: some View {
        TextField(t("搜索词", "Search query"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
