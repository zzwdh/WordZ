import SwiftUI

extension NgramView {
    @ViewBuilder
    var ngramResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                columnKeys: NgramColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前 N-Gram 结果没有可显示的词串。", "No N-Gram rows to display."),
                accessibilityLabel: t("N-Gram 结果表格", "N-Gram results table"),
                activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
            ) {
                Text("\(scene.n)-Gram")
                    .font(.headline)
                Text(scene.query.isEmpty ? t("显示全部结果", "Showing all results") : t("过滤词：", "Filter: ") + scene.query)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } headerTrailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                WorkbenchTablePrimaryControls(
                    sortTitle: t("排序", "Sort"),
                    selectedSort: Binding(
                        get: { scene.sorting.selectedSort },
                        set: { onAction(.changeSort($0)) }
                    ),
                    sortOptions: Array(NgramSortMode.allCases),
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.filteredRows,
                    pageSizeLabel: { $0.title(in: languageMode) }
                )
            } tableSupplement: {
                EmptyView()
            } paginationFallback: {
                EmptyView()
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成 N-Gram 结果", "No N-Gram results yet"),
                systemImage: "textformat.abc.dottedunderline",
                message: t("选择 N 值并运行后，这里会显示可排序、可分页、可导出的连续词串。", "Choose an N value and run the analysis to build a sortable, pageable, exportable n-gram table."),
                suggestions: [
                    t("先用 2-Gram 或 3-Gram 找稳定搭配，再提高 N 值查看更长表达。", "Start with 2-grams or 3-grams for stable patterns, then raise N to inspect longer expressions."),
                    t("结果生成后可直接用列菜单控制字段，并通过表头继续排序。", "After running, use the column menu to control fields and table headers to refine sorting.")
                ]
            )
        }
    }
}
