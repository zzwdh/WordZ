import SwiftUI

extension CollocateView {
    @ViewBuilder
    var collocateResultsSection: some View {
        if let scene = viewModel.scene {
            if viewModel.hasPendingRunChanges {
                WorkbenchIssueBanner(
                    tone: .info,
                    title: t("参数已修改，结果仍基于上次运行", "Inputs changed, results still reflect the previous run"),
                    message: t("你已经修改了节点词、窗口或最小频次。重新运行后，表格和统计指标才会按新参数刷新。", "You changed the keyword, window, or minimum frequency. Run the analysis again to refresh the table and metrics with the new settings.")
                ) {
                    HStack(spacing: 10) {
                        runButton
                        Text(t("当前结果仍可用于查看旧参数下的排序与细节。", "The current results still describe the previous run and remain available for inspection."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            AnalysisResultTableSection(
                annotationState: viewModel.annotationState,
                annotationResultCount: scene.filteredRows,
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                columnKeys: CollocateColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前搭配词结果没有可显示的词项。", "No collocate rows to display."),
                accessibilityLabel: t("搭配词结果表格", "Collocate results table"),
                activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
            ) {
                Text(t("节点词：", "Node Word: ") + scene.query)
                    .font(.headline)
                Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow) · " + t("最低共现：", "Min Co-occurrence: ") + "\(scene.minFreq)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } headerTrailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows) / \(scene.totalRows)")
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
                    sortOptions: Array(CollocateSortMode.allCases),
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.filteredRows,
                    pageSizeLabel: { $0.title(in: languageMode) },
                    prefix: {
                        WorkbenchMenuPicker(
                            title: t("重点指标", "Focus Metric"),
                            selection: Binding(
                                get: { viewModel.focusMetricValue },
                                set: { onAction(.changeFocusMetric($0)) }
                            ),
                            options: Array(CollocateAssociationMetric.allCases)
                        ) {
                            $0.title(in: languageMode)
                        }
                    }
                )
            } tableSupplement: {
                WorkbenchMethodNoteCard(
                    title: t("结果说明", "How to Read These Results"),
                    summary: scene.methodSummary,
                    notes: scene.methodNotes
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
                collocateSelectedRowSection(selectedRow, focusMetric: scene.focusMetric)
            }
        } else {
            collocateEmptyState
        }
    }
}
