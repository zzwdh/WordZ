import SwiftUI

struct EvidenceWorkbenchDetailPanel: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    @State private var showsExportOptions = false
    @State private var showsSourceTrace = false
    @State private var showsOrderingTools = false

    let onUpdateStatus: (String, EvidenceReviewStatus) -> Void
    let onMoveSelected: (EvidenceWorkbenchMoveDirection) -> Void
    let onExportMarkdown: () -> Void
    let onMoveSelectedGroup: (EvidenceWorkbenchMoveDirection) -> Void
    let onSplitSelectedGroup: () -> Void
    let onRenameSelectedGroup: () -> Void
    let onMergeSelectedGroup: () -> Void
    let onSaveDetails: () -> Void
    let onDeleteItem: (String) -> Void
    let onCopyCitation: (String) -> Void

    var body: some View {
        if let item = workbench.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(for: item)

                    WorkbenchConcordanceLineView(
                        leftContext: item.leftContext,
                        keyword: item.keyword,
                        rightContext: item.rightContext
                    )

                    detailBlock(
                        title: t("完整句", "Full Sentence"),
                        content: item.fullSentenceText
                    )

                    evidenceNotesSection

                    DisclosureGroup(isExpanded: $showsExportOptions) {
                        exportOptionsSection(item)
                    } label: {
                        disclosureLabel(
                            title: t("引文文本", "Citation Text"),
                            subtitle: workbench.citationFormatDraft.title(in: languageMode) +
                                " · " +
                                workbench.citationStyleDraft.title(in: languageMode)
                        )
                    }

                    DisclosureGroup(isExpanded: $showsSourceTrace) {
                        sourceTraceSection(item)
                    } label: {
                        disclosureLabel(
                            title: t("来源与分析记录", "Source and Analysis Trace"),
                            subtitle: item.sourceKind.title(in: languageMode) + " · " + item.corpusName
                        )
                    }

                    DisclosureGroup(isExpanded: $showsOrderingTools) {
                        orderingToolsSection
                    } label: {
                        disclosureLabel(
                            title: t("整理工具", "Organization Tools"),
                            subtitle: workbench.selectedGroup(in: languageMode)?.title ??
                                t("未选择分组", "No Group Selected")
                        )
                    }

                    actionRow(item)
                }
            }
        } else {
            emptyState
        }
    }

    private func header(for item: EvidenceItem) -> some View {
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
    }

    private var evidenceNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("整理信息", "Evidence Notes"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(
                t("证据组", "Evidence Group"),
                text: $workbench.sectionDraft
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                t("发现线索", "Finding"),
                text: $workbench.claimDraft
            )
            .textFieldStyle(.roundedBorder)

            TextField(
                t("标签（逗号分隔）", "Tags (comma separated)"),
                text: $workbench.tagsDraft
            )
            .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text(t("复查备注", "Review Note"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $workbench.noteDraft)
                    .font(.body)
                    .frame(minHeight: 120)
            }

            if let summary = workbench.currentDraft.summary(in: languageMode).nilIfEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exportOptionsSection(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailBlock(
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

    private func sourceTraceSection(_ item: EvidenceItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceSummarySection(item)

            if let sentimentMetadata = item.sentimentMetadata {
                sentimentTraceSection(sentimentMetadata)
            }

            if let crossAnalysisMetadata = item.crossAnalysisMetadata {
                crossAnalysisTraceSection(crossAnalysisMetadata)
            }
        }
        .padding(.top, 8)
    }

    private func sourceSummarySection(_ item: EvidenceItem) -> some View {
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
    }

    private func sentimentTraceSection(_ metadata: EvidenceSentimentMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("情感溯源", "Sentiment Trace"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            detailSummaryRow(
                t("Raw Result", "Raw Result"),
                value: metadata.rawLabel.title(in: languageMode) + " · " + sentimentScoreSummary(metadata.rawScores)
            )
            detailSummaryRow(
                t("Effective Result", "Effective Result"),
                value: metadata.effectiveLabel.title(in: languageMode) + " · " + sentimentScoreSummary(metadata.effectiveScores)
            )
            detailSummaryRow(
                t("Review Status", "Review Status"),
                value: metadata.reviewStatus.title(in: languageMode)
            )
            detailSummaryRow(
                t("Backend", "Backend"),
                value: metadata.backendKind.title(in: languageMode) + " · " + metadata.backendRevision
            )
            if let providerID = metadata.providerID, !providerID.isEmpty {
                let providerValue = providerID + (metadata.providerFamily.map {
                    " · " + $0.title(in: languageMode)
                } ?? "")
                detailSummaryRow(t("Model Provider", "Model Provider"), value: providerValue)
            }
            detailSummaryRow(
                t("Pack / Profile", "Pack / Profile"),
                value: metadata.domainPackID.title(in: languageMode) + " · " + metadata.ruleProfileID
            )
            if let inferencePath = metadata.inferencePath {
                detailSummaryRow(t("推理路径", "Inference Path"), value: inferencePath.title(in: languageMode))
            }
            if let modelInputKind = metadata.modelInputKind {
                detailSummaryRow(t("输入模式", "Input Mode"), value: modelInputKind.title(in: languageMode))
            }
            if let ruleSummary = workbench.normalizedNote(metadata.ruleSummary) {
                detailSummaryRow(t("规则摘要", "Rule Summary"), value: ruleSummary)
            }
            if !metadata.topRuleTraceSteps.isEmpty {
                detailSummaryRow(
                    t("规则步骤", "Rule Steps"),
                    value: metadata.topRuleTraceSteps
                        .map { "\($0.tag): \($0.note)" }
                        .joined(separator: " · ")
                )
            }
        }
    }

    private func crossAnalysisTraceSection(_ metadata: EvidenceCrossAnalysisMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("跨分析溯源", "Cross-analysis Trace"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            detailSummaryRow(t("来源", "Origin"), value: metadata.originKind.title(in: languageMode))
            detailSummaryRow(t("范围", "Scope"), value: metadata.scopeSummary)
            if let focusTerm = workbench.normalizedNote(metadata.focusTerm) {
                detailSummaryRow(t("聚焦词项", "Focus Term"), value: focusTerm)
            }
            if let focusedTopicID = workbench.normalizedNote(metadata.focusedTopicID) {
                detailSummaryRow(t("聚焦主题", "Focused Topic"), value: focusedTopicID)
            }
            if let groupTitle = workbench.normalizedNote(metadata.groupTitle) {
                detailSummaryRow(t("分组", "Group"), value: groupTitle)
            }
            if let compareSide = workbench.normalizedNote(metadata.compareSide) {
                detailSummaryRow(t("对照侧", "Compare Side"), value: compareSide)
            }
            if let topicTitle = workbench.normalizedNote(metadata.topicTitle) {
                detailSummaryRow(t("主题标题", "Topic Title"), value: topicTitle)
            }
        }
    }

    private var orderingToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(t("条目顺序", "Item Order"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onMoveSelected(.up)
                } label: {
                    Label(t("上移条目", "Move Item Up"), systemImage: EvidenceWorkbenchMoveDirection.up.systemImageName)
                }
                .disabled(!workbench.canMoveSelectedItemUp)

                Button {
                    onMoveSelected(.down)
                } label: {
                    Label(t("下移条目", "Move Item Down"), systemImage: EvidenceWorkbenchMoveDirection.down.systemImageName)
                }
                .disabled(!workbench.canMoveSelectedItemDown)

                Spacer()
            }

            if let selectedGroup = workbench.selectedGroup(in: languageMode) {
                Text(
                    workbench.groupingMode.currentGroupTitle(in: languageMode) +
                        ": " +
                        selectedGroup.title +
                        " · " +
                        selectedGroup.itemCountSummary
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button {
                        onMoveSelectedGroup(.up)
                    } label: {
                        Label(
                            workbench.groupingMode.moveSelectedGroupTitle(.up, in: languageMode),
                            systemImage: EvidenceWorkbenchMoveDirection.up.systemImageName
                        )
                    }
                    .disabled(!workbench.canMoveSelectedGroupUp)

                    Button {
                        onMoveSelectedGroup(.down)
                    } label: {
                        Label(
                            workbench.groupingMode.moveSelectedGroupTitle(.down, in: languageMode),
                            systemImage: EvidenceWorkbenchMoveDirection.down.systemImageName
                        )
                    }
                    .disabled(!workbench.canMoveSelectedGroupDown)

                    Button {
                        onSplitSelectedGroup()
                    } label: {
                        Label(workbench.groupingMode.splitSelectedGroupTitle(in: languageMode), systemImage: "scissors")
                    }
                    .disabled(!workbench.canSplitSelectedGroup)

                    Button {
                        onRenameSelectedGroup()
                    } label: {
                        Label(workbench.groupingMode.renameSelectedGroupTitle(in: languageMode), systemImage: "pencil")
                    }
                    .disabled(!workbench.groupingMode.supportsItemAssignment)

                    Button {
                        onMergeSelectedGroup()
                    } label: {
                        Label(workbench.groupingMode.mergeSelectedGroupTitle(in: languageMode), systemImage: "arrow.triangle.merge")
                    }
                    .disabled(!workbench.groupingMode.supportsItemAssignment)

                    Spacer()
                }
            }
        }
        .padding(.top, 8)
    }

    private func actionRow(_ item: EvidenceItem) -> some View {
        HStack(spacing: 12) {
            Button(t("复制引文", "Copy Citation")) {
                onCopyCitation(item.id)
            }

            Button(t("保存保留条目…", "Save Kept Items…")) {
                onExportMarkdown()
            }
            .disabled(!workbench.items.contains(where: { $0.reviewStatus == .keep }))

            Button(t("保存整理", "Save Notes")) {
                onSaveDetails()
            }
            .disabled(!workbench.hasUnsavedDetailChanges)

            Button(role: .destructive) {
                onDeleteItem(item.id)
            } label: {
                Text(t("删除条目", "Delete Item"))
            }

            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("还没有可阅读的证据条目", "No Evidence Items Yet"))
                .font(.title3.weight(.semibold))
            Text(
                t(
                    "先从 KWIC、定位器或原文阅读器加入证据；这里会保留上下文、来源参数和复查备注，方便之后带到真正的写作工具。",
                    "Add evidence from KWIC, Locator, or Source Reader; this basket keeps context, source traces, and review notes for handoff to your writing tools."
                )
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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

    private func disclosureLabel(title: String, subtitle: String) -> some View {
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

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private func sentimentScoreSummary(_ scores: SentimentScoreTriple) -> String {
        String(
            format: "P %.3f · N %.3f · Neg %.3f · Net %.3f",
            scores.positivityScore,
            scores.neutralityScore,
            scores.negativityScore,
            scores.netScore
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
