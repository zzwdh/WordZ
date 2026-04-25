import SwiftUI

extension CompareView {
    @ViewBuilder
    var compareResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
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
            } trailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows)（\(t("总计", "Total")) \(scene.totalRows)）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                HStack(spacing: 12) {
                    WorkbenchMenuPicker(
                        title: t("排序", "Sort"),
                        selection: Binding(
                            get: { scene.sorting.selectedSort },
                            set: { onAction(.changeSort($0)) }
                        ),
                        options: Array(CompareSortMode.allCases)
                    ) {
                        $0.title(in: languageMode)
                    }

                    WorkbenchGuardedPageSizePicker(
                        title: t("页大小", "Page Size"),
                        selection: Binding(
                            get: { scene.sorting.selectedPageSize },
                            set: { onAction(.changePageSize($0)) }
                        ),
                        totalRows: scene.filteredRows
                    ) {
                        $0.title(in: languageMode)
                    }
                }
            } trailingControls: {
                WorkbenchResultTrailingControls(
                    columnMenuTitle: t("列", "Columns"),
                    keys: CompareColumnKey.allCases,
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

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    snapshot: scene.tableSnapshot,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onSortByColumn: { columnID in
                        guard let column = CompareColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = CompareColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    allowsMultipleSelection: false,
                    emptyMessage: t("当前对比结果没有可显示的词项。", "No comparison rows to display."),
                    accessibilityLabel: t("对比结果表格", "Compare results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                )
            }

            if let selectedRow = viewModel.selectedSceneRow {
                compareSelectedRowSection(selectedRow)
            }
        } else {
            compareEmptyState
        }
    }
}
