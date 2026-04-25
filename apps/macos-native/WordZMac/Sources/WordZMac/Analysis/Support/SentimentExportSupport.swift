import Foundation

enum SentimentExportSupport {
    static func summaryLines(
        result: SentimentRunResult,
        additionalLines: [String] = [],
        languageMode: AppLanguageMode
    ) -> [String] {
        summaryLines(
            presentationResult: SentimentReviewOverlaySupport.makePresentationResult(
                rawResult: result,
                reviewSamples: []
            ),
            additionalLines: additionalLines,
            languageMode: languageMode
        )
    }

    static func summaryLines(
        presentationResult: SentimentPresentationResult,
        additionalLines: [String] = [],
        languageMode: AppLanguageMode
    ) -> [String] {
        let rawResult = presentationResult.rawResult
        var lines = [
            wordZText("WordZ Sentiment Analysis 摘要", "WordZ Sentiment Analysis Summary", mode: languageMode),
            "",
            "\(wordZText("来源", "Source", mode: languageMode)): \(rawResult.request.source.title(in: languageMode))",
            "\(wordZText("单位", "Unit", mode: languageMode)): \(rawResult.request.unit.title(in: languageMode))",
            "\(wordZText("上下文", "Context", mode: languageMode)): \(rawResult.request.contextBasis.title(in: languageMode))",
            "\(wordZText("后端", "Backend", mode: languageMode)): \(rawResult.backendKind.title(in: languageMode))",
            "\(wordZText("后端版本", "Backend Revision", mode: languageMode)): \(rawResult.backendRevision)",
            "\(wordZText("资源版本", "Resource Revision", mode: languageMode)): \(rawResult.resourceRevision)",
            "\(wordZText("规则包", "Domain Pack", mode: languageMode)): \(rawResult.request.domainPackSummary(in: languageMode))",
            "\(wordZText("规则配置", "Rule Profile", mode: languageMode)): \(rawResult.request.ruleProfile.title)",
            "\(wordZText("校准版本", "Calibration Revision", mode: languageMode)): \(rawResult.calibrationProfileRevision)",
            "\(wordZText("聚合方式", "Aggregation", mode: languageMode)): \(aggregationSummary(for: rawResult.request.unit, languageMode: languageMode))",
            "",
            "\(wordZText("总条数", "Total Texts", mode: languageMode)): \(presentationResult.effectiveOverallSummary.totalTexts)",
            "\(wordZText("积极", "Positive", mode: languageMode)): \(presentationResult.effectiveOverallSummary.positiveCount) (\(formatPercent(presentationResult.effectiveOverallSummary.positiveRatio)))",
            "\(wordZText("中性", "Neutral", mode: languageMode)): \(presentationResult.effectiveOverallSummary.neutralCount) (\(formatPercent(presentationResult.effectiveOverallSummary.neutralRatio)))",
            "\(wordZText("消极", "Negative", mode: languageMode)): \(presentationResult.effectiveOverallSummary.negativeCount) (\(formatPercent(presentationResult.effectiveOverallSummary.negativeRatio)))",
            "\(wordZText("已审校样本", "Reviewed Samples", mode: languageMode)): \(presentationResult.reviewSummary.reviewedCount)",
            "\(wordZText("人工改标", "Overrides", mode: languageMode)): \(presentationResult.reviewSummary.overriddenCount)",
            "\(wordZText("确认原判", "Confirmed Raw", mode: languageMode)): \(presentationResult.reviewSummary.confirmedRawCount)"
        ]

        if !rawResult.lexiconVersion.isEmpty {
            lines.insert("Lexicon: \(rawResult.lexiconVersion)", at: 6)
        }
        if !rawResult.activePackIDs.isEmpty {
            lines.insert(
                "\(wordZText("激活规则包", "Active Packs", mode: languageMode)): \(rawResult.activePackIDs.map { $0.title(in: languageMode) }.joined(separator: ", "))",
                at: 7
            )
        }
        if !rawResult.userLexiconBundleIDs.isEmpty {
            lines.insert(
                "\(wordZText("用户词典", "User Lexicon Bundles", mode: languageMode)): \(rawResult.userLexiconBundleIDs.joined(separator: ", "))",
                at: 8
            )
        }
        if let providerID = rawResult.providerID,
           !providerID.isEmpty {
            lines.insert(
                "\(wordZText("模型 Provider", "Model Provider", mode: languageMode)): \(providerID)",
                at: min(lines.count, 8)
            )
        }
        if let providerFamily = rawResult.providerFamily {
            lines.insert(
                "\(wordZText("Provider 家族", "Provider Family", mode: languageMode)): \(providerFamily.title(in: languageMode))",
                at: min(lines.count, 9)
            )
        }

        let scopeLines = scopeSummaryLines(for: rawResult, languageMode: languageMode)
        if !scopeLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: scopeLines)
        }

        if !additionalLines.isEmpty {
            lines.append("")
            lines.append(contentsOf: additionalLines)
        }

        if !presentationResult.effectiveGroupSummaries.isEmpty {
            lines.append("")
            lines.append(wordZText("分组统计", "Grouped Summaries", mode: languageMode))
            for group in presentationResult.effectiveGroupSummaries {
                lines.append("\(group.title): +\(group.positiveCount) / =\(group.neutralCount) / -\(group.negativeCount)")
            }
        }

        lines.append("")
        lines.append(wordZText("示例", "Examples", mode: languageMode))
        for label in SentimentLabel.allCases {
            if let row = presentationResult.effectiveRows.first(where: { $0.effectiveLabel == label }) {
                lines.append("[\(label.title(in: languageMode))] \(row.rawRow.text)")
            }
        }
        return lines
    }

    static func aggregationSummary(
        for unit: SentimentAnalysisUnit,
        languageMode: AppLanguageMode
    ) -> String {
        switch unit {
        case .document:
            return wordZText("句级聚合", "Sentence-level aggregation", mode: languageMode)
        case .sentence, .concordanceLine, .sourceSentence:
            return wordZText("直接判别", "Direct classification", mode: languageMode)
        }
    }

    private static func formatPercent(_ ratio: Double) -> String {
        String(format: "%.1f%%", ratio * 100)
    }

    private static func scopeSummaryLines(
        for result: SentimentRunResult,
        languageMode: AppLanguageMode
    ) -> [String] {
        switch result.request.source {
        case .corpusCompare:
            let groupedSources = Dictionary(grouping: result.request.texts) { input in
                input.groupTitle ?? input.groupID ?? wordZText("未分组", "Ungrouped", mode: languageMode)
            }
            let orderedGroupTitles = result.request.texts.compactMap {
                $0.groupTitle ?? $0.groupID
            }.uniquedPreservingOrder()
            return orderedGroupTitles.compactMap { groupTitle in
                let sourceTitles = groupedSources[groupTitle]?
                    .map(\.sourceTitle)
                    .uniquedPreservingOrder()
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
                guard !sourceTitles.isEmpty else { return nil }
                return "\(groupTitle): \(sourceTitles.joined(separator: ", "))"
            }
        default:
            return []
        }
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen: Set<String> = []
        return filter { value in
            seen.insert(value).inserted
        }
    }
}
