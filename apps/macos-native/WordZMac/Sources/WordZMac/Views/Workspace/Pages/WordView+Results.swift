import SwiftUI

extension WordView {
    @ViewBuilder
    var wordResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
                Text(scene.query.isEmpty ? t("显示全部词项", "Showing all terms") : t("过滤词：", "Filter: ") + scene.query)
                    .font(.headline)
                Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(scene.definitionSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } trailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                WorkbenchAdaptiveControlCluster {
                    sortPicker(for: scene)
                    definitionControls(for: scene)
                    pageSizePicker(for: scene)
                }
            } trailingControls: {
                WorkbenchAdaptiveResultTrailingControls(
                    columnMenuTitle: t("列与导出", "Columns & Export"),
                    keys: WordColumnKey.allCases,
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

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    onSortByColumn: { columnID in
                        guard let column = WordColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = WordColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前词表结果没有可显示的词项。", "No word rows to display."),
                    accessibilityLabel: t("词表结果表格", "Word results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                )
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成词表结果", "No word results yet"),
                systemImage: "character.book.closed",
                message: t("先运行词表统计，WordZ 会按当前检索和停用词口径给出可排序、可导出的词项列表。", "Run the word list first and WordZ will build a sortable, exportable lexical table based on the current query and stopword rules.")
            )
        }
    }

}
