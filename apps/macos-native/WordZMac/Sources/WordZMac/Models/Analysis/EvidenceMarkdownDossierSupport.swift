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
        let itemNumbers = evidenceNumberLookup(groups: groups)

        var lines: [String] = [
            "# " + wordZText("研究 dossier", "Research Dossier", mode: .system),
            "",
            wordZText("导出时间", "Exported At", mode: .system) + ": " + exportedAtText,
            wordZText("保留证据", "Kept Items", mode: .system) + ": \(keptItems.count)",
            wordZText("组织方式", "Grouping", mode: .system) + ": " + grouping.title(in: .system)
        ]

        lines.append("")
        lines.append("## " + wordZText("方法摘要", "Method Summary", mode: .system))
        lines.append(contentsOf: methodSummaryLines(items: keptItems, groups: groups))
        lines.append("")
        lines.append("## " + wordZText("证据索引", "Evidence Index", mode: .system))
        lines.append(contentsOf: evidenceIndexLines(groups: groups, itemNumbers: itemNumbers))
        lines.append("")
        lines.append("## " + wordZText("元数据缺口", "Metadata Gaps", mode: .system))
        lines.append(contentsOf: metadataGapLines(items: keptItems, itemNumbers: itemNumbers))

        for group in groups {
            lines.append("")
            lines.append("## \(group.title)")
            if let subtitle = normalizedValue(group.subtitle) {
                lines.append("")
                lines.append("> " + subtitle)
            }
            lines.append("")
            lines.append("- " + wordZText("条目数", "Items", mode: .system) + ": \(group.items.count)")

            for item in group.items {
                lines.append("")
                lines.append("### \(evidenceLabel(for: item, itemNumbers: itemNumbers)). \(item.keyword)")
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
                lines.append("- " + wordZText("引文格式", "Citation Format", mode: .system) + ": " + item.citationFormat.title(in: .system))
                lines.append("- " + wordZText("引用样式", "Citation Style", mode: .system) + ": " + item.citationStyle.title(in: .system))
                lines.append("")
                lines.append("#### " + wordZText("索引行", "Concordance", mode: .system))
                lines.append(item.concordanceText)
                lines.append("")
                lines.append("#### " + wordZText("完整句", "Full Sentence", mode: .system))
                lines.append(item.fullSentenceText)
                lines.append("")
                lines.append("#### " + wordZText("引文", "Citation", mode: .system))
                lines.append(item.styledCitationText)
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

        lines.append("")
        lines.append("## " + wordZText("参考来源", "References", mode: .system))
        lines.append(contentsOf: referenceLines(items: keptItems, itemNumbers: itemNumbers))

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

    private static func evidenceNumberLookup(groups: [EvidenceWorkbenchGroup]) -> [String: Int] {
        var lookup: [String: Int] = [:]
        var nextNumber = 1
        for group in groups {
            for item in group.items where lookup[item.id] == nil {
                lookup[item.id] = nextNumber
                nextNumber += 1
            }
        }
        return lookup
    }

    private static func evidenceLabel(
        for item: EvidenceItem,
        itemNumbers: [String: Int]
    ) -> String {
        "E\(itemNumbers[item.id] ?? 0)"
    }

    private static func methodSummaryLines(
        items: [EvidenceItem],
        groups: [EvidenceWorkbenchGroup]
    ) -> [String] {
        [
            "- " + wordZText("审校范围", "Review Scope", mode: .system) + ": " + wordZText("仅保留证据", "Kept evidence only", mode: .system),
            "- " + wordZText("证据分组", "Evidence Groups", mode: .system) + ": \(groups.count)",
            "- " + wordZText("来源分布", "Source Mix", mode: .system) + ": " + sourceMixSummary(items),
            "- " + wordZText("引文格式分布", "Citation Formats", mode: .system) + ": " + citationFormatSummary(items),
            "- " + wordZText("引用样式分布", "Citation Styles", mode: .system) + ": " + citationStyleSummary(items)
        ]
    }

    private static func evidenceIndexLines(
        groups: [EvidenceWorkbenchGroup],
        itemNumbers: [String: Int]
    ) -> [String] {
        var lines = [
            "| " + [
                wordZText("编号", "ID", mode: .system),
                wordZText("关键词", "Keyword", mode: .system),
                wordZText("语料", "Corpus", mode: .system),
                wordZText("分组", "Group", mode: .system),
                wordZText("论点", "Claim", mode: .system),
                wordZText("引用样式", "Citation Style", mode: .system)
            ].joined(separator: " | ") + " |",
            "| --- | --- | --- | --- | --- | --- |"
        ]

        for group in groups {
            for item in group.items {
                lines.append("| " + [
                    evidenceLabel(for: item, itemNumbers: itemNumbers),
                    markdownTableCell(item.keyword),
                    markdownTableCell(item.corpusName),
                    markdownTableCell(group.title),
                    markdownTableCell(normalizedValue(item.claim) ?? wordZText("未归类", "Unclaimed", mode: .system)),
                    markdownTableCell(item.citationStyle.title(in: .system))
                ].joined(separator: " | ") + " |")
            }
        }
        return lines
    }

    private static func metadataGapLines(
        items: [EvidenceItem],
        itemNumbers: [String: Int]
    ) -> [String] {
        let entries = uniqueReferenceEntries(items: items, itemNumbers: itemNumbers)
        let gapLines = entries.compactMap { entry -> String? in
            let gaps = missingMetadataLabels(entry.metadata)
            guard !gaps.isEmpty else { return nil }
            return "- " + entry.corpusName + " (" + entry.evidenceLabels.joined(separator: ", ") + "): " + gaps.joined(separator: ", ")
        }
        if gapLines.isEmpty {
            return ["- " + wordZText("未发现关键元数据缺口。", "No key metadata gaps detected.", mode: .system)]
        }
        return gapLines
    }

    private static func referenceLines(
        items: [EvidenceItem],
        itemNumbers: [String: Int]
    ) -> [String] {
        uniqueReferenceEntries(items: items, itemNumbers: itemNumbers)
            .map { entry in
                "- " + referenceText(entry) + " " + wordZText("证据", "Evidence", mode: .system) + ": " + entry.evidenceLabels.joined(separator: ", ") + "."
            }
    }

    private struct ReferenceEntry {
        let key: String
        let corpusName: String
        let metadata: CorpusMetadataProfile?
        var evidenceLabels: [String]
    }

    private static func uniqueReferenceEntries(
        items: [EvidenceItem],
        itemNumbers: [String: Int]
    ) -> [ReferenceEntry] {
        var entries: [ReferenceEntry] = []
        var indexByKey: [String: Int] = [:]
        for item in items {
            let key = referenceKey(item)
            let label = evidenceLabel(for: item, itemNumbers: itemNumbers)
            if let index = indexByKey[key] {
                entries[index].evidenceLabels.append(label)
            } else {
                indexByKey[key] = entries.count
                entries.append(
                    ReferenceEntry(
                        key: key,
                        corpusName: item.corpusName,
                        metadata: item.corpusMetadata,
                        evidenceLabels: [label]
                    )
                )
            }
        }
        return entries
    }

    private static func referenceKey(_ item: EvidenceItem) -> String {
        [
            item.corpusID,
            item.corpusName,
            item.corpusMetadata?.sourceLabel ?? "",
            item.corpusMetadata?.yearLabel ?? "",
            item.corpusMetadata?.genreLabel ?? "",
            item.corpusMetadata?.tags.joined(separator: ",") ?? ""
        ].joined(separator: "|")
    }

    private static func referenceText(_ entry: ReferenceEntry) -> String {
        var parts = [entry.corpusName]
        if let sourceLabel = normalizedValue(entry.metadata?.sourceLabel) {
            parts.append(sourceLabel)
        }
        if let yearLabel = normalizedValue(entry.metadata?.yearLabel) {
            parts.append(yearLabel)
        }
        if let genreLabel = normalizedValue(entry.metadata?.genreLabel) {
            parts.append(wordZText("体裁", "Genre", mode: .system) + ": " + genreLabel)
        }
        if let tags = entry.metadata?.tags, !tags.isEmpty {
            parts.append(wordZText("标签", "Tags", mode: .system) + ": " + tags.joined(separator: ", "))
        }
        parts.append("WordZ")
        return parts.joined(separator: ". ") + "."
    }

    private static func missingMetadataLabels(_ metadata: CorpusMetadataProfile?) -> [String] {
        var labels: [String] = []
        if normalizedValue(metadata?.sourceLabel) == nil {
            labels.append(wordZText("来源标签", "Source Label", mode: .system))
        }
        if normalizedValue(metadata?.yearLabel) == nil {
            labels.append(wordZText("年份", "Year", mode: .system))
        }
        if normalizedValue(metadata?.genreLabel) == nil {
            labels.append(wordZText("体裁", "Genre", mode: .system))
        }
        return labels
    }

    private static func sourceMixSummary(_ items: [EvidenceItem]) -> String {
        EvidenceSourceKind.allCases
            .compactMap { kind -> String? in
                let count = items.filter { $0.sourceKind == kind }.count
                guard count > 0 else { return nil }
                return "\(kind.title(in: .system)) \(count)"
            }
            .joined(separator: " · ")
    }

    private static func citationFormatSummary(_ items: [EvidenceItem]) -> String {
        EvidenceCitationFormat.allCases
            .compactMap { format -> String? in
                let count = items.filter { $0.citationFormat == format }.count
                guard count > 0 else { return nil }
                return "\(format.title(in: .system)) \(count)"
            }
            .joined(separator: " · ")
    }

    private static func citationStyleSummary(_ items: [EvidenceItem]) -> String {
        EvidenceCitationStyle.allCases
            .compactMap { style -> String? in
                let count = items.filter { $0.citationStyle == style }.count
                guard count > 0 else { return nil }
                return "\(style.title(in: .system)) \(count)"
            }
            .joined(separator: " · ")
    }

    private static func markdownTableCell(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\n", with: " ")
        return normalized.replacingOccurrences(of: "|", with: "\\|")
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
