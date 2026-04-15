import SwiftUI

extension KWICView {
    @ViewBuilder
    var kwicResultsSection: some View {
        if let scene = viewModel.scene {
            WorkbenchToolbarSection {
                WorkbenchResultHeaderRow {
                    Text(t("关键词：", "Keyword: ") + scene.query)
                        .font(.headline)
                    Text(t("窗口：", "Window: ") + "L\(scene.leftWindow) / R\(scene.rightWindow)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } trailing: {
                    Text("\(t("显示", "Showing")) \(scene.visibleRows) / \(scene.filteredRows) / \(scene.totalRows)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

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

                WorkbenchResultControlsRow {
                    HStack(spacing: 12) {
                        WorkbenchMenuPicker(
                            title: t("排序", "Sort"),
                            selection: Binding(
                                get: { scene.sorting.selectedSort },
                                set: { onAction(.changeSort($0)) }
                            ),
                            options: Array(KWICSortMode.allCases)
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
                } trailing: {
                    WorkbenchResultTrailingControls(
                        columnMenuTitle: t("列", "Columns"),
                        keys: KWICColumnKey.allCases,
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
                    onSortByColumn: { columnID in
                        guard let column = KWICColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = KWICColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    allowsMultipleSelection: false,
                    emptyMessage: t("当前 KWIC 结果没有可显示的行。", "No KWIC rows to display."),
                    accessibilityLabel: "KWIC",
                    activationHint: t("使用方向键浏览结果，按 Return 或空格可定位当前选中行。", "Use arrow keys to browse results, then press Return or Space to locate the selected row.")
                )
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
                        Label(t("加入证据工作台", "Add to Evidence Workbench"), systemImage: "text.badge.plus")
                    }
                    Button(t("保存语料集", "Save Corpus Set")) {
                        onAction(.saveCorpusSet)
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
                        Label(t("发送到定位器", "Send to Locator"), systemImage: "scope")
                    }
                    Spacer()
                }
            }
        }
    }

    var kwicEvidenceWorkbenchSection: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(t("证据工作台", "Evidence Workbench"))
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
                        Label(t("加入当前行", "Add Current Row"), systemImage: "plus")
                    }
                    .disabled(viewModel.selectedSceneRow == nil)

                    Button(t("打开独立窗口", "Open Window")) {
                        openEvidenceWorkbenchWindow()
                    }
                }

                if evidenceWorkbench.filteredItems.isEmpty {
                    Text(
                        t(
                            "把当前 KWIC 行加入证据工作台后，这里会显示可复查、可标记、可备注的研究摘录。",
                            "Add the current KWIC row to start a reviewable, annotatable evidence notebook here."
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
                                        Text(item.concordanceText)
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

    var kwicSavedSetsSection: some View {
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
                            "把当前行或当前页保存为命中集后，这里会显示可回看的结果快照。",
                            "Save the current row or visible page as a hit set to keep a reusable concordance snapshot here."
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
                                Text(t("关键词", "Keyword") + " \(selectedSet.query)")
                                if viewModel.hasSavedSetFilter {
                                    Text("\(viewModel.filteredSelectedSavedSetRows.count) / \(selectedSet.rowCount) \(t("行", "rows"))")
                                } else {
                                    Text("\(selectedSet.rowCount) \(t("行", "rows"))")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let searchOptions = selectedSet.searchOptions {
                                Text(searchOptions.summaryText(in: languageMode))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            if let stopwordFilter = selectedSet.stopwordFilter {
                                Text(stopwordFilter.summaryText(in: languageMode))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
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
                                        Text(row.citationText)
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
