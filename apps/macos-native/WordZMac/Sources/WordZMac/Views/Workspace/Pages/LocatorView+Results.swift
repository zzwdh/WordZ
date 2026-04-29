import SwiftUI

extension LocatorView {
    @ViewBuilder
    var locatorResultsSection: some View {
        if let scene = viewModel.scene {
            AnalysisResultTableSection(
                descriptor: scene.table,
                snapshot: scene.tableSnapshot,
                selectedRowID: viewModel.selectedRowID,
                onSelectionChange: { onAction(.selectRow($0)) },
                onDoubleClick: { onAction(.activateRow($0)) },
                columnKeys: LocatorColumnKey.allCases,
                columnMenuTitle: t("列", "Columns"),
                columnLabel: { scene.columnTitle(for: $0, mode: languageMode) },
                isColumnVisible: { scene.column(for: $0)?.isVisible ?? false },
                onToggleColumn: { onAction(.toggleColumn($0)) },
                onToggleColumnFromHeader: { onAction(.toggleColumn($0)) },
                pagination: scene.pagination,
                onPreviousPage: { onAction(.previousPage) },
                onNextPage: { onAction(.nextPage) },
                emptyMessage: t("当前定位结果没有可显示的句子。", "No locator rows to display."),
                accessibilityLabel: t("定位结果表格", "Locator results table"),
                activationHint: t("使用方向键浏览结果，按 Return 或空格可重新定位当前句子。", "Use arrow keys to browse results, then press Return or Space to relaunch Locator from the selected sentence.")
            ) {
                Text(t("句", "Sentence") + " \(scene.source.sentenceId + 1) · " + t("节点词", "Node") + " \(scene.source.keyword)")
                    .font(.headline)
                if let selectedRow = viewModel.selectedSceneRow {
                    Text(t("当前选择：句", "Selected: sentence") + " \(selectedRow.sentenceId + 1) · \(selectedRow.nodeWord.isEmpty ? t("无节点词", "No node") : selectedRow.nodeWord)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text(selectedRow.text)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            } headerTrailing: {
                Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)（\(t("共", "Across")) \(scene.sentenceCount) \(t("句", "sentences"))）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } leadingControls: {
                WorkbenchTablePageSizeControls(
                    title: t("页大小", "Page Size"),
                    selectedPageSize: Binding(
                        get: { scene.selectedPageSize },
                        set: { onAction(.changePageSize($0)) }
                    ),
                    totalRows: scene.totalRows
                ) {
                    $0.title(in: languageMode)
                }
            } tableSupplement: {
                EmptyView()
            } paginationFallback: {
                EmptyView()
            }

            if let selectedRow = viewModel.selectedSceneRow {
                locatorSelectedRowSection(selectedRow)
            }
        } else {
            WorkbenchEmptyStateCard(
                title: t("尚未生成定位结果", "No locator results yet"),
                systemImage: "scope",
                message: t("先从 KWIC 选择一条索引行，再运行定位器，这里会显示句内位置、完整句子和可复制的研究引文。", "Choose a concordance line from KWIC, then run Locator to inspect its sentence position, full sentence, and a citation-ready excerpt."),
                suggestions: [
                    t("定位器适合确认节点词是否真的是你要研究的用法。", "Use Locator to verify whether the node really shows the usage you want to study."),
                    t("双击任意句子可以把它作为新的定位源继续展开。", "Double-click any sentence to promote it as the next locator source.")
                ]
            )
        }

        locatorEvidenceWorkbenchSection
        locatorSavedSetsSection
    }

    func locatorSelectedRowSection(_ selectedRow: LocatorSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(t("句内定位视图", "Sentence Locator View"))
                        .font(.headline)
                    Spacer()
                    if !selectedRow.status.isEmpty {
                        Text(selectedRow.status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(t("句", "Sentence") + " \(selectedRow.sentenceId + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchConcordanceLineView(
                    leftContext: selectedRow.leftWords,
                    keyword: selectedRow.nodeWord,
                    rightContext: selectedRow.rightWords
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(t("完整原句", "Full Sentence"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selectedRow.text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

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
                        Label(t("以此句继续定位", "Continue from This Sentence"), systemImage: "arrowshape.turn.up.right")
                    }
                    Spacer()
                }
            }
        }
    }

    var locatorEvidenceWorkbenchSection: some View {
        ConcordanceEvidenceWorkbenchSection(
            evidenceWorkbench: evidenceWorkbench,
            languageMode: languageMode,
            addCurrentTitle: t("加入当前句", "Add Current Sentence"),
            emptyMessage: t(
                "把当前定位句加入摘录后，这里会显示可复查、可标记、可备注的分析片段。",
                "Add the current locator sentence to collect reviewable, annotatable analysis clips here."
            ),
            currentSelectionAvailable: viewModel.selectedSceneRow != nil,
            itemPreviewText: { $0.fullSentenceText },
            addCurrent: { onAction(.addCurrentRowToEvidenceWorkbench) },
            openWorkbench: { openEvidenceWorkbenchWindow() },
            setReviewStatus: { onAction(.setEvidenceReviewStatus($0, $1)) },
            saveSelectedNote: { onAction(.saveSelectedEvidenceNote) },
            deleteItem: { onAction(.deleteEvidenceItem($0)) }
        )
    }

    var locatorSavedSetsSection: some View {
        ConcordanceSavedSetsSection(
            viewModel: viewModel,
            kind: .locator,
            languageMode: languageMode,
            canSaveCurrent: viewModel.selectedSceneRow != nil,
            canSaveVisible: !(viewModel.scene?.rows.isEmpty ?? true),
            emptyMessage: t(
                "把当前句或当前页保存为命中集后，这里会显示可回看的定位结果快照。",
                "Save the current sentence or visible page as a hit set to keep a reusable locator snapshot here."
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
