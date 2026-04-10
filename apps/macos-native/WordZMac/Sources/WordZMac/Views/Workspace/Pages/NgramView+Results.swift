import SwiftUI

extension NgramView {
    @ViewBuilder
    var ngramResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchResultsToolbarSection {
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
                        options: Array(NgramSortMode.allCases)
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
                    keys: NgramColumnKey.allCases,
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
                        guard let column = NgramColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = NgramColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前 N-Gram 结果没有可显示的词串。", "No N-Gram rows to display."),
                    accessibilityLabel: t("N-Gram 结果表格", "N-Gram results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                )
            }
        } else {
            ContentUnavailableView(
                t("尚未生成 N-Gram 结果", "No N-Gram results yet"),
                systemImage: "textformat.abc.dottedunderline"
            )
        }
    }
}
