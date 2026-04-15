import SwiftUI

struct EvidenceWorkbenchWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var workbench: EvidenceWorkbenchViewModel

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _workbench = ObservedObject(wrappedValue: workspace.evidenceWorkbench)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            NavigationSplitView {
                List(selection: $workbench.selectedItemID) {
                    ForEach(workbench.filteredItems) { item in
                        evidenceListRow(item)
                            .tag(item.id)
                    }
                }
                .listStyle(.sidebar)
            } detail: {
                EvidenceWorkbenchDetailPanel(
                    workbench: workbench,
                    onUpdateStatus: { itemID, status in
                        Task { await workspace.updateEvidenceReviewStatus(itemID: itemID, reviewStatus: status) }
                    },
                    onExportMarkdown: {
                        Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onExportJSON: {
                        Task { await workspace.exportEvidenceJSON(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onSaveNote: {
                        Task { await workspace.saveSelectedEvidenceNote() }
                    },
                    onDeleteItem: { itemID in
                        Task { await workspace.deleteEvidenceItem(itemID) }
                    },
                    onCopyCitation: { itemID in
                        Task { await workspace.copyEvidenceCitation(itemID: itemID) }
                    }
                )
                .padding(20)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .adaptiveWindowScaffold(for: .evidenceWorkbench)
        .bindWindowRoute(.evidenceWorkbench, titleProvider: { mode in
            NativeWindowRoute.evidenceWorkbench.title(in: mode)
        })
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .evidenceWorkbench))
        .task {
            await workspace.initializeIfNeeded()
            await workspace.refreshEvidenceItems()
        }
        .frame(minWidth: 920, minHeight: 640)
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("证据条目工作台", "Evidence Workbench"))
                    .font(.title3.weight(.semibold))
                Text(
                    String(
                        format: t("当前筛选下共有 %d 条证据。", "%d evidence items are currently visible."),
                        workbench.filteredItems.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Picker(
                t("筛选", "Filter"),
                selection: $workbench.reviewFilter
            ) {
                ForEach(EvidenceReviewFilter.allCases) { filter in
                    Text(filter.title(in: languageMode))
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)

            Button(t("导出 Markdown", "Export Markdown")) {
                Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
            }
            .disabled(!workbench.items.contains(where: { $0.reviewStatus == .keep }))

            Button(t("导出 JSON", "Export JSON")) {
                Task { await workspace.exportEvidenceJSON(preferredWindowRoute: .evidenceWorkbench) }
            }
            .disabled(workbench.items.isEmpty)
        }
        .padding(20)
    }

    @ViewBuilder
    private func evidenceListRow(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.keyword.isEmpty ? t("未命名条目", "Untitled Item") : item.keyword)
                    .lineLimit(1)
                Spacer()
                Text(item.reviewStatus.title(in: languageMode))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(item.corpusName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(item.concordanceText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            if let note = workbench.normalizedNote(item.note) {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct EvidenceWorkbenchDetailPanel: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    let onUpdateStatus: (String, EvidenceReviewStatus) -> Void
    let onExportMarkdown: () -> Void
    let onExportJSON: () -> Void
    let onSaveNote: () -> Void
    let onDeleteItem: (String) -> Void
    let onCopyCitation: (String) -> Void

    var body: some View {
        if let item = workbench.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.keyword.isEmpty ? t("证据条目", "Evidence Item") : item.keyword)
                                .font(.title3.weight(.semibold))
                            Text(item.sourceKind.title(in: languageMode) + " · " + item.corpusName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker(
                            t("评审状态", "Review Status"),
                            selection: Binding(
                                get: { item.reviewStatus },
                                set: { onUpdateStatus(item.id, $0) }
                            )
                        ) {
                            ForEach(EvidenceReviewStatus.allCases) { status in
                                Text(status.title(in: languageMode))
                                    .tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }

                    WorkbenchConcordanceLineView(
                        leftContext: item.leftContext,
                        keyword: item.keyword,
                        rightContext: item.rightContext
                    )

                    detailBlock(
                        title: t("完整句", "Full Sentence"),
                        content: item.fullSentenceText
                    )

                    detailBlock(
                        title: t("引文", "Citation"),
                        content: item.citationText
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("来源摘要", "Source Summary"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        detailSummaryRow(t("来源", "Source"), value: item.sourceKind.title(in: languageMode))
                        detailSummaryRow(t("语料", "Corpus"), value: item.corpusName)
                        detailSummaryRow(t("句号", "Sentence"), value: "\(item.sentenceId + 1)")
                        detailSummaryRow(t("参数", "Parameters"), value: item.parameterSummary(in: languageMode))
                        if let savedSetName = workbench.normalizedNote(item.savedSetName) {
                            detailSummaryRow(t("命中集", "Hit Set"), value: savedSetName)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("研究备注", "Research Note"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $workbench.noteDraft)
                            .font(.body)
                            .frame(minHeight: 120)
                    }

                    HStack(spacing: 12) {
                        Button(t("复制引文", "Copy Citation")) {
                            onCopyCitation(item.id)
                        }
                        Button(t("导出证据包", "Export Packet")) {
                            onExportMarkdown()
                        }
                        .disabled(!workbench.items.contains(where: { $0.reviewStatus == .keep }))
                        Button(t("导出 JSON", "Export JSON")) {
                            onExportJSON()
                        }
                        .disabled(workbench.items.isEmpty)
                        Button(t("保存备注", "Save Note")) {
                            onSaveNote()
                        }
                        .disabled(!workbench.hasUnsavedNoteChanges)
                        Button(role: .destructive) {
                            onDeleteItem(item.id)
                        } label: {
                            Text(t("删除条目", "Delete Item"))
                        }
                        Spacer()
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("还没有可阅读的证据条目", "No Evidence Items Yet"))
                    .font(.title3.weight(.semibold))
                Text(
                    t(
                        "先从 KWIC 或 Locator 把当前命中行加入证据工作台，这里就会形成可复查、可整理、可导出的阅读面板。",
                        "Add rows from KWIC or Locator to start a reviewable, editable, exportable evidence notebook here."
                    )
                )
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func detailBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func detailSummaryRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
