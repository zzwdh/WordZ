import Foundation

enum EvidenceMarkdownDossierSupport {
    enum DossierError: LocalizedError {
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有已标记为保留的证据条目。", "There are no kept evidence items to export.", mode: .system)
            }
        }
    }

    static func document(
        items: [EvidenceItem],
        grouping: EvidenceWorkbenchGroupingMode,
        exportedAt: Date = Date()
    ) throws -> PlainTextExportDocument {
        let keptItems = items.filter { $0.reviewStatus == .keep }
        guard !keptItems.isEmpty else {
            throw DossierError.emptySelection
        }

        let exportedAtText = ISO8601DateFormatter().string(from: exportedAt)
        let groups = EvidenceWorkbenchGroupingSupport.makeGroups(
            items: keptItems,
            grouping: grouping,
            mode: .system
        )

        var lines: [String] = [
            "# " + wordZText("研究 dossier", "Research Dossier", mode: .system),
            "",
            wordZText("导出时间", "Exported At", mode: .system) + ": " + exportedAtText,
            wordZText("保留证据", "Kept Items", mode: .system) + ": \(keptItems.count)",
            wordZText("组织方式", "Grouping", mode: .system) + ": " + grouping.title(in: .system)
        ]

        for group in groups {
            lines.append("")
            lines.append("## \(group.title)")
            if let subtitle = normalizedValue(group.subtitle) {
                lines.append("")
                lines.append("> " + subtitle)
            }
            lines.append("")
            lines.append("- " + wordZText("条目数", "Items", mode: .system) + ": \(group.items.count)")

            for (index, item) in group.items.enumerated() {
                lines.append("")
                lines.append("### \(index + 1). \(item.keyword)")
                lines.append("")
                lines.append("- " + wordZText("来源", "Source", mode: .system) + ": " + item.sourceKind.title(in: .system))
                lines.append("- " + wordZText("语料", "Corpus", mode: .system) + ": " + item.corpusName)
                lines.append("- " + wordZText("句号", "Sentence", mode: .system) + ": \(item.sentenceId + 1)")
                lines.append("- " + wordZText("参数", "Parameters", mode: .system) + ": " + item.parameterSummary(in: .system))
                if let savedSetName = normalizedValue(item.savedSetName) {
                    lines.append("- " + wordZText("命中集", "Hit Set", mode: .system) + ": " + savedSetName)
                }
                if let sectionTitle = normalizedValue(item.sectionTitle) {
                    lines.append("- " + wordZText("章节", "Section", mode: .system) + ": " + sectionTitle)
                }
                if let claim = normalizedValue(item.claim) {
                    lines.append("- " + wordZText("论点", "Claim", mode: .system) + ": " + claim)
                }
                if !item.tags.isEmpty {
                    lines.append("- " + wordZText("标签", "Tags", mode: .system) + ": " + item.tags.joined(separator: ", "))
                }
                lines.append("")
                lines.append("#### " + wordZText("索引行", "Concordance", mode: .system))
                lines.append(item.concordanceText)
                lines.append("")
                lines.append("#### " + wordZText("完整句", "Full Sentence", mode: .system))
                lines.append(item.fullSentenceText)
                lines.append("")
                lines.append("#### " + wordZText("引文", "Citation", mode: .system))
                lines.append(item.citationText)
                if let note = normalizedValue(item.note) {
                    lines.append("")
                    lines.append("#### " + wordZText("备注", "Note", mode: .system))
                    lines.append(note)
                }
                if let sentimentMetadata = item.sentimentMetadata {
                    lines.append("")
                    lines.append("#### " + wordZText("情感 Provenance", "Sentiment Provenance", mode: .system))
                    lines.append(contentsOf: sentimentMetadataLines(sentimentMetadata))
                }
                if let crossAnalysisMetadata = item.crossAnalysisMetadata {
                    lines.append("")
                    lines.append("#### " + wordZText("跨分析 Provenance", "Cross-analysis Provenance", mode: .system))
                    lines.append(contentsOf: crossAnalysisMetadataLines(crossAnalysisMetadata))
                }
            }
        }

        return PlainTextExportDocument(
            suggestedName: "research-dossier.md",
            text: lines.joined(separator: "\n"),
            allowedExtension: "md"
        )
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sentimentMetadataLines(
        _ metadata: EvidenceSentimentMetadata
    ) -> [String] {
        var lines = [
            "- " + wordZText("生效标签", "Effective Label", mode: .system) + ": " + metadata.effectiveLabel.title(in: .system),
            "- " + wordZText("原始标签", "Raw Label", mode: .system) + ": " + metadata.rawLabel.title(in: .system),
            "- " + wordZText("后端", "Backend", mode: .system) + ": " + metadata.backendKind.title(in: .system) + " · " + metadata.backendRevision,
            "- " + wordZText("规则包", "Domain Pack", mode: .system) + ": " + metadata.domainPackID.title(in: .system),
            "- " + wordZText("规则配置", "Rule Profile", mode: .system) + ": " + metadata.ruleProfileID,
            "- " + wordZText("审校状态", "Review Status", mode: .system) + ": " + metadata.reviewStatus.title(in: .system),
            "- " + wordZText("原始分数", "Raw Scores", mode: .system) + ": " + sentimentScoreLine(metadata.rawScores),
            "- " + wordZText("生效分数", "Effective Scores", mode: .system) + ": " + sentimentScoreLine(metadata.effectiveScores)
        ]
        if let reviewDecision = metadata.reviewDecision {
            lines.append("- " + wordZText("审校决策", "Review Decision", mode: .system) + ": " + reviewDecision.rawValue)
        }
        if let providerID = normalizedValue(metadata.providerID) {
            var providerLine = providerID
            if let providerFamily = metadata.providerFamily {
                providerLine += " · " + providerFamily.title(in: .system)
            }
            lines.append("- " + wordZText("模型 Provider", "Model Provider", mode: .system) + ": " + providerLine)
        }
        if let inferencePath = metadata.inferencePath {
            lines.append("- " + wordZText("推理路径", "Inference Path", mode: .system) + ": " + inferencePath.title(in: .system))
        }
        if let modelInputKind = metadata.modelInputKind {
            lines.append("- " + wordZText("输入模式", "Input Mode", mode: .system) + ": " + modelInputKind.title(in: .system))
        }
        if let reviewNote = normalizedValue(metadata.reviewNote) {
            lines.append("- " + wordZText("审校备注", "Review Note", mode: .system) + ": " + reviewNote)
        }
        if let ruleSummary = normalizedValue(metadata.ruleSummary) {
            lines.append("- " + wordZText("规则摘要", "Rule Summary", mode: .system) + ": " + ruleSummary)
        }
        if !metadata.topRuleTraceSteps.isEmpty {
            lines.append("- " + wordZText("规则步骤", "Rule Steps", mode: .system) + ": " + metadata.topRuleTraceSteps.map { "\($0.tag): \($0.note)" }.joined(separator: " · "))
        }
        return lines
    }

    private static func crossAnalysisMetadataLines(
        _ metadata: EvidenceCrossAnalysisMetadata
    ) -> [String] {
        var lines = [
            "- " + wordZText("来源", "Origin", mode: .system) + ": " + metadata.originKind.title(in: .system),
            "- " + wordZText("范围", "Scope", mode: .system) + ": " + metadata.scopeSummary
        ]
        if let focusTerm = normalizedValue(metadata.focusTerm) {
            lines.append("- " + wordZText("聚焦词项", "Focus Term", mode: .system) + ": " + focusTerm)
        }
        if let focusedTopicID = normalizedValue(metadata.focusedTopicID) {
            lines.append("- " + wordZText("聚焦主题", "Focused Topic", mode: .system) + ": " + focusedTopicID)
        }
        if let groupTitle = normalizedValue(metadata.groupTitle) {
            lines.append("- " + wordZText("分组", "Group", mode: .system) + ": " + groupTitle)
        }
        if let compareSide = normalizedValue(metadata.compareSide) {
            lines.append("- " + wordZText("对照侧", "Compare Side", mode: .system) + ": " + compareSide)
        }
        if let topicTitle = normalizedValue(metadata.topicTitle) {
            lines.append("- " + wordZText("主题标题", "Topic Title", mode: .system) + ": " + topicTitle)
        }
        return lines
    }

    private static func sentimentScoreLine(_ scores: SentimentScoreTriple) -> String {
        String(
            format: "P %.3f · N %.3f · Neg %.3f · Net %.3f",
            scores.positivityScore,
            scores.neutralityScore,
            scores.negativityScore,
            scores.netScore
        )
    }
}
