import SwiftUI

extension StatsView {
    var emptyState: some View {
        WorkbenchEmptyStateCard(
            title: t("尚未生成统计结果", "No stats yet"),
            systemImage: "chart.bar.doc.horizontal",
            message: t("统计会先给你一个整体轮廓：词项规模、词汇密度、标准频次与分布范围。完成这一步后，再进入词表、对比和阅读会更清楚。", "Stats gives you the overall shape first: scale, lexical density, normalized frequency, and distribution range. That baseline makes later word, compare, and reading work much clearer."),
            suggestions: [
                t("默认先用全部语料跑一遍，得到最稳定的概览。", "Start with all corpora for the most stable overview."),
                t("先跑统计，再决定是否需要更细的分词、对比或 KWIC 阅读。", "Run stats first, then decide whether you need tokenization, comparison, or KWIC reading.")
            ]
        )
    }

    func summarySection(_ scene: StatsSceneModel) -> some View {
        WorkbenchToolbarSection {
            statsOverviewText

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 12)
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(scene.metrics) { metric in
                    WorkbenchMetricCard(title: metric.title, value: metric.value)
                }
            }
        }
    }

    func resultsSection(_ scene: StatsSceneModel) -> some View {
        AnalysisResultTableSection(
            descriptor: scene.table,
            snapshot: scene.tableSnapshot,
            columnKeys: StatsColumnKey.allCases,
            columnMenuTitle: t("列与导出", "Columns & Export"),
            columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
            isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
            onToggleColumn: { onAction(.toggleColumn($0)) },
            onSortByColumn: { onAction(.sortByColumn($0)) },
            onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
            pagination: scene.pagination,
            showsPaginationControls: showsPaginationControls(for: scene),
            onPreviousPage: { onAction(.previousPage) },
            onNextPage: { onAction(.nextPage) },
            emptyMessage: t("当前统计结果没有可显示的词项。", "No stats rows to display."),
            accessibilityLabel: t("统计结果表格", "Stats results table"),
            activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
        ) {
            Text(t("词频列表", "Frequency List"))
                .font(.headline)
            Text(currentSortSummary(for: scene))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(scene.definitionSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        } headerTrailing: {
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(rangeSummary(for: scene))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        } leadingControls: {
            WorkbenchTablePrimaryControls(
                sortTitle: t("排序", "Sort"),
                selectedSort: Binding(
                    get: { scene.sorting.selectedSort },
                    set: { onAction(.changeSort($0)) }
                ),
                sortOptions: Array(StatsSortMode.allCases),
                sortLabel: { $0.title(in: languageMode) },
                pageSizeTitle: t("页大小", "Page Size"),
                selectedPageSize: Binding(
                    get: { scene.sorting.selectedPageSize },
                    set: { onAction(.changePageSize($0)) }
                ),
                totalRows: scene.totalRows,
                showsPageSizeControl: showsPageSizeControl(for: scene),
                pageSizeLabel: { $0.title(in: languageMode) },
                middle: {
                    definitionControls(for: scene)
                }
            )
        } tableSupplement: {
            EmptyView()
        } paginationFallback: {
            allRowsVisibleBadge
        }
    }

    var statsOverviewText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("统计概览", "Stats Overview"))
                .font(.headline)
            Text(t("对当前语料计算 Token、Type、TTR、STTR，以及 Norm Frequency、Range、Rank、Norm Range 等词频指标。", "Compute Token, Type, TTR, STTR, plus Norm Frequency, Range, Rank, and Norm Range for the current corpus."))
                .font(.caption)
                .foregroundStyle(WordZTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func sortPicker(for scene: StatsSceneModel) -> some View {
        WorkbenchMenuPicker(
            title: t("排序", "Sort"),
            selection: Binding(
                get: { scene.sorting.selectedSort },
                set: { onAction(.changeSort($0)) }
            ),
            options: Array(StatsSortMode.allCases)
        ) {
            $0.title(in: languageMode)
        }
    }

    func pageSizePicker(for scene: StatsSceneModel) -> some View {
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

    func definitionControls(for scene: StatsSceneModel) -> some View {
        HStack(spacing: 12) {
            WorkbenchMenuPicker(
                title: t("标准频次", "Norm Frequency"),
                selection: Binding(
                    get: { scene.definition.normalizationUnit },
                    set: { onAction(.changeNormalizationUnit($0)) }
                ),
                options: Array(FrequencyNormalizationUnit.allCases)
            ) {
                $0.title(in: languageMode)
            }

            WorkbenchMenuPicker(
                title: t("Range 口径", "Range Definition"),
                selection: Binding(
                    get: { scene.definition.rangeMode },
                    set: { onAction(.changeRangeMode($0)) }
                ),
                options: Array(FrequencyRangeMode.allCases)
            ) {
                $0.title(in: languageMode)
            }
        }
    }

    var allRowsVisibleBadge: some View {
        Label(t("当前页已展开全部结果", "All visible rows shown"), systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    func currentSortSummary(for scene: StatsSceneModel) -> String {
        t("当前排序：", "Current sort: ") + scene.sorting.selectedSort.title(in: languageMode)
    }

    func rangeSummary(for scene: StatsSceneModel) -> String {
        if showsPaginationControls(for: scene) {
            return scene.pagination.rangeLabel
        }
        return t("本页已完整展开", "All rows are visible on this page")
    }

    func showsPageSizeControl(for scene: StatsSceneModel) -> Bool {
        scene.totalRows > StatsPageSize.fifty.rawValue
    }

    func showsPaginationControls(for scene: StatsSceneModel) -> Bool {
        scene.pagination.totalPages > 1
    }
}
