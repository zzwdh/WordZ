import SwiftUI

struct EvidenceWorkbenchSelectedItemDetail: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let item: EvidenceItem
    @Binding var showsExportOptions: Bool
    @Binding var showsSourceTrace: Bool
    let onAction: (EvidenceWorkbenchWindowAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EvidenceWorkbenchDetailHeader(item: item, onAction: onAction)

                WorkbenchConcordanceLineView(
                    leftContext: item.leftContext,
                    keyword: item.keyword,
                    rightContext: item.rightContext
                )

                EvidenceWorkbenchDetailBlock(
                    title: t("完整句", "Full Sentence"),
                    content: item.fullSentenceText
                )

                EvidenceWorkbenchNotesSection(workbench: workbench)

                DisclosureGroup(isExpanded: $showsExportOptions) {
                    EvidenceWorkbenchCitationOptionsSection(workbench: workbench, item: item)
                } label: {
                    EvidenceWorkbenchDisclosureLabel(
                        title: t("引文文本", "Citation Text"),
                        subtitle: workbench.citationFormatDraft.title(in: languageMode) +
                            " · " +
                            workbench.citationStyleDraft.title(in: languageMode)
                    )
                }

                DisclosureGroup(isExpanded: $showsSourceTrace) {
                    EvidenceWorkbenchSourceTraceSection(workbench: workbench, item: item)
                } label: {
                    EvidenceWorkbenchDisclosureLabel(
                        title: t("来源与分析记录", "Source and Analysis Trace"),
                        subtitle: item.sourceKind.title(in: languageMode) + " · " + item.corpusName
                    )
                }

                EvidenceWorkbenchDetailActionRow(
                    workbench: workbench,
                    item: item,
                    onAction: onAction
                )
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct EvidenceWorkbenchDetailHeader: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let item: EvidenceItem
    let onAction: (EvidenceWorkbenchWindowAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.keyword.isEmpty ? t("未命名摘录", "Untitled Excerpt") : item.keyword)
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
                    set: { onAction(.updateReviewStatus(itemID: item.id, status: $0)) }
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
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct EvidenceWorkbenchNotesSection: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("摘录备注", "Excerpt Note"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("给自己留一句写作提醒", "Writing Reminder"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $workbench.noteDraft)
                    .font(.body)
                    .frame(minHeight: 120)
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct EvidenceWorkbenchCitationOptionsSection: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let item: EvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EvidenceWorkbenchDetailBlock(
                title: t("引文预览", "Citation Preview"),
                content: item.styledCitationText(
                    format: workbench.citationFormatDraft,
                    style: workbench.citationStyleDraft
                )
            )

            Picker(
                t("引文文本", "Citation Text"),
                selection: $workbench.citationFormatDraft
            ) {
                ForEach(EvidenceCitationFormat.allCases) { format in
                    Text(format.title(in: languageMode))
                        .tag(format)
                }
            }
            .pickerStyle(.segmented)

            Text(workbench.citationFormatDraft.summary(in: languageMode))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(
                t("引用样式", "Reference Style"),
                selection: $workbench.citationStyleDraft
            ) {
                ForEach(EvidenceCitationStyle.allCases) { style in
                    Text(style.title(in: languageMode))
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)

            Text(workbench.citationStyleDraft.summary(in: languageMode))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

struct EvidenceWorkbenchDetailBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}

struct EvidenceWorkbenchDisclosureLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
