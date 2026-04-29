import SwiftUI

extension TokenizeView {
    @ViewBuilder
    var tokenizeResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                columnKeys: TokenizeColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onSortByColumn: { onAction(.sortByColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前分词结果没有可显示的 token。", "No token rows to display."),
                accessibilityLabel: t("分词结果表格", "Tokenization results table"),
                activationHint: t("使用方向键浏览分词结果。", "Use arrow keys to browse tokenization results.")
            ) {
                Text(scene.query.isEmpty ? t("显示全部 token", "Showing all tokens") : t("过滤 token：", "Filter: ") + scene.query)
                    .font(.headline)
                tokenizeSummaryRow(scene)
                if !scene.searchError.isEmpty {
                    Text(scene.searchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } headerTrailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleTokens) / \(scene.filteredTokens)（\(t("总计", "Total")) \(scene.totalTokens)）")
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
                    sortOptions: Array(TokenizeSortMode.allCases),
                    sortLabel: { $0.title(in: languageMode) },
                    pageSizeTitle: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.sorting.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.filteredTokens,
                    pageSizeLabel: { $0.title(in: languageMode) }
                )
            } tableSupplement: {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 12)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(scene.metrics) { item in
                        WorkbenchMetricCard(title: item.title, value: item.value)
                    }
                }

                if let selectedRow = viewModel.selectedSceneRow {
                    tokenizeSelectionCard(selectedRow, scene: scene)
                }
            } paginationFallback: {
                EmptyView()
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成分词结果", "No tokenization results yet"),
                systemImage: "text.word.spacing",
                message: t("先运行一次分词，WordZ 会把 token、lemma、词类和脚本信息一起整理好，方便你继续做筛选、导出和教学展示。", "Run tokenization once and WordZ will organize tokens, lemmas, lexical classes, and script information for filtering, export, and teaching-oriented reading.")
            )
        }
    }

    func tokenizeSummaryRow(_ scene: TokenizeSceneModel) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Label(scene.searchOptions.summaryText, systemImage: "magnifyingglass")
                Label(scene.stopwordFilter.summaryText, systemImage: "line.3.horizontal.decrease.circle")
                Label(scene.languagePreset.title(in: languageMode), systemImage: "globe")
                Label(scene.lemmaStrategy.title(in: languageMode), systemImage: "character.book.closed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(scene.languagePreset.title(in: languageMode)) · \(scene.lemmaStrategy.title(in: languageMode))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    func tokenizeSelectionCard(_ row: TokenizeSceneRow, scene: TokenizeSceneModel) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Label(t("当前选中 token", "Selected Token"), systemImage: "text.cursor")
                        .font(.headline)
                    Spacer(minLength: 8)
                    Text(scene.languagePresetSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        tokenPill(title: t("原词", "Original"), value: row.original)
                        tokenPill(title: t("规范词", "Normalized"), value: row.normalized)
                        tokenPill(title: t("Lemma", "Lemma"), value: row.lemma)
                    }
                    HStack(spacing: 12) {
                        tokenPill(title: t("原词", "Original"), value: row.original)
                        tokenPill(title: t("规范词", "Normalized"), value: row.normalized)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Label(row.lexicalClass, systemImage: "tag")
                        Label(row.script, systemImage: "character.textbox")
                        Text(scene.annotationSummary)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Label(row.lexicalClass, systemImage: "tag")
                        Label(row.script, systemImage: "character.textbox")
                        Text(scene.annotationSummary)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(row.sentenceText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func tokenPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
