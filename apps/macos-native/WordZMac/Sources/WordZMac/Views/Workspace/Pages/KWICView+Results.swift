import SwiftUI

extension KWICView {
    @ViewBuilder
    var kwicResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                annotationState: viewModel.annotationState,
                annotationResultCount: scene.filteredRows,
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                onDoubleClick: { onAction(.activateRow($0)) },
                columnKeys: KWICColumnKey.allCases,
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
                emptyMessage: t("当前 KWIC 结果没有可显示的行。", "No KWIC rows to display."),
                accessibilityLabel: "KWIC",
                activationHint: t("使用方向键浏览结果，按 Return 或空格可定位当前选中行。", "Use arrow keys to browse results, then press Return or Space to locate the selected row.")
            ) {
                Text(t("关键词：", "Keyword: ") + scene.query)
                    .font(.headline)
                Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow)")
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

                if let selectedRow = viewModel.selectedSceneRow {
                    HStack(spacing: 8) {
                        Label(t("定位源", "Locator Source"), systemImage: "scope")
                            .font(.caption.weight(.semibold))
                        Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1) · " + t("节点词", "Node") + " \(selectedRow.keyword)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Spacer()
                    }
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
                    sortOptions: Array(KWICSortMode.allCases),
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
                EmptyView()
            } paginationFallback: {
                EmptyView()
            }

            if let selectedRow = viewModel.selectedSceneRow {
                kwicSelectedRowSection(selectedRow)
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成 KWIC 结果", "No KWIC results yet"),
                systemImage: "text.magnifyingglass",
                message: t("输入检索词并运行后，这里会显示可阅读、可复制、可继续定位的索引行。", "Run a keyword search to see concordance lines that are ready for reading, citation copying, and follow-up locating."),
                suggestions: [
                    t("较短的窗口更适合课堂演示，较长的窗口更适合研究解读。", "Shorter windows work well for teaching demos, while longer windows help with research interpretation."),
                    t("双击任意索引行或使用“发送到定位器”可继续查看句内位置。", "Double-click any row or use Send to Locator to continue from that concordance line.")
                ]
            )
        }

        kwicEvidenceWorkbenchSection
        kwicSavedSetsSection
    }

    func kwicSelectedRowSection(_ selectedRow: KWICSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(t("研究阅读视图", "Research Reading View"))
                        .font(.headline)
                    Spacer()
                    Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchConcordanceLineView(
                    leftContext: selectedRow.leftContext,
                    keyword: selectedRow.keyword,
                    rightContext: selectedRow.rightContext
                )

                Text(selectedRow.concordanceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                HStack(spacing: 12) {
                    Button {
                        onAction(.openSourceReader)
                    } label: {
                        Label(t("打开原文视图", "Open Source View"), systemImage: "doc.text.magnifyingglass")
                    }
                    WorkbenchCopyTextButton(
                        title: t("复制引文", "Copy Citation"),
                        text: selectedRow.citationText
                    )
                    Button {
                        onAction(.addCurrentRowToEvidenceWorkbench)
                    } label: {
                        Label(t("加入摘录", "Add to Clips"), systemImage: "text.badge.plus")
                    }
                    ConcordanceReadingExportMenu(
                        languageMode: languageMode,
                        copyCurrent: { onAction(.copyCurrent($0)) },
                        copyVisible: { onAction(.copyVisible($0)) },
                        exportCurrent: { onAction(.exportCurrent($0)) },
                        exportVisible: { onAction(.exportVisible($0)) }
                    )
                    Button {
                        onAction(.activateRow(selectedRow.id))
                    } label: {
                        Label(t("发送到定位器", "Send to Locator"), systemImage: "scope")
                    }
                    Spacer()
                }
            }
        }
    }

    var kwicEvidenceWorkbenchSection: some View {
        ConcordanceEvidenceWorkbenchSection(
            evidenceWorkbench: evidenceWorkbench,
            languageMode: languageMode,
            addCurrentTitle: t("加入当前行", "Add Current Row"),
            emptyMessage: t(
                "把当前 KWIC 行加入摘录后，这里会显示可复查、可标记、可备注的分析片段。",
                "Add the current KWIC row to collect reviewable, annotatable analysis clips here."
            ),
            currentSelectionAvailable: viewModel.selectedSceneRow != nil,
            itemPreviewText: { $0.concordanceText },
            addCurrent: { onAction(.addCurrentRowToEvidenceWorkbench) },
            openWorkbench: { openEvidenceWorkbenchWindow() },
            setReviewStatus: { onAction(.setEvidenceReviewStatus($0, $1)) },
            saveSelectedNote: { onAction(.saveSelectedEvidenceNote) },
            deleteItem: { onAction(.deleteEvidenceItem($0)) }
        )
    }

    var kwicSavedSetsSection: some View {
        ConcordanceSavedSetsSection(
            viewModel: viewModel,
            kind: .kwic,
            languageMode: languageMode,
            canSaveCurrent: viewModel.selectedSceneRow != nil,
            canSaveVisible: !(viewModel.scene?.rows.isEmpty ?? true),
            emptyMessage: t(
                "把当前行或当前页保存为命中集后，这里会显示可回看的结果快照。",
                "Save the current row or visible page as a hit set to keep a reusable concordance snapshot here."
            ),
            saveCurrent: { onAction(.saveCurrentHitSet) },
            saveVisible: { onAction(.saveVisibleHitSet) },
            importJSON: { onAction(.importSavedSetsJSON) },
            refresh: { onAction(.refreshSavedSets) },
            selectSavedSet: { onAction(.selectSavedSet($0)) },
            loadSelected: { onAction(.loadSelectedSavedSet) },
            saveFiltered: { onAction(.saveFilteredSavedSet) },
            saveNotes: { onAction(.saveSelectedSavedSetNotes) },
            exportSelectedJSON: { onAction(.exportSelectedSavedSetJSON) },
            deleteSavedSet: { onAction(.deleteSavedSet($0)) }
        )
    }
}
