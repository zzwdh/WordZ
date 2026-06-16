import SwiftUI
import WordZExport
import WordZShared
import WordZWorkbenchUI

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
                kwicResultHeader(scene)
            } headerTrailing: {
                Text("\(t("当前", "Page")) \(scene.visibleRows) · \(t("筛后", "Filtered")) \(scene.filteredRows) · \(t("总命中", "Total")) \(scene.totalRows)")
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
                    pageSizeLabel: { $0.title(in: languageMode) },
                    prefix: {
                        kwicSourceFilterField
                    },
                    middle: {
                        KWICTableDensityPicker(languageMode: languageMode)
                        Button {
                            KWICTablePreferenceKeys.resetStoredLayout(for: scene.table)
                            onAction(.resetTableLayout)
                        } label: {
                            Label(t("重置表格", "Reset Table"), systemImage: "arrow.counterclockwise")
                        }
                        .help(t("恢复默认列、列宽、列顺序和密度。", "Restore default columns, widths, order, and density."))
                    }
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
                    t("较短的窗口适合快速核对，较长的窗口适合细读上下文。", "Shorter windows work well for quick checks, while longer windows help with close reading."),
                    t("双击任意索引行或使用“发送到定位器”可继续查看句内位置。", "Double-click any row or use Send to Locator to continue from that concordance line.")
                ]
            )
        }

        kwicSavedSetsSection
    }

    func kwicResultHeader(_ scene: KWICSceneModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(t("检索词：", "Query: ") + scene.query)
                    .font(.headline)
                Text(t("窗口", "Window") + " L\(scene.leftWindow) / R\(scene.rightWindow)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }

            Text("\(scene.searchOptions.summaryText) · \(scene.stopwordFilter.summaryText)")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if !scene.sourceFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(t("来源筛选：", "Source filter: ") + scene.sourceFilterQuery)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !scene.searchError.isEmpty {
                Text(scene.searchError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let selectedRow = viewModel.selectedSceneRow {
                HStack(spacing: 8) {
                    Label(t("当前行", "Current Row"), systemImage: "scope")
                        .font(.caption.weight(.semibold))
                    Text(selectedRowHeaderText(selectedRow))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
            }
        }
    }

    func kwicSelectedRowSection(_ selectedRow: KWICSceneRow) -> some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        selectedRowSummary(selectedRow)
                        Spacer(minLength: 0)
                        selectedRowActions(selectedRow)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        selectedRowSummary(selectedRow)
                        selectedRowActions(selectedRow)
                    }
                }

                DisclosureGroup(
                    isExpanded: $isSelectedRowContextExpanded
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        WorkbenchConcordanceLineView(
                            leftContext: selectedRow.leftContext,
                            keyword: selectedRow.keyword,
                            rightContext: selectedRow.rightContext
                        )

                        Text(selectedRow.concordanceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.top, 6)
                } label: {
                    Text(isSelectedRowContextExpanded ? t("收起上下文", "Hide Context") : t("展开上下文", "Show Context"))
                        .font(.caption.weight(.semibold))
                }
            }
        }
    }

    func selectedRowSummary(_ selectedRow: KWICSceneRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t("当前命中行", "Current Hit"))
                .font(.headline)
            Text(selectedRowHeaderText(selectedRow, includeRowNumber: true))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    var kwicSourceFilterField: some View {
        TextField(t("筛选来源/元数据", "Filter source/metadata"), text: $viewModel.sourceFilterQuery)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
            .help(t("按文件名、来源、年份、体裁或标签筛选当前 KWIC 结果。", "Filter the current KWIC rows by file name, source, year, genre, or tags."))
    }

    func selectedRowHeaderText(
        _ selectedRow: KWICSceneRow,
        includeRowNumber: Bool = false
    ) -> String {
        var parts: [String] = []
        if includeRowNumber {
            parts.append("#\(selectedRow.rowNumberText)")
        }
        if !selectedRow.sourceDisplayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(t("来源", "Source") + " " + selectedRow.sourceDisplayText)
        }
        parts.append(t("位置", "Position") + " \(selectedRow.positionText)")
        parts.append(t("节点词", "Node") + " \(selectedRow.keyword)")
        return parts.joined(separator: " · ")
    }

    func selectedRowActions(_ selectedRow: KWICSceneRow) -> some View {
        HStack(spacing: 8) {
            Button {
                onAction(.openSourceReader)
            } label: {
                Label(t("打开来源", "Open Source"), systemImage: "doc.text.magnifyingglass")
            }
            WorkbenchCopyTextButton(
                title: t("复制引文", "Copy Citation"),
                text: selectedRow.citationText
            )
            Button {
                onAction(.activateRow(selectedRow.id))
            } label: {
                Label(t("定位", "Locate"), systemImage: "scope")
            }
            ConcordanceReadingExportMenu(
                languageMode: languageMode,
                copyCurrent: { onAction(.copyCurrent($0)) },
                copyVisible: { onAction(.copyVisible($0)) },
                exportCurrent: { onAction(.exportCurrent($0)) },
                exportVisible: { onAction(.exportVisible($0)) }
            )
        }
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

private struct KWICTableDensityPicker: View {
    @AppStorage(KWICTablePreferenceKeys.density) private var densityRawValue = NativeTableDensityPreset.standard.rawValue

    let languageMode: AppLanguageMode

    var body: some View {
        Picker(wordZText("密度", "Density", mode: languageMode), selection: $densityRawValue) {
            ForEach(NativeTableDensityPreset.allCases, id: \.rawValue) { density in
                Text(title(for: density))
                    .tag(density.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }

    private func title(for density: NativeTableDensityPreset) -> String {
        switch density {
        case .compact:
            return wordZText("紧凑", "Compact", mode: languageMode)
        case .standard:
            return wordZText("标准", "Standard", mode: languageMode)
        case .reading:
            return wordZText("阅读", "Reading", mode: languageMode)
        }
    }
}

private enum KWICTablePreferenceKeys {
    static let storageVersion = "v3"
    static let storageKey = "kwic"
    static let density = "wordz.nativeTable.\(storageVersion).\(storageKey).density"
    static let columnOrder = "wordz.nativeTable.\(storageVersion).\(storageKey).columnOrder"

    static func width(columnID: String) -> String {
        "wordz.nativeTable.\(storageVersion).\(storageKey).\(columnID).width"
    }

    static func resetStoredLayout(for table: NativeTableDescriptor) {
        let defaults = UserDefaults.standard
        for column in table.columns {
            defaults.removeObject(forKey: width(columnID: column.id))
        }
        defaults.removeObject(forKey: columnOrder)
        defaults.removeObject(forKey: density)
    }
}
