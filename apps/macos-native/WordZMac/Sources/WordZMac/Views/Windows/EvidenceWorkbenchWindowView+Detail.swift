import SwiftUI

struct EvidenceWorkbenchDetailPanel: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    let onUpdateStatus: (String, EvidenceReviewStatus) -> Void
    let onMoveSelected: (EvidenceWorkbenchMoveDirection) -> Void
    let onExportMarkdown: () -> Void
    let onExportJSON: () -> Void
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("dossier 整理", "Dossier Organization"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(
                            t("章节标题", "Section Title"),
                            text: $workbench.sectionDraft
                        )
                        .textFieldStyle(.roundedBorder)

                        TextField(
                            t("论点 / Claim", "Claim"),
                            text: $workbench.claimDraft
                        )
                        .textFieldStyle(.roundedBorder)

                        TextField(
                            t("标签（逗号分隔）", "Tags (comma separated)"),
                            text: $workbench.tagsDraft
                        )
                        .textFieldStyle(.roundedBorder)

                        if let summary = workbench.currentDraft.summary(in: languageMode).nilIfEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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

                    if let sentimentMetadata = item.sentimentMetadata {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("情感 Provenance", "Sentiment Provenance"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            detailSummaryRow(
                                t("Raw Result", "Raw Result"),
                                value: sentimentMetadata.rawLabel.title(in: languageMode) + " · " + sentimentScoreSummary(sentimentMetadata.rawScores)
                            )
                            detailSummaryRow(
                                t("Effective Result", "Effective Result"),
                                value: sentimentMetadata.effectiveLabel.title(in: languageMode) + " · " + sentimentScoreSummary(sentimentMetadata.effectiveScores)
                            )
                            detailSummaryRow(
                                t("Review Status", "Review Status"),
                                value: sentimentMetadata.reviewStatus.title(in: languageMode)
                            )
                            detailSummaryRow(
                                t("Backend", "Backend"),
                                value: sentimentMetadata.backendKind.title(in: languageMode) + " · " + sentimentMetadata.backendRevision
                            )
                            if let providerID = sentimentMetadata.providerID,
                               !providerID.isEmpty {
                                let providerValue = providerID + (sentimentMetadata.providerFamily.map {
                                    " · " + $0.title(in: languageMode)
                                } ?? "")
                                detailSummaryRow(
                                    t("Model Provider", "Model Provider"),
                                    value: providerValue
                                )
                            }
                            detailSummaryRow(
                                t("Pack / Profile", "Pack / Profile"),
                                value: sentimentMetadata.domainPackID.title(in: languageMode) + " · " + sentimentMetadata.ruleProfileID
                            )
                            if let inferencePath = sentimentMetadata.inferencePath {
                                detailSummaryRow(
                                    t("推理路径", "Inference Path"),
                                    value: inferencePath.title(in: languageMode)
                                )
                            }
                            if let modelInputKind = sentimentMetadata.modelInputKind {
                                detailSummaryRow(
                                    t("输入模式", "Input Mode"),
                                    value: modelInputKind.title(in: languageMode)
                                )
                            }
                            if let ruleSummary = workbench.normalizedNote(sentimentMetadata.ruleSummary) {
                                detailSummaryRow(t("规则摘要", "Rule Summary"), value: ruleSummary)
                            }
                            if !sentimentMetadata.topRuleTraceSteps.isEmpty {
                                detailSummaryRow(
                                    t("规则步骤", "Rule Steps"),
                                    value: sentimentMetadata.topRuleTraceSteps
                                        .map { "\($0.tag): \($0.note)" }
                                        .joined(separator: " · ")
                                )
                            }
                        }
                    }

                    if let crossAnalysisMetadata = item.crossAnalysisMetadata {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("跨分析 Provenance", "Cross-analysis Provenance"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            detailSummaryRow(t("来源", "Origin"), value: crossAnalysisMetadata.originKind.title(in: languageMode))
                            detailSummaryRow(t("范围", "Scope"), value: crossAnalysisMetadata.scopeSummary)
                            if let focusTerm = workbench.normalizedNote(crossAnalysisMetadata.focusTerm) {
                                detailSummaryRow(t("聚焦词项", "Focus Term"), value: focusTerm)
                            }
                            if let focusedTopicID = workbench.normalizedNote(crossAnalysisMetadata.focusedTopicID) {
                                detailSummaryRow(t("聚焦主题", "Focused Topic"), value: focusedTopicID)
                            }
                            if let groupTitle = workbench.normalizedNote(crossAnalysisMetadata.groupTitle) {
                                detailSummaryRow(t("分组", "Group"), value: groupTitle)
                            }
                            if let compareSide = workbench.normalizedNote(crossAnalysisMetadata.compareSide) {
                                detailSummaryRow(t("对照侧", "Compare Side"), value: compareSide)
                            }
                            if let topicTitle = workbench.normalizedNote(crossAnalysisMetadata.topicTitle) {
                                detailSummaryRow(t("主题标题", "Topic Title"), value: topicTitle)
                            }
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text(t("编排顺序", "Ordering"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Text(t("条目顺序", "Item Order"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                onMoveSelected(.up)
                            } label: {
                                Label(
                                    t("上移条目", "Move Item Up"),
                                    systemImage: EvidenceWorkbenchMoveDirection.up.systemImageName
                                )
                            }
                            .disabled(!workbench.canMoveSelectedItemUp)

                            Button {
                                onMoveSelected(.down)
                            } label: {
                                Label(
                                    t("下移条目", "Move Item Down"),
                                    systemImage: EvidenceWorkbenchMoveDirection.down.systemImageName
                                )
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
                                    Label(
                                        workbench.groupingMode.splitSelectedGroupTitle(in: languageMode),
                                        systemImage: "scissors"
                                    )
                                }
                                .disabled(!workbench.canSplitSelectedGroup)

                                Button {
                                    onRenameSelectedGroup()
                                } label: {
                                    Label(
                                        workbench.groupingMode.renameSelectedGroupTitle(in: languageMode),
                                        systemImage: "pencil"
                                    )
                                }
                                .disabled(!workbench.groupingMode.supportsItemAssignment)

                                Button {
                                    onMergeSelectedGroup()
                                } label: {
                                    Label(
                                        workbench.groupingMode.mergeSelectedGroupTitle(in: languageMode),
                                        systemImage: "arrow.triangle.merge"
                                    )
                                }
                                .disabled(!workbench.groupingMode.supportsItemAssignment)

                                Spacer()
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        Button(t("复制引文", "Copy Citation")) {
                            onCopyCitation(item.id)
                        }
                        Button(t("导出 Dossier", "Export Dossier")) {
                            onExportMarkdown()
                        }
                        .disabled(!workbench.items.contains(where: { $0.reviewStatus == .keep }))
                        Button(t("导出 JSON", "Export JSON")) {
                            onExportJSON()
                        }
                        .disabled(workbench.items.isEmpty)
                        Button(t("保存整理字段", "Save Details")) {
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
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("还没有可阅读的证据条目", "No Evidence Items Yet"))
                    .font(.title3.weight(.semibold))
                Text(
                    t(
                        "先从 KWIC、定位器或原文阅读器把带 provenance 的命中加入工作台，这里就会形成可分组、可整理、可导出的研究 dossier。",
                        "Add provenance-backed hits from KWIC, Locator, or Source Reader to start a grouped, editable, exportable research dossier."
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
