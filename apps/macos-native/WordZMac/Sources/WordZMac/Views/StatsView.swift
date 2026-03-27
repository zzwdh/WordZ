import SwiftUI

struct StatsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: StatsPageViewModel
    let onAction: (StatsPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("统计", "Stats"), subtitle: t("生成当前语料的词频、TTR 与基础概览", "Generate frequencies, TTR, and a quick overview for the current corpus")) {
                Button(t("开始统计", "Run Stats")) { onAction(.run) }
                    .buttonStyle(.borderedProminent)
            }

            if let scene = viewModel.scene {
                HStack(spacing: 16) {
                    ForEach(scene.metrics) { metric in
                        WorkbenchMetricCard(title: metric.title, value: metric.value)
                    }
                }

                WorkbenchToolbarSection {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("词频结果", "Frequency Results"))
                                .font(.headline)
                            Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Spacer(minLength: 12)

                        Picker(
                            t("排序", "Sort"),
                            selection: Binding(
                                get: { scene.sorting.selectedSort },
                                set: { onAction(.changeSort($0)) }
                            )
                        ) {
                            ForEach(StatsSortMode.allCases) { mode in
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
                            ForEach(StatsPageSize.allCases) { size in
                                Text(size.title(in: languageMode)).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                    }

                    HStack(spacing: 12) {
                        WorkbenchColumnMenu(
                            title: t("列", "Columns"),
                            keys: StatsColumnKey.allCases,
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
                        onSortByColumn: { columnID in
                            guard let column = StatsColumnKey(rawValue: columnID) else { return }
                            onAction(.sortByColumn(column))
                        },
                        onToggleColumnFromHeader: { columnID in
                            guard let column = StatsColumnKey(rawValue: columnID) else { return }
                            onAction(.toggleColumn(column))
                        },
                        emptyMessage: t("当前统计结果没有可显示的词项。", "No stats rows to display."),
                        accessibilityLabel: t("统计结果表格", "Stats results table"),
                        activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .layoutPriority(1)
                }
            } else {
                ContentUnavailableView(
                    t("尚未生成统计结果", "No stats yet"),
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text(t("先从左侧打开一条已保存语料，再开始统计。", "Open a saved corpus from the sidebar, then run stats."))
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
