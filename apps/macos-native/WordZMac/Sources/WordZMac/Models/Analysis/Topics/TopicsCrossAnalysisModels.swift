import Foundation

struct TopicsCompareDrilldownContext: Equatable, Sendable {
    let focusTerm: String
    let targetCorpora: [LibraryCorpusItem]
    let referenceCorpora: [LibraryCorpusItem]

    var targetCorpusIDs: [String] {
        targetCorpora.map(\.id)
    }

    var referenceCorpusIDs: [String] {
        referenceCorpora.map(\.id)
    }

    var hasReferenceScope: Bool {
        !referenceCorpora.isEmpty
    }

    func scopeSummary(in mode: AppLanguageMode) -> String {
        [
            "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(joinedCorpusNames(targetCorpora, emptyLabel: wordZText("未选择目标语料", "No target corpora selected", mode: mode)))",
            "\(wordZText("参考语料", "Reference Corpora", mode: mode)): \(joinedCorpusNames(referenceCorpora, emptyLabel: wordZText("未选择参考语料", "No reference corpora selected", mode: mode)))"
        ]
        .joined(separator: " · ")
    }

    func summaryLine(in mode: AppLanguageMode) -> String {
        [
            wordZText("Compare x Topics 交叉分析", "Compare x Topics cross-analysis", mode: mode),
            scopeSummary(in: mode),
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)"
        ]
        .joined(separator: " · ")
    }

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        [
            "\(wordZText("跨分析", "Cross Analysis", mode: mode)): \(wordZText("Compare x Topics", "Compare x Topics", mode: mode))",
            "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(joinedCorpusNames(targetCorpora, emptyLabel: "—"))",
            "\(wordZText("参考语料", "Reference Corpora", mode: mode)): \(joinedCorpusNames(referenceCorpora, emptyLabel: "—"))",
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)"
        ]
    }

    private func joinedCorpusNames(
        _ corpora: [LibraryCorpusItem],
        emptyLabel: String
    ) -> String {
        let names = corpora.map(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !names.isEmpty else { return emptyLabel }
        return names.joined(separator: " · ")
    }
}

struct CompareTopicsClusterSummary: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let keywordsText: String
    let targetSegmentCount: Int
    let referenceSegmentCount: Int

    var totalSegmentCount: Int {
        targetSegmentCount + referenceSegmentCount
    }

    var hasBothSides: Bool {
        targetSegmentCount > 0 && referenceSegmentCount > 0
    }

    func balanceText(in mode: AppLanguageMode) -> String {
        let balance: String
        if hasBothSides {
            balance = wordZText("共享主题", "Shared Topic", mode: mode)
        } else if targetSegmentCount > referenceSegmentCount {
            balance = wordZText("目标侧更强", "Target leaning", mode: mode)
        } else if referenceSegmentCount > targetSegmentCount {
            balance = wordZText("参考侧更强", "Reference leaning", mode: mode)
        } else {
            balance = wordZText("暂无侧向", "No side signal", mode: mode)
        }
        return "\(balance) · T \(targetSegmentCount) / R \(referenceSegmentCount)"
    }
}

struct CompareTopicsSummary: Equatable, Sendable {
    let focusTerm: String
    let headline: String
    let scopeSummary: String
    let targetSegmentCount: Int
    let referenceSegmentCount: Int
    let sharedTopicCount: Int
    let targetLeaningTopicCount: Int
    let referenceLeaningTopicCount: Int
    let note: String
    let topTopics: [CompareTopicsClusterSummary]

    static func build(
        context: TopicsCompareDrilldownContext,
        result: TopicAnalysisResult,
        languageMode: AppLanguageMode
    ) -> CompareTopicsSummary? {
        guard !result.segments.isEmpty else { return nil }

        let targetSegments = result.segments.filter { $0.groupID == "target" }
        let referenceSegments = result.segments.filter { $0.groupID == "reference" }
        let segmentsByTopic = Dictionary(grouping: result.segments, by: \.topicID)
        let topicSummaries = result.clusters
            .filter { !$0.isOutlier }
            .compactMap { cluster -> CompareTopicsClusterSummary? in
                let topicSegments = segmentsByTopic[cluster.id] ?? []
                let targetCount = topicSegments.filter { $0.groupID == "target" }.count
                let referenceCount = topicSegments.filter { $0.groupID == "reference" }.count
                guard targetCount + referenceCount > 0 else { return nil }
                let keywords = cluster.keywordTerms.prefix(4).joined(separator: " · ")
                return CompareTopicsClusterSummary(
                    id: cluster.id,
                    title: "\(wordZText("主题", "Topic", mode: languageMode)) \(cluster.index)",
                    keywordsText: keywords.isEmpty ? wordZText("暂无关键词", "No keywords yet", mode: languageMode) : keywords,
                    targetSegmentCount: targetCount,
                    referenceSegmentCount: referenceCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalSegmentCount == rhs.totalSegmentCount {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.totalSegmentCount > rhs.totalSegmentCount
            }

        guard !topicSummaries.isEmpty else { return nil }

        let sharedCount = topicSummaries.filter(\.hasBothSides).count
        let targetLeaningCount = topicSummaries.filter { $0.targetSegmentCount > $0.referenceSegmentCount }.count
        let referenceLeaningCount = topicSummaries.filter { $0.referenceSegmentCount > $0.targetSegmentCount }.count
        let note: String
        if sharedCount > 0 {
            note = wordZText(
                "至少一个主题同时覆盖目标侧与参考侧，适合继续比较两侧如何围绕同一词项形成不同语义环境。",
                "At least one topic spans both target and reference sides, making it useful for comparing how each side frames the same focus term.",
                mode: languageMode
            )
        } else if targetLeaningCount > referenceLeaningCount {
            note = wordZText(
                "主题结果更集中在目标侧，建议优先阅读目标侧代表片段并检查参考侧是否缺少对应语境。",
                "The topic result leans toward the target side; inspect target exemplars first and check whether the reference side lacks a matching context.",
                mode: languageMode
            )
        } else {
            note = wordZText(
                "主题结果更集中在参考侧，建议把参考侧主题作为解释 keyness 差异的背景线索。",
                "The topic result leans toward the reference side; use reference-side topics as context for interpreting the keyness contrast.",
                mode: languageMode
            )
        }

        return CompareTopicsSummary(
            focusTerm: context.focusTerm,
            headline: [
                wordZText("Compare x Topics", "Compare x Topics", mode: languageMode),
                "\(wordZText("聚焦词项", "Focus Term", mode: languageMode)): \(context.focusTerm)"
            ].joined(separator: " · "),
            scopeSummary: context.scopeSummary(in: languageMode),
            targetSegmentCount: targetSegments.count,
            referenceSegmentCount: referenceSegments.count,
            sharedTopicCount: sharedCount,
            targetLeaningTopicCount: targetLeaningCount,
            referenceLeaningTopicCount: referenceLeaningCount,
            note: note,
            topTopics: Array(topicSummaries.prefix(5))
        )
    }

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        var lines = [
            "\(wordZText("跨分析", "Cross Analysis", mode: mode)): \(wordZText("Compare x Topics", "Compare x Topics", mode: mode))",
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)",
            scopeSummary,
            "\(wordZText("片段分布", "Segment Distribution", mode: mode)): T \(targetSegmentCount) / R \(referenceSegmentCount)",
            "\(wordZText("主题侧向", "Topic Balance", mode: mode)): shared \(sharedTopicCount) · target \(targetLeaningTopicCount) · reference \(referenceLeaningTopicCount)",
            "\(wordZText("解释", "Interpretation", mode: mode)): \(note)"
        ]
        for topic in topTopics.prefix(5) {
            lines.append("\(topic.title): \(topic.balanceText(in: mode)) · \(topic.keywordsText)")
        }
        return lines
    }
}
