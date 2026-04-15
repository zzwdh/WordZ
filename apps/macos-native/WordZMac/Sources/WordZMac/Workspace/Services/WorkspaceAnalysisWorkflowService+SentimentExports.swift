import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func exportSentimentSummary(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let result = features.sentiment.result else { return }
        let lines = sentimentSummaryLines(result: result, languageMode: .system)
        let document = PlainTextExportDocument(
            suggestedName: "sentiment-summary.txt",
            text: lines.joined(separator: "\n")
        )
        await exportTextDocument(
            document,
            title: wordZText("导出情感摘要", "Export Sentiment Summary", mode: .system),
            successStatus: wordZText("情感摘要已导出到", "Sentiment summary exported to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func exportSentimentStructuredJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let result = features.sentiment.result else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result),
              let text = String(data: data, encoding: .utf8) else {
            features.sidebar.setError(wordZText("无法生成情感 JSON 导出内容。", "Unable to generate the sentiment JSON export.", mode: .system))
            return
        }
        let document = PlainTextExportDocument(
            suggestedName: "sentiment-structured.json",
            text: text,
            allowedExtension: "json"
        )
        await exportTextDocument(
            document,
            title: wordZText("导出情感 JSON", "Export Sentiment JSON", mode: .system),
            successStatus: wordZText("情感 JSON 已导出到", "Sentiment JSON exported to", mode: .system),
            features: features,
            preferredRoute: preferredRoute
        )
    }

    private func sentimentSummaryLines(
        result: SentimentRunResult,
        languageMode: AppLanguageMode
    ) -> [String] {
        var lines = [
            wordZText("WordZ Sentiment Analysis 摘要", "WordZ Sentiment Analysis Summary", mode: languageMode),
            "",
            "\(wordZText("来源", "Source", mode: languageMode)): \(result.request.source.title(in: languageMode))",
            "\(wordZText("单位", "Unit", mode: languageMode)): \(result.request.unit.title(in: languageMode))",
            "\(wordZText("上下文", "Context", mode: languageMode)): \(result.request.contextBasis.title(in: languageMode))",
            "\(wordZText("后端", "Backend", mode: languageMode)): \(result.backendKind.title(in: languageMode))",
            "\(wordZText("后端版本", "Backend Revision", mode: languageMode)): \(result.backendRevision)",
            "\(wordZText("资源版本", "Resource Revision", mode: languageMode)): \(result.resourceRevision)",
            "\(wordZText("聚合方式", "Aggregation", mode: languageMode)): \(aggregationSummary(for: result.request.unit, languageMode: languageMode))",
            "",
            "\(wordZText("总条数", "Total Texts", mode: languageMode)): \(result.overallSummary.totalTexts)",
            "\(wordZText("积极", "Positive", mode: languageMode)): \(result.overallSummary.positiveCount) (\(formatPercent(result.overallSummary.positiveRatio)))",
            "\(wordZText("中性", "Neutral", mode: languageMode)): \(result.overallSummary.neutralCount) (\(formatPercent(result.overallSummary.neutralRatio)))",
            "\(wordZText("消极", "Negative", mode: languageMode)): \(result.overallSummary.negativeCount) (\(formatPercent(result.overallSummary.negativeRatio)))"
        ]

        if !result.lexiconVersion.isEmpty {
            lines.insert("Lexicon: \(result.lexiconVersion)", at: 6)
        }

        if !result.groupSummaries.isEmpty {
            lines.append("")
            lines.append(wordZText("分组统计", "Grouped Summaries", mode: languageMode))
            for group in result.groupSummaries {
                lines.append("\(group.title): +\(group.positiveCount) / =\(group.neutralCount) / -\(group.negativeCount)")
            }
        }

        lines.append("")
        lines.append(wordZText("示例", "Examples", mode: languageMode))
        for label in SentimentLabel.allCases {
            if let row = result.rows.first(where: { $0.finalLabel == label }) {
                lines.append("[\(label.title(in: languageMode))] \(row.text)")
            }
        }
        return lines
    }

    private func formatPercent(_ ratio: Double) -> String {
        String(format: "%.1f%%", ratio * 100)
    }

    private func aggregationSummary(
        for unit: SentimentAnalysisUnit,
        languageMode: AppLanguageMode
    ) -> String {
        switch unit {
        case .document:
            return wordZText("句级聚合", "Sentence-level aggregation", mode: languageMode)
        case .sentence, .concordanceLine:
            return wordZText("直接判别", "Direct classification", mode: languageMode)
        }
    }
}
