import SwiftUI

extension WordView {
    @ViewBuilder
    var wordResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                annotationState: viewModel.annotationState,
                annotationResultCount: scene.filteredRows,
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                columnKeys: WordColumnKey.allCases,
                columnMenuTitle: t("列与导出", "Columns & Export"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前词表结果没有可显示的词项。", "No word rows to display."),
                accessibilityLabel: t("词表结果表格", "Word results table"),
                activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
            ) {
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
                    sortOptions: Array(WordSortMode.allCases),
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.filteredRows,
                    pageSizeLabel: { $0.title(in: languageMode) },
                    middle: {
                        definitionControls(for: scene)
                    }
                )
            } tableSupplement: {
                EmptyView()
            } paginationFallback: {
                EmptyView()
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
