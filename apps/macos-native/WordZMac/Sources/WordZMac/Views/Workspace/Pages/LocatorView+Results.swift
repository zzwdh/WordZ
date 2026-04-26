import SwiftUI

extension LocatorView {
    @ViewBuilder
    var locatorResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchToolbarSection {
                WorkbenchResultHeaderRow {
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
                } trailing: {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.totalRows)（\(t("共", "Across")) \(scene.sentenceCount) \(t("句", "sentences"))）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                WorkbenchResultControlsRow {
                    WorkbenchGuardedPageSizePicker(
                        title: t("页大小", "Page Size"),
                        selection: Binding(
                            get: { scene.selectedPageSize },
                            set: { onAction(.changePageSize($0)) }
                        ),
                        totalRows: scene.totalRows
                    ) {
                        $0.title(in: languageMode)
                    }
                } trailing: {
                    WorkbenchResultTrailingControls(
                        columnMenuTitle: t("列", "Columns"),
                        keys: LocatorColumnKey.allCases,
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
            }

            WorkbenchTableCard {
                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onDoubleClick: { onAction(.activateRow($0)) },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = LocatorColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    emptyMessage: t("当前定位结果没有可显示的句子。", "No locator rows to display."),
                    accessibilityLabel: t("定位结果表格", "Locator results table"),
                    activationHint: t("使用方向键浏览结果，按 Return 或空格可重新定位当前句子。", "Use arrow keys to browse results, then press Return or Space to relaunch Locator from the selected sentence.")
                )
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
                    Menu(t("阅读导出", "Reading Export")) {
                        Button(t("Copy Current · 索引行", "Copy Current · Concordance")) {
                            onAction(.copyCurrent(.concordance))
                        }
                        Button(t("Copy Current · 完整句", "Copy Current · Full Sentence")) {
                            onAction(.copyCurrent(.fullSentence))
                        }
                        Button(t("Copy Current · 引文格式", "Copy Current · Citation")) {
                            onAction(.copyCurrent(.citation))
                        }
                        Divider()
                        Button(t("Copy Visible · 索引行", "Copy Visible · Concordance")) {
                            onAction(.copyVisible(.concordance))
                        }
                        Button(t("Copy Visible · 完整句", "Copy Visible · Full Sentence")) {
                            onAction(.copyVisible(.fullSentence))
                        }
                        Button(t("Copy Visible · 引文格式", "Copy Visible · Citation")) {
                            onAction(.copyVisible(.citation))
                        }
                        Divider()
                        Button(t("Export Current · 索引行", "Export Current · Concordance")) {
                            onAction(.exportCurrent(.concordance))
                        }
                        Button(t("Export Current · 完整句", "Export Current · Full Sentence")) {
                            onAction(.exportCurrent(.fullSentence))
                        }
                        Button(t("Export Current · 引文格式", "Export Current · Citation")) {
                            onAction(.exportCurrent(.citation))
                        }
                        Divider()
                        Button(t("Export Visible · 索引行", "Export Visible · Concordance")) {
                            onAction(.exportVisible(.concordance))
                        }
                        Button(t("Export Visible · 完整句", "Export Visible · Full Sentence")) {
                            onAction(.exportVisible(.fullSentence))
                        }
                        Button(t("Export Visible · 引文格式", "Export Visible · Citation")) {
                            onAction(.exportVisible(.citation))
                        }
                    }
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
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(t("摘录", "Clips"))
                        .font(.headline)
                    Spacer()
                    Picker(
                        t("筛选", "Filter"),
                        selection: $evidenceWorkbench.reviewFilter
                    ) {
                        ForEach(EvidenceReviewFilter.allCases) { filter in
                            Text(filter.title(in: languageMode))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.menu)

                    Button {
                        onAction(.addCurrentRowToEvidenceWorkbench)
                    } label: {
                        Label(t("加入当前句", "Add Current Sentence"), systemImage: "plus")
                    }
                    .disabled(viewModel.selectedSceneRow == nil)

                    Button(t("查看摘录", "View Clips")) {
                        openEvidenceWorkbenchWindow()
                    }
                }

                if evidenceWorkbench.filteredItems.isEmpty {
                    Text(
                        t(
                            "把当前定位句加入摘录后，这里会显示可复查、可标记、可备注的分析片段。",
                            "Add the current locator sentence to collect reviewable, annotatable analysis clips here."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(evidenceWorkbench.filteredItems.prefix(5))) { item in
                            Button {
                                evidenceWorkbench.selectedItemID = item.id
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.keyword.isEmpty ? t("未命名条目", "Untitled Item") : item.keyword)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.fullSentenceText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        if let note = evidenceWorkbench.normalizedNote(item.note) {
                                            Text(note)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Text(item.reviewStatus.title(in: languageMode))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(evidenceWorkbench.selectedItemID == item.id ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if evidenceWorkbench.filteredItems.count > 5 {
                        Text(
                            String(
                                format: t("另有 %d 条证据可在独立窗口中继续整理。", "%d more evidence items are available in the dedicated window."),
                                evidenceWorkbench.filteredItems.count - 5
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }

                    if let selectedItem = evidenceWorkbench.selectedItem {
                        VStack(alignment: .leading, spacing: 10) {
                            Divider()
                            Text(selectedItem.keyword.isEmpty ? t("证据详情", "Evidence Detail") : selectedItem.keyword)
                                .font(.subheadline.weight(.semibold))

                            WorkbenchConcordanceLineView(
                                leftContext: selectedItem.leftContext,
                                keyword: selectedItem.keyword,
                                rightContext: selectedItem.rightContext
                            )

                            Text(selectedItem.fullSentenceText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            Picker(
                                t("评审状态", "Review Status"),
                                selection: Binding(
                                    get: { selectedItem.reviewStatus },
                                    set: { onAction(.setEvidenceReviewStatus(selectedItem.id, $0)) }
                                )
                            ) {
                                ForEach(EvidenceReviewStatus.allCases) { status in
                                    Text(status.title(in: languageMode))
                                        .tag(status)
                                }
                            }
                            .pickerStyle(.segmented)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(t("备注", "Note"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $evidenceWorkbench.noteDraft)
                                    .font(.caption)
                                    .frame(minHeight: 80)
                            }

                            HStack(spacing: 12) {
                                WorkbenchCopyTextButton(
                                    title: t("复制引文", "Copy Citation"),
                                    text: selectedItem.citationText
                                )
                                Button(t("保存备注", "Save Note")) {
                                    onAction(.saveSelectedEvidenceNote)
                                }
                                .disabled(!evidenceWorkbench.hasUnsavedNoteChanges)
                                Button(role: .destructive) {
                                    onAction(.deleteEvidenceItem(selectedItem.id))
                                } label: {
                                    Text(t("删除", "Delete"))
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    var locatorSavedSetsSection: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(t("已保存命中集", "Saved Hit Sets"))
                        .font(.headline)
                    Spacer()
                    Button(t("保存当前", "Save Current")) {
                        onAction(.saveCurrentHitSet)
                    }
                    .disabled(viewModel.selectedSceneRow == nil)
                    Button(t("保存当前页", "Save Visible")) {
                        onAction(.saveVisibleHitSet)
                    }
                    .disabled((viewModel.scene?.rows.isEmpty ?? true))
                    Button(t("导入 JSON", "Import JSON")) {
                        onAction(.importSavedSetsJSON)
                    }
                    Button(t("刷新", "Refresh")) {
                        onAction(.refreshSavedSets)
                    }
                }

                if viewModel.savedSets.isEmpty {
                    Text(
                        t(
                            "把当前句或当前页保存为命中集后，这里会显示可回看的定位结果快照。",
                            "Save the current sentence or visible page as a hit set to keep a reusable locator snapshot here."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Picker(
                        t("命中集", "Hit Set"),
                        selection: Binding(
                            get: { viewModel.selectedSavedSetID ?? "" },
                            set: { onAction(.selectSavedSet($0.isEmpty ? nil : $0)) }
                        )
                    ) {
                        ForEach(viewModel.savedSets) { set in
                            Text("\(set.name) (\(set.rowCount))")
                                .tag(set.id)
                        }
                    }
                    .pickerStyle(.menu)

                    if let selectedSet = viewModel.selectedSavedSet {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedSet.name)
                                .font(.headline)
                            HStack(spacing: 12) {
                                Text(selectedSet.corpusName)
                                Text(t("节点词", "Node") + " \(selectedSet.query)")
                                if viewModel.hasSavedSetFilter {
                                    Text("\(viewModel.filteredSelectedSavedSetRows.count) / \(selectedSet.rowCount) \(t("行", "rows"))")
                                } else {
                                    Text("\(selectedSet.rowCount) \(t("行", "rows"))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let sourceSentenceId = selectedSet.sourceSentenceId {
                                Text(t("起始句", "Source Sentence") + " \(sourceSentenceId + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }

                            TextField(
                                t("在命中集内筛选", "Filter Within Hit Set"),
                                text: $viewModel.savedSetFilterQuery
                            )
                            .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(t("研究备注", "Research Notes"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                TextEditor(text: $viewModel.savedSetNotesDraft)
                                    .font(.caption)
                                    .frame(minHeight: 74)
                            }

                            HStack(spacing: 12) {
                                Button(viewModel.hasSavedSetFilter ? t("载入筛选结果", "Load Filtered Result") : t("载入结果", "Load Live Result")) {
                                    onAction(.loadSelectedSavedSet)
                                }
                                .disabled(viewModel.filteredSelectedSavedSetRows.isEmpty)
                                Button(t("另存精炼版", "Save Refined Copy")) {
                                    onAction(.saveFilteredSavedSet)
                                }
                                .disabled(viewModel.filteredSelectedSavedSetRows.isEmpty)
                                Button(t("保存备注", "Save Notes")) {
                                    onAction(.saveSelectedSavedSetNotes)
                                }
                                .disabled(!viewModel.hasUnsavedSavedSetNotesChanges)
                                Button(t("导出 JSON", "Export JSON")) {
                                    onAction(.exportSelectedSavedSetJSON)
                                }
                                Button(role: .destructive) {
                                    onAction(.deleteSavedSet(selectedSet.id))
                                } label: {
                                    Text(t("删除", "Delete"))
                                }
                                Spacer()
                            }

                            if viewModel.filteredSelectedSavedSetRows.isEmpty {
                                Text(
                                    t(
                                        "当前筛选没有匹配行，可以调整关键词后再载入或另存。",
                                        "The current refinement does not match any rows. Adjust the filter before loading or saving."
                                    )
                                )
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            } else {
                                ForEach(Array(viewModel.filteredSelectedSavedSetRows.prefix(3))) { row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        WorkbenchConcordanceLineView(
                                            leftContext: row.leftContext,
                                            keyword: row.keyword,
                                            rightContext: row.rightContext
                                        )
                                        if !row.status.isEmpty {
                                            Text(row.status)
                                                .font(.caption2.weight(.medium))
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(row.fullSentenceText)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }
                            }

                            if viewModel.filteredSelectedSavedSetRows.count > 3 {
                                Text(
                                    String(
                                        format: t("其余 %d 行已保存在命中集中。", "%d more rows are stored in this hit set."),
                                        viewModel.filteredSelectedSavedSetRows.count - 3
                                    )
                                )
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}
