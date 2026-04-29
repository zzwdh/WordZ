import SwiftUI

@MainActor
protocol ConcordanceSavedSetsPanelState: ObservableObject {
    var savedSets: [ConcordanceSavedSet] { get }
    var selectedSavedSetID: String? { get set }
    var savedSetFilterQuery: String { get set }
    var savedSetNotesDraft: String { get set }
    var selectedSavedSet: ConcordanceSavedSet? { get }
    var hasSavedSetFilter: Bool { get }
    var filteredSelectedSavedSetRows: [ConcordanceSavedSetRow] { get }
    var hasUnsavedSavedSetNotesChanges: Bool { get }
}

extension KWICPageViewModel: ConcordanceSavedSetsPanelState {}
extension LocatorPageViewModel: ConcordanceSavedSetsPanelState {}

struct ConcordanceReadingExportMenu: View {
    let languageMode: AppLanguageMode
    let copyCurrent: (ReadingExportFormat) -> Void
    let copyVisible: (ReadingExportFormat) -> Void
    let exportCurrent: (ReadingExportFormat) -> Void
    let exportVisible: (ReadingExportFormat) -> Void

    var body: some View {
        Menu(t("阅读导出", "Reading Export")) {
            Button(t("Copy Current · 索引行", "Copy Current · Concordance")) {
                copyCurrent(.concordance)
            }
            Button(t("Copy Current · 完整句", "Copy Current · Full Sentence")) {
                copyCurrent(.fullSentence)
            }
            Button(t("Copy Current · 引文格式", "Copy Current · Citation")) {
                copyCurrent(.citation)
            }
            Divider()
            Button(t("Copy Visible · 索引行", "Copy Visible · Concordance")) {
                copyVisible(.concordance)
            }
            Button(t("Copy Visible · 完整句", "Copy Visible · Full Sentence")) {
                copyVisible(.fullSentence)
            }
            Button(t("Copy Visible · 引文格式", "Copy Visible · Citation")) {
                copyVisible(.citation)
            }
            Divider()
            Button(t("Export Current · 索引行", "Export Current · Concordance")) {
                exportCurrent(.concordance)
            }
            Button(t("Export Current · 完整句", "Export Current · Full Sentence")) {
                exportCurrent(.fullSentence)
            }
            Button(t("Export Current · 引文格式", "Export Current · Citation")) {
                exportCurrent(.citation)
            }
            Divider()
            Button(t("Export Visible · 索引行", "Export Visible · Concordance")) {
                exportVisible(.concordance)
            }
            Button(t("Export Visible · 完整句", "Export Visible · Full Sentence")) {
                exportVisible(.fullSentence)
            }
            Button(t("Export Visible · 引文格式", "Export Visible · Citation")) {
                exportVisible(.citation)
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct ConcordanceEvidenceWorkbenchSection: View {
    @ObservedObject var evidenceWorkbench: EvidenceWorkbenchViewModel
    let languageMode: AppLanguageMode
    let addCurrentTitle: String
    let emptyMessage: String
    let currentSelectionAvailable: Bool
    let itemPreviewText: (EvidenceItem) -> String
    let addCurrent: () -> Void
    let openWorkbench: () -> Void
    let setReviewStatus: (String, EvidenceReviewStatus) -> Void
    let saveSelectedNote: () -> Void
    let deleteItem: (String) -> Void

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                if evidenceWorkbench.filteredItems.isEmpty {
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    itemList
                    overflowSummary
                    selectedItemEditor
                }
            }
        }
    }

    private var header: some View {
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
                addCurrent()
            } label: {
                Label(addCurrentTitle, systemImage: "plus")
            }
            .disabled(!currentSelectionAvailable)

            Button(t("查看摘录", "View Clips")) {
                openWorkbench()
            }
        }
    }

    private var itemList: some View {
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
                            Text(itemPreviewText(item))
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
    }

    @ViewBuilder
    private var overflowSummary: some View {
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
    }

    @ViewBuilder
    private var selectedItemEditor: some View {
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
                        set: { setReviewStatus(selectedItem.id, $0) }
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
                        saveSelectedNote()
                    }
                    .disabled(!evidenceWorkbench.hasUnsavedNoteChanges)
                    Button(role: .destructive) {
                        deleteItem(selectedItem.id)
                    } label: {
                        Text(t("删除", "Delete"))
                    }
                    Spacer()
                }
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct ConcordanceSavedSetsSection<ViewModel: ConcordanceSavedSetsPanelState>: View {
    @ObservedObject var viewModel: ViewModel
    let kind: ConcordanceSavedSetKind
    let languageMode: AppLanguageMode
    let canSaveCurrent: Bool
    let canSaveVisible: Bool
    let emptyMessage: String
    let saveCurrent: () -> Void
    let saveVisible: () -> Void
    let importJSON: () -> Void
    let refresh: () -> Void
    let selectSavedSet: (String?) -> Void
    let loadSelected: () -> Void
    let saveFiltered: () -> Void
    let saveNotes: () -> Void
    let exportSelectedJSON: () -> Void
    let deleteSavedSet: (String) -> Void

    var body: some View {
        WorkbenchSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                if viewModel.savedSets.isEmpty {
                    Text(emptyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    savedSetPicker
                    selectedSavedSetDetails
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(t("已保存命中集", "Saved Hit Sets"))
                .font(.headline)
            Spacer()
            Button(t("保存当前", "Save Current")) {
                saveCurrent()
            }
            .disabled(!canSaveCurrent)
            Button(t("保存当前页", "Save Visible")) {
                saveVisible()
            }
            .disabled(!canSaveVisible)
            Button(t("导入 JSON", "Import JSON")) {
                importJSON()
            }
            Button(t("刷新", "Refresh")) {
                refresh()
            }
        }
    }

    private var savedSetPicker: some View {
        Picker(
            t("命中集", "Hit Set"),
            selection: Binding(
                get: { viewModel.selectedSavedSetID ?? "" },
                set: { selectSavedSet($0.isEmpty ? nil : $0) }
            )
        ) {
            ForEach(viewModel.savedSets) { set in
                Text("\(set.name) (\(set.rowCount))")
                    .tag(set.id)
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var selectedSavedSetDetails: some View {
        if let selectedSet = viewModel.selectedSavedSet {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedSet.name)
                    .font(.headline)
                selectedSetMetadata(selectedSet)
                savedSetFiltersAndNotes
                savedSetActions(selectedSet)
                savedSetRowsPreview
                savedSetOverflowSummary
            }
        }
    }

    private func selectedSetMetadata(_ selectedSet: ConcordanceSavedSet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text(selectedSet.corpusName)
                Text(queryLabel + " \(selectedSet.query)")
                if viewModel.hasSavedSetFilter {
                    Text("\(viewModel.filteredSelectedSavedSetRows.count) / \(selectedSet.rowCount) \(t("行", "rows"))")
                } else {
                    Text("\(selectedSet.rowCount) \(t("行", "rows"))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            switch kind {
            case .kwic:
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
            case .locator:
                if let sourceSentenceId = selectedSet.sourceSentenceId {
                    Text(t("起始句", "Source Sentence") + " \(sourceSentenceId + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
    }

    private var savedSetFiltersAndNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        }
    }

    private func savedSetActions(_ selectedSet: ConcordanceSavedSet) -> some View {
        HStack(spacing: 12) {
            Button(viewModel.hasSavedSetFilter ? t("载入筛选结果", "Load Filtered Result") : t("载入结果", "Load Live Result")) {
                loadSelected()
            }
            .disabled(viewModel.filteredSelectedSavedSetRows.isEmpty)
            Button(t("另存精炼版", "Save Refined Copy")) {
                saveFiltered()
            }
            .disabled(viewModel.filteredSelectedSavedSetRows.isEmpty)
            Button(t("保存备注", "Save Notes")) {
                saveNotes()
            }
            .disabled(!viewModel.hasUnsavedSavedSetNotesChanges)
            Button(t("导出 JSON", "Export JSON")) {
                exportSelectedJSON()
            }
            Button(role: .destructive) {
                deleteSavedSet(selectedSet.id)
            } label: {
                Text(t("删除", "Delete"))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var savedSetRowsPreview: some View {
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
                savedSetRowPreview(row)
            }
        }
    }

    private func savedSetRowPreview(_ row: ConcordanceSavedSetRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            WorkbenchConcordanceLineView(
                leftContext: row.leftContext,
                keyword: row.keyword,
                rightContext: row.rightContext
            )
            switch kind {
            case .kwic:
                Text(row.citationText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            case .locator:
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

    @ViewBuilder
    private var savedSetOverflowSummary: some View {
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

    private var queryLabel: String {
        switch kind {
        case .kwic:
            return t("关键词", "Keyword")
        case .locator:
            return t("节点词", "Node")
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
