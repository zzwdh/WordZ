import SwiftUI

extension KeywordView {
    @ViewBuilder
    var keywordResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchHeaderCard(
                title: t("Target / Reference 摘要", "Target / Reference Summary"),
                subtitle: scene.preprocessingSummary
            ) {
                HStack(spacing: 12) {
                    WorkbenchMetricCard(title: t("Target", "Target"), value: scene.targetSummary)
                    WorkbenchMetricCard(title: t("Reference", "Reference"), value: scene.referenceSummary)
                }
                .frame(maxWidth: 520)
            }

            WorkbenchMethodNoteCard(
                title: t("结果说明", "How to Read These Results"),
                summary: scene.methodSummary,
                notes: scene.methodNotes
            )

            WorkbenchToolbarSection {
                WorkbenchResultHeaderRow {
                    Text(t("按显著性显示关键词", "Showing keywords ranked by keyness"))
                        .font(.headline)
                    if viewModel.hasPendingRunChanges {
                        Text(t("参数已修改，当前表格仍基于上次运行。", "Parameters changed. The table still reflects the last completed run."))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } trailing: {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

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
                        keys: KeywordColumnKey.allCases,
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

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
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
                    emptyMessage: t("当前没有符合条件的关键词。", "No keywords match the current criteria."),
                    accessibilityLabel: t("关键词结果表格", "Keyword results table"),
                    activationHint: t("使用方向键浏览关键词结果。", "Use arrow keys to browse keyword results.")
                )
            }

            if let selectedRow = viewModel.selectedSceneRow {
                keywordSelectedRowSection(selectedRow)
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成关键词结果", "No keyword results yet"),
                systemImage: "text.magnifyingglass",
                message: t("请选择 Target Corpus 和 Reference Corpus，再运行关键词分析。结果会显示哪些词在 Target 中相对更显著。", "Select a target corpus and a reference corpus, then run keyword analysis. The result table shows which terms are statistically more distinctive in the target corpus."),
                suggestions: [
                    t("Target 与 Reference 最好来自可比较但又有差异的文本集合。", "Choose corpora that are comparable in genre or task, but still meaningfully different."),
                    t("建议从默认 Log-Likelihood 开始，再根据需要切换为 Chi-square。", "Start with the default Log-Likelihood setting, then switch to Chi-square if needed.")
                ]
            ) {
                runButton
            }
        }
    }

    func keywordSelectedRowSection(_ selectedRow: KeywordSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(selectedRow.word)
                        .font(.headline)
                    Text("Score \(selectedRow.scoreText) · Log Ratio \(selectedRow.logRatioText) · p \(selectedRow.pValueText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 16) {
                    keywordMetric(t("Target 频次", "Target Freq"), value: selectedRow.targetFrequencyText)
                    keywordMetric(t("Reference 频次", "Reference Freq"), value: selectedRow.referenceFrequencyText)
                    keywordMetric(t("Target 标准频次", "Target Norm Freq"), value: selectedRow.targetNormFrequencyText)
                    keywordMetric(t("Reference 标准频次", "Reference Norm Freq"), value: selectedRow.referenceNormFrequencyText)
                }
            }
        }
    }

    func keywordMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
