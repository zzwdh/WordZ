import Foundation

struct CompareSentimentDrilldownContext: Equatable, Sendable {
    let focusTerm: String
    let targetCorpora: [LibraryCorpusItem]
    let referenceCorpora: [LibraryCorpusItem]

    var hasReferenceScope: Bool {
        !referenceCorpora.isEmpty
    }

    func scopeSummary(in mode: AppLanguageMode) -> String {
        let targetSummary = joinedCorpusNames(
            targetCorpora,
            emptyLabel: wordZText("未选择目标语料", "No target corpora selected", mode: mode)
        )
        let referenceSummary = joinedCorpusNames(
            referenceCorpora,
            emptyLabel: wordZText("未固定参考语料", "No fixed reference scope", mode: mode)
        )
        return [
            "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(targetSummary)",
            "\(wordZText("参考语料", "Reference Corpora", mode: mode)): \(referenceSummary)"
        ]
        .joined(separator: " · ")
    }

    func summaryLine(in mode: AppLanguageMode) -> String {
        [
            wordZText("Compare x Sentiment 交叉分析", "Compare x Sentiment cross-analysis", mode: mode),
            scopeSummary(in: mode),
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)"
        ]
        .joined(separator: " · ")
    }

    private func joinedCorpusNames(
        _ corpora: [LibraryCorpusItem],
        emptyLabel: String
    ) -> String {
        let names = corpora
            .map(\.name)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !names.isEmpty else { return emptyLabel }
        return names.joined(separator: " · ")
    }
}

struct CompareSentimentSummary: Equatable, Sendable {
    let focusTerm: String
    let headline: String
    let scopeSummary: String
    let targetDistribution: String
    let referenceDistribution: String?
    let note: String

    static func build(
        context: CompareSentimentDrilldownContext,
        result: SentimentPresentationResult,
        languageMode: AppLanguageMode
    ) -> CompareSentimentSummary? {
        guard result.rawResult.request.source == .corpusCompare else { return nil }

        let targetSummary = result.effectiveGroupSummaries.first(where: { $0.id == "target" }) ??
            SentimentAggregateSummary(
                id: "target",
                title: wordZText("目标语料", "Target", mode: languageMode),
                totalTexts: result.effectiveOverallSummary.totalTexts,
                positiveCount: result.effectiveOverallSummary.positiveCount,
                neutralCount: result.effectiveOverallSummary.neutralCount,
                negativeCount: result.effectiveOverallSummary.negativeCount,
                positiveRatio: result.effectiveOverallSummary.positiveRatio,
                neutralRatio: result.effectiveOverallSummary.neutralRatio,
                negativeRatio: result.effectiveOverallSummary.negativeRatio,
                averagePositivity: result.effectiveOverallSummary.averagePositivity,
                averageNeutrality: result.effectiveOverallSummary.averageNeutrality,
                averageNegativity: result.effectiveOverallSummary.averageNegativity,
                averageNetScore: result.effectiveOverallSummary.averageNetScore
            )

        let referenceSummary = result.effectiveGroupSummaries.first(where: { $0.id == "reference" })
        let note: String
        if let referenceSummary {
            let delta = targetSummary.averageNetScore - referenceSummary.averageNetScore
            if abs(delta) < 0.05 {
                note = wordZText(
                    "目标侧与参考侧的整体情感倾向接近。",
                    "Target and reference show a similar overall sentiment profile.",
                    mode: languageMode
                )
            } else if delta > 0 {
                note = wordZText(
                    "目标侧整体上更偏积极，参考侧相对更弱或更负面。",
                    "The target side trends more positive overall than the reference side.",
                    mode: languageMode
                )
            } else {
                note = wordZText(
                    "目标侧整体上更偏负面，参考侧相对更积极。",
                    "The target side trends more negative overall than the reference side.",
                    mode: languageMode
                )
            }
        } else {
            note = wordZText(
                "当前没有固定参考侧情感汇总，因此这里只显示目标侧分布。",
                "No fixed reference-side sentiment summary is available, so only the target distribution is shown.",
                mode: languageMode
            )
        }

        return CompareSentimentSummary(
            focusTerm: context.focusTerm,
            headline: [
                wordZText("Compare x Sentiment", "Compare x Sentiment", mode: languageMode),
                "\(wordZText("聚焦词项", "Focus Term", mode: languageMode)): \(context.focusTerm)"
            ]
            .joined(separator: " · "),
            scopeSummary: context.scopeSummary(in: languageMode),
            targetDistribution: distributionLine(for: targetSummary, languageMode: languageMode),
            referenceDistribution: referenceSummary.map {
                distributionLine(for: $0, languageMode: languageMode)
            },
            note: note
        )
    }

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        var lines = [
            "\(wordZText("跨分析", "Cross Analysis", mode: mode)): \(wordZText("Compare x Sentiment", "Compare x Sentiment", mode: mode))",
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)",
            scopeSummary,
            targetDistribution
        ]
        if let referenceDistribution {
            lines.append(referenceDistribution)
        }
        lines.append("\(wordZText("解释", "Interpretation", mode: mode)): \(note)")
        return lines
    }

    private static func distributionLine(
        for summary: SentimentAggregateSummary,
        languageMode: AppLanguageMode
    ) -> String {
        "\(summary.title): +\(summary.positiveCount) / =\(summary.neutralCount) / -\(summary.negativeCount) · \(wordZText("平均净分", "Avg Net", mode: languageMode)) \(String(format: "%.3f", summary.averageNetScore))"
    }
}
