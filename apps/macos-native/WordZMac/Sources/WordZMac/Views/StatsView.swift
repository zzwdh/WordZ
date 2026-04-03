import SwiftUI

struct StatsView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: StatsPageViewModel
    let onAction: (StatsPageAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let scene = viewModel.scene {
                summarySection(scene)
                resultsSection(scene)
                tableSection(scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                emptyState
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchToolbarSection {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        statsOverviewText
                        Spacer(minLength: 0)
                        runButton
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        statsOverviewText
                        HStack(spacing: 12) {
                            runButton
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            ContentUnavailableView(
                t("尚未生成统计结果", "No stats yet"),
                systemImage: "chart.bar.doc.horizontal"
            )
        }
    }

    private func summarySection(_ scene: StatsSceneModel) -> some View {
        WorkbenchToolbarSection {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    statsOverviewText
                    Spacer(minLength: 0)
                    runButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    statsOverviewText
                    HStack(spacing: 12) {
                        runButton
                        Spacer(minLength: 0)
                    }
                }
            }

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

    private func resultsSection(_ scene: StatsSceneModel) -> some View {
        WorkbenchToolbarSection {
            WorkbenchResultHeaderRow {
                Text(t("词频列表", "Frequency List"))
                    .font(.headline)
                Text(currentSortSummary(for: scene))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(scene.definitionSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } trailing: {
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
            }

            WorkbenchResultControlsRow {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        sortPicker(for: scene)
                        definitionControls(for: scene)
                        if showsPageSizeControl(for: scene) {
                            pageSizePicker(for: scene)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        sortPicker(for: scene)
                        definitionControls(for: scene)
                        if showsPageSizeControl(for: scene) {
                            pageSizePicker(for: scene)
                        }
                    }
                }
            } trailing: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        columnMenu(for: scene)
                        if showsPaginationControls(for: scene) {
                            paginationControls(for: scene)
                        } else {
                            allRowsVisibleBadge
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        columnMenu(for: scene)
                        if showsPaginationControls(for: scene) {
                            paginationControls(for: scene)
                        } else {
                            allRowsVisibleBadge
                        }
                    }
                }
            }
        }
    }

    private func tableSection(_ scene: StatsSceneModel) -> some View {
        WorkbenchSectionCard {
            NativeTableView(
                descriptor: scene.table,
                rows: scene.tableRows,
                onSortByColumn: { columnID in
                    guard let column = StatsColumnKey(rawValue: columnID) else { return }
                    onAction(.sortByColumn(column))
                },
                onToggleColumnFromHeader: { columnID in
                    guard let column = StatsColumnKey(rawValue: columnID) else { return }
                    onAction(.toggleColumn(column))
                },
                emptyMessage: t("当前统计结果没有可显示的词项。", "No stats rows to display."),
                accessibilityLabel: t("统计结果表格", "Stats results table"),
                activationHint: t("使用方向键浏览结果，按 Return 可触发表格默认动作。", "Use arrow keys to browse results, then press Return to trigger the default table action.")
                )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(1)
        }
    }

    private var statsOverviewText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t("统计概览", "Stats Overview"))
                .font(.headline)
            Text(t("对当前语料计算 Token、Type、TTR、STTR，以及 Norm Frequency、Range、Rank、Norm Range 等词频指标。", "Compute Token, Type, TTR, STTR, plus Norm Frequency, Range, Rank, and Norm Range for the current corpus."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var runButton: some View {
        Button(t("开始统计", "Run Stats")) { onAction(.run) }
            .buttonStyle(.borderedProminent)
    }

    private func sortPicker(for scene: StatsSceneModel) -> some View {
        Picker(
            t("排序", "Sort"),
            selection: Binding(
                get: { scene.sorting.selectedSort },
                set: { onAction(.changeSort($0)) }
            )
        ) {
            ForEach(StatsSortMode.allCases) { mode in
                Text(mode.title(in: languageMode)).tag(mode)
            }
        }
        .pickerStyle(.menu)
    }

    private func pageSizePicker(for scene: StatsSceneModel) -> some View {
        Picker(
            t("页大小", "Page Size"),
            selection: Binding(
                get: { scene.sorting.selectedPageSize },
                set: { onAction(.changePageSize($0)) }
            )
        ) {
            ForEach(StatsPageSize.allCases) { size in
                Text(size.title(in: languageMode)).tag(size)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
    }

    private func definitionControls(for scene: StatsSceneModel) -> some View {
        HStack(spacing: 12) {
            Picker(
                t("标准频次", "Norm Frequency"),
                selection: Binding(
                    get: { scene.definition.normalizationUnit },
                    set: { onAction(.changeNormalizationUnit($0)) }
                )
            ) {
                ForEach(FrequencyNormalizationUnit.allCases) { unit in
                    Text(unit.title(in: languageMode)).tag(unit)
                }
            }
            .pickerStyle(.menu)

            Picker(
                t("Range 口径", "Range Definition"),
                selection: Binding(
                    get: { scene.definition.rangeMode },
                    set: { onAction(.changeRangeMode($0)) }
                )
            ) {
                ForEach(FrequencyRangeMode.allCases) { mode in
                    Text(mode.title(in: languageMode)).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func columnMenu(for scene: StatsSceneModel) -> some View {
        WorkbenchColumnMenu(
            title: t("列与导出", "Columns & Export"),
            keys: StatsColumnKey.allCases,
            label: { scene.columnTitle(for: $0, mode: languageMode) },
            isVisible: { scene.column(for: $0)?.isVisible ?? false },
            onToggle: { onAction(.toggleColumn($0)) }
        )
    }

    private func paginationControls(for scene: StatsSceneModel) -> some View {
        WorkbenchPaginationControls(
            canGoBackward: scene.pagination.canGoBackward,
            canGoForward: scene.pagination.canGoForward,
            rangeLabel: scene.pagination.rangeLabel,
            onPrevious: { onAction(.previousPage) },
            onNext: { onAction(.nextPage) }
        )
    }

    private var allRowsVisibleBadge: some View {
        Label(t("当前页已展开全部结果", "All visible rows shown"), systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
    }

    private func currentSortSummary(for scene: StatsSceneModel) -> String {
        t("当前排序：", "Current sort: ") + scene.sorting.selectedSort.title(in: languageMode)
    }

    private func rangeSummary(for scene: StatsSceneModel) -> String {
        if showsPaginationControls(for: scene) {
            return scene.pagination.rangeLabel
        }
        return t("本页已完整展开", "All rows are visible on this page")
    }

    private func showsPageSizeControl(for scene: StatsSceneModel) -> Bool {
        scene.totalRows > StatsPageSize.fifty.rawValue
    }

    private func showsPaginationControls(for scene: StatsSceneModel) -> Bool {
        scene.pagination.totalPages > 1
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
