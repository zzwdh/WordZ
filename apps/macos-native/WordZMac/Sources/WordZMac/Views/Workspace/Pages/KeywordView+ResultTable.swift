import SwiftUI

extension KeywordView {
    @ViewBuilder
    func keywordResultsTableSection(_ scene: KeywordSceneModel) -> some View {
        WorkbenchToolbarSection {
            keywordResultHeaderRow(scene)
            keywordResultControlsRow(scene)
        }

        WorkbenchTableCard {
            NativeTableView(
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                onSortByColumn: { columnID in
                    guard let column = KeywordColumnKey(rawValue: columnID) else { return }
                    onAction(.sortByColumn(column))
                },
                onToggleColumnFromHeader: { columnID in
                    guard let column = KeywordColumnKey(rawValue: columnID) else { return }
                    onAction(.toggleColumn(column))
                },
                allowsMultipleSelection: false,
                emptyMessage: scene.emptyStateMessage,
                accessibilityLabel: t("Keyword Suite 结果表格", "Keyword Suite results table"),
                activationHint: t("使用方向键浏览关键词结果。", "Use arrow keys to browse keyword suite results.")
            )
        }
    }

    func keywordResultHeaderRow(_ scene: KeywordSceneModel) -> some View {
        WorkbenchResultHeaderRow {
            Text(keywordResultHeaderTitle(scene))
                .font(.headline)
            if viewModel.hasPendingRunChanges, viewModel.activeTab != .lists {
                Text(t("输入已修改，当前结果仍基于上次运行。", "Inputs changed. The table still reflects the last run."))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } trailing: {
            Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    func keywordResultControlsRow(_ scene: KeywordSceneModel) -> some View {
        WorkbenchResultControlsRow {
            HStack(spacing: 12) {
                WorkbenchMenuPicker(
                    title: t("排序", "Sort"),
                    selection: Binding(
                        get: { scene.sorting.selectedSort },
                        set: { onAction(.changeSort($0)) }
                    ),
                    options: Array(KeywordSortMode.allCases)
                ) {
                    $0.title(in: languageMode)
                }

                WorkbenchGuardedPageSizePicker(
                    title: t("页大小", "Page Size"),
                    selection: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.totalRows
                ) {
                    $0.title(in: languageMode)
                }
            }
        } trailing: {
            WorkbenchResultTrailingControls(
                columnMenuTitle: t("列", "Columns"),
                keys: scene.table.columns.compactMap { KeywordColumnKey(rawValue: $0.id) },
                label: { scene.columnTitle(for: $0, mode: languageMode, statistic: viewModel.statistic) },
                isVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggle: { onAction(.toggleColumn($0)) },
                canGoBackward: scene.pagination.canGoBackward,
                canGoForward: scene.pagination.canGoForward,
                rangeLabel: scene.pagination.rangeLabel,
                onPrevious: { onAction(.previousPage) },
                onNext: { onAction(.nextPage) }
            )
        }
    }
}
