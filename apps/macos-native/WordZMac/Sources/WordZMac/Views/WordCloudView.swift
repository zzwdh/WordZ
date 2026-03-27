import SwiftUI

struct WordCloudView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: WordCloudPageViewModel
    let onAction: (WordCloudPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("词云", "Word Cloud"), subtitle: t("从高频词生成可视化云图，并支持导出表格", "Generate a word cloud from frequent terms and export the backing table")) {
                HStack(spacing: 12) {
                    Stepper(
                        "Top \(viewModel.scene?.limit ?? viewModel.limit)",
                        value: Binding(
                            get: { viewModel.limit },
                            set: { onAction(.changeLimit($0)) }
                        ),
                        in: 10...200,
                        step: 10
                    )
                    .frame(maxWidth: 180)
                    Button(t("生成词云", "Generate Cloud")) { onAction(.run) }
                        .buttonStyle(.borderedProminent)
                }
            }

            WorkbenchToolbarSection {
                TextField(t("搜索词（留空显示全部）", "Search term (leave blank for all)"), text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
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
                            Text(t("高频词云", "Frequent Word Cloud"))
                                .font(.headline)
                            Text(scene.query.isEmpty ? t("显示全部高频词", "Showing all frequent words") : t("过滤词：", "Filter: ") + scene.query)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !scene.searchError.isEmpty {
                                Text(scene.searchError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer(minLength: 12)
                        Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                            ForEach(scene.cloudItems) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.word)
                                        .font(.system(size: 14 * item.fontScale, weight: item.isAccent ? .bold : .medium))
                                        .lineLimit(2)
                                    Text(item.countText)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                                .padding(12)
                                .background(item.isAccent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .frame(minHeight: 220, maxHeight: 320)

                    HStack {
                        Text(t("导出表格", "Export Table"))
                            .font(.headline)
                        Spacer()
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
            } else {
                ContentUnavailableView(
                    t("尚未生成词云", "No word cloud yet"),
                    systemImage: "textformat.size",
                    description: Text(t("打开一条语料后即可生成高频词云。", "Open a corpus to generate a word cloud from frequent words."))
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $viewModel.isEditingStopwords) {
            StopwordEditorSheet(filter: $viewModel.stopwordFilter)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
