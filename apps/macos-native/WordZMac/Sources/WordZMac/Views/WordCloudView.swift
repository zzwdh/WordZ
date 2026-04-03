import SwiftUI

struct WordCloudView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: WordCloudPageViewModel
    let onAction: (WordCloudPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            controlsSection

            if let scene = viewModel.scene {
                previewSection(scene)
                tableSection(scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ContentUnavailableView(
                    t("尚未生成词云", "No word cloud yet"),
                    systemImage: "textformat.size"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private var controlsSection: some View {
        WorkbenchToolbarSection {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    searchField
                    limitStepper
                    runButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        searchField
                        runButton
                    }
                    HStack(spacing: 12) {
                        limitStepper
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
    }

    private func previewSection(_ scene: WordCloudSceneModel) -> some View {
        WorkbenchToolbarSection {
            WorkbenchResultHeaderRow {
                Text(t("高频词云", "Frequent Word Cloud"))
                    .font(.headline)
                Text(scene.query.isEmpty ? t("显示全部高频词", "Showing all frequent words") : t("过滤词：", "Filter: ") + scene.query)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } trailing: {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(limitSummary(for: scene))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 118), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(scene.cloudItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.word)
                                .font(.system(size: 14 * item.fontScale, weight: item.isAccent ? .bold : .medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.countText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                        .padding(12)
                        .background(
                            item.isAccent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                }
            }
            .frame(height: cloudPreviewHeight(for: scene.visibleRows))
        }
    }

    private func tableSection(_ scene: WordCloudSceneModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkbenchToolbarSection {
                WorkbenchResultHeaderRow {
                    Text(t("词频明细", "Frequency Details"))
                        .font(.headline)
                    Text(t("用于复制、Quick Look 与导出。", "Used for copy, Quick Look, and export."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } trailing: {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchResultControlsRow {
                    Label(t("词云表格会随当前筛选同步更新", "The table reflects the current filtered cloud"), systemImage: "tablecells")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } trailing: {
                    WorkbenchColumnMenu(
                        title: t("列", "Columns"),
                        keys: WordCloudColumnKey.allCases,
                        label: { scene.column(for: $0)?.title ?? $0.title },
                        isVisible: { scene.column(for: $0)?.isVisible ?? false },
                        onToggle: { onAction(.toggleColumn($0)) }
                    )
                }
            }

            WorkbenchSectionCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    onToggleColumnFromHeader: { columnID in
                        guard let column = WordCloudColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前词云导出表没有可显示的数据。", "No word cloud export rows to display.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)
            }
        }
    }

    private var searchField: some View {
        TextField(t("搜索词（留空显示全部）", "Search term (leave blank for all)"), text: $viewModel.query)
            .textFieldStyle(.roundedBorder)
            .layoutPriority(1)
    }

    private var limitStepper: some View {
        Stepper(
            t("显示前", "Top ") + "\(viewModel.scene?.limit ?? viewModel.limit)",
            value: Binding(
                get: { viewModel.limit },
                set: { onAction(.changeLimit($0)) }
            ),
            in: 10...200,
            step: 10
        )
        .frame(maxWidth: 180)
    }

    private var runButton: some View {
        Button(t("生成词云", "Generate Cloud")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func limitSummary(for scene: WordCloudSceneModel) -> String {
        t("当前上限：", "Current limit: ") + "\(scene.limit)"
    }

    private func cloudPreviewHeight(for visibleRows: Int) -> CGFloat {
        let estimatedRows = max(Int(ceil(Double(max(visibleRows, 1)) / 5.0)), 1)
        let fittedHeight = CGFloat(estimatedRows) * 104
        return min(max(fittedHeight, 180), 320)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
