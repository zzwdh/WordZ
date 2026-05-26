import SwiftUI

struct EvidenceWorkbenchSourceTraceSection: View {
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    let item: EvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EvidenceWorkbenchSourceSummarySection(workbench: workbench, item: item)

            if let sentimentMetadata = item.sentimentMetadata {
                EvidenceWorkbenchSentimentTraceSection(
                    workbench: workbench,
                    metadata: sentimentMetadata
                )
            }

            if let crossAnalysisMetadata = item.crossAnalysisMetadata {
                EvidenceWorkbenchCrossAnalysisTraceSection(
                    workbench: workbench,
                    metadata: crossAnalysisMetadata
                )
            }
        }
        .padding(.top, 8)
    }
}

private struct EvidenceWorkbenchSourceSummarySection: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let item: EvidenceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("来源摘要", "Source Summary"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            EvidenceWorkbenchDetailSummaryRow(t("来源", "Source"), value: item.sourceKind.title(in: languageMode))
            EvidenceWorkbenchDetailSummaryRow(t("语料", "Corpus"), value: item.corpusName)
            EvidenceWorkbenchDetailSummaryRow(t("句号", "Sentence"), value: "\(item.sentenceId + 1)")
            EvidenceWorkbenchDetailSummaryRow(t("参数", "Parameters"), value: item.parameterSummary(in: languageMode))
            if let savedSetName = workbench.normalizedNote(item.savedSetName) {
                EvidenceWorkbenchDetailSummaryRow(t("命中集", "Hit Set"), value: savedSetName)
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct EvidenceWorkbenchSentimentTraceSection: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let metadata: EvidenceSentimentMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("情感溯源", "Sentiment Trace"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            EvidenceWorkbenchDetailSummaryRow(
                t("Raw Result", "Raw Result"),
                value: metadata.rawLabel.title(in: languageMode) + " · " + sentimentScoreSummary(metadata.rawScores)
            )
            EvidenceWorkbenchDetailSummaryRow(
                t("Effective Result", "Effective Result"),
                value: metadata.effectiveLabel.title(in: languageMode) + " · " + sentimentScoreSummary(metadata.effectiveScores)
            )
            EvidenceWorkbenchDetailSummaryRow(
                t("Review Status", "Review Status"),
                value: metadata.reviewStatus.title(in: languageMode)
            )
            EvidenceWorkbenchDetailSummaryRow(
                t("Backend", "Backend"),
                value: metadata.backendKind.title(in: languageMode) + " · " + metadata.backendRevision
            )
            if let providerID = metadata.providerID, !providerID.isEmpty {
                let providerValue = providerID + (metadata.providerFamily.map {
                    " · " + $0.title(in: languageMode)
                } ?? "")
                EvidenceWorkbenchDetailSummaryRow(t("Model Provider", "Model Provider"), value: providerValue)
            }
            EvidenceWorkbenchDetailSummaryRow(
                t("Pack / Profile", "Pack / Profile"),
                value: metadata.domainPackID.title(in: languageMode) + " · " + metadata.ruleProfileID
            )
            if let inferencePath = metadata.inferencePath {
                EvidenceWorkbenchDetailSummaryRow(t("推理路径", "Inference Path"), value: inferencePath.title(in: languageMode))
            }
            if let modelInputKind = metadata.modelInputKind {
                EvidenceWorkbenchDetailSummaryRow(t("输入模式", "Input Mode"), value: modelInputKind.title(in: languageMode))
            }
            if let ruleSummary = workbench.normalizedNote(metadata.ruleSummary) {
                EvidenceWorkbenchDetailSummaryRow(t("规则摘要", "Rule Summary"), value: ruleSummary)
            }
            if !metadata.topRuleTraceSteps.isEmpty {
                EvidenceWorkbenchDetailSummaryRow(
                    t("规则步骤", "Rule Steps"),
                    value: metadata.topRuleTraceSteps
                        .map { "\($0.tag): \($0.note)" }
                        .joined(separator: " · ")
                )
            }
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

private struct EvidenceWorkbenchCrossAnalysisTraceSection: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workbench: EvidenceWorkbenchViewModel

    let metadata: EvidenceCrossAnalysisMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("跨分析溯源", "Cross-analysis Trace"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            EvidenceWorkbenchDetailSummaryRow(t("来源", "Origin"), value: metadata.originKind.title(in: languageMode))
            EvidenceWorkbenchDetailSummaryRow(t("范围", "Scope"), value: metadata.scopeSummary)
            if let focusTerm = workbench.normalizedNote(metadata.focusTerm) {
                EvidenceWorkbenchDetailSummaryRow(t("聚焦词项", "Focus Term"), value: focusTerm)
            }
            if let focusedTopicID = workbench.normalizedNote(metadata.focusedTopicID) {
                EvidenceWorkbenchDetailSummaryRow(t("聚焦主题", "Focused Topic"), value: focusedTopicID)
            }
            if let groupTitle = workbench.normalizedNote(metadata.groupTitle) {
                EvidenceWorkbenchDetailSummaryRow(t("分组", "Group"), value: groupTitle)
            }
            if let compareSide = workbench.normalizedNote(metadata.compareSide) {
                EvidenceWorkbenchDetailSummaryRow(t("对照侧", "Compare Side"), value: compareSide)
            }
            if let topicTitle = workbench.normalizedNote(metadata.topicTitle) {
                EvidenceWorkbenchDetailSummaryRow(t("主题标题", "Topic Title"), value: topicTitle)
            }
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct EvidenceWorkbenchDetailSummaryRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
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
}
