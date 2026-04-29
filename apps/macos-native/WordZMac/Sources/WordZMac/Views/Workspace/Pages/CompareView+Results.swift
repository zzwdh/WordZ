import SwiftUI

extension CompareView {
    @ViewBuilder
    var compareResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                annotationState: viewModel.annotationState,
                annotationResultCount: scene.filteredRows,
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                columnKeys: CompareColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                allowsMultipleSelection: false,
                emptyMessage: t("当前对比结果没有可显示的词项。", "No comparison rows to display."),
                accessibilityLabel: t("对比结果表格", "Compare results table"),
                activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
            ) {
                Text(scene.query.isEmpty ? t("显示全部对比词项", "Showing all comparison rows") : t("过滤词：", "Filter: ") + scene.query)
                    .font(.headline)
                Text(scene.referenceSummary)
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
                    sortOptions: Array(CompareSortMode.allCases),
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
                WorkbenchMethodNoteCard(
                    title: t("结果说明", "How to Read These Results"),
                    summary: scene.methodSummary,
                    notes: scene.methodNotes + [scene.annotationSummary]
                )

                HStack {
                    Button(t("复制方法摘要", "Copy Method Summary")) {
                        onAction(.copyMethodSummary)
                    }
                    Spacer()
                }
            } paginationFallback: {
                EmptyView()
            }

            if let selectedRow = viewModel.selectedSceneRow {
                compareSelectedRowSection(selectedRow)
            }
        } else {
            compareEmptyState
        }
    }
}
