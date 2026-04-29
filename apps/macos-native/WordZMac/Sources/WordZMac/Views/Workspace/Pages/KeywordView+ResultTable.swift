import SwiftUI

extension KeywordView {
    @ViewBuilder
    func keywordResultsTableSection(_ scene: KeywordSceneModel) -> some View {
        AnalysisResultTableSection(
            descriptor: scene.table,
            snapshot: scene.tableSnapshot,
            selectedRowID: viewModel.selectedRowID,
            onSelectionChange: { onAction(.selectRow($0)) },
            columnKeys: scene.table.columns.compactMap { KeywordColumnKey(rawValue: $0.id) },
            columnMenuTitle: t("列", "Columns"),
            columnLabel: { scene.columnTitle(for: $0, mode: languageMode, statistic: viewModel.statistic) },
            isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
            onToggleColumn: { onAction(.toggleColumn($0)) },
            onSortByColumn: { onAction(.sortByColumn($0)) },
            onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
            pagination: scene.pagination,
            onPreviousPage: { onAction(.previousPage) },
            onNextPage: { onAction(.nextPage) },
            allowsMultipleSelection: false,
            emptyMessage: scene.emptyStateMessage,
            accessibilityLabel: t("Keyword Suite 结果表格", "Keyword Suite results table"),
            activationHint: t("使用方向键浏览关键词结果。", "Use arrow keys to browse keyword suite results.")
        ) {
            Text(keywordResultHeaderTitle(scene))
                .font(.headline)
            if viewModel.hasPendingRunChanges, viewModel.activeTab != .lists {
                Text(t("输入已修改，当前结果仍基于上次运行。", "Inputs changed. The table still reflects the last run."))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } headerTrailing: {
            Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
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
                sortOptions: Array(KeywordSortMode.allCases),
                sortLabel: { $0.title(in: languageMode) },
                pageSizeTitle: t("页大小", "Page Size"),
                selectedPageSize: Binding(
                    get: { scene.sorting.selectedPageSize },
                    set: { onAction(.changePageSize($0)) }
                ),
                totalRows: scene.totalRows,
                pageSizeLabel: { $0.title(in: languageMode) }
            )
        } tableSupplement: {
            EmptyView()
        } paginationFallback: {
            EmptyView()
        }
    }
}
