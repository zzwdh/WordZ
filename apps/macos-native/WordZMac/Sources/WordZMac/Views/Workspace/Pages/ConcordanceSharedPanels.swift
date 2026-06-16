import SwiftUI
import WordZShared
import WordZWorkbenchUI

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
            Button(t("导入命中集文件", "Import Hit Set File")) {
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
                Text(t("复查备注", "Review Notes"))
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
            Button(t("导出命中集", "Export Hit Set")) {
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
                if let sourceSummary = savedSetRowSourceSummary(row) {
                    Text(sourceSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
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

    private func savedSetRowSourceSummary(_ row: ConcordanceSavedSetRow) -> String? {
        let source = [row.sourceTitle, row.sourceFileName, row.sourceID]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .first
        guard let source else { return nil }
        if let sourceSentenceId = row.sourceSentenceId {
            return "\(t("来源", "Source")) \(source) · \(t("位置", "Position")) \(sourceSentenceId + 1)"
        }
        return "\(t("来源", "Source")) \(source)"
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
