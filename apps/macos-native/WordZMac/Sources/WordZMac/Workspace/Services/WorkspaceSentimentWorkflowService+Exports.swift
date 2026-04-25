import Foundation

@MainActor
extension WorkspaceSentimentWorkflowService {
    func exportSentimentSummary(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard let presentationResult = features.sentiment.presentationResult else { return }
        let lines = SentimentExportSupport.summaryLines(
            presentationResult: presentationResult,
            additionalLines: features.sentiment.exportMetadataLines(
                annotationSummary: features.shell.scene.annotationSummary,
                languageMode: .system
            ),
            languageMode: .system
        )
        let document = PlainTextExportDocument(
            suggestedName: "sentiment-summary.txt",
            text: lines.joined(separator: "\n")
        )
        await analysisWorkflow.exportTextDocument(
            document,
            title: wordZText("导出情感摘要", "Export Sentiment Summary", mode: .system),
            successStatus: wordZText("情感摘要已导出到", "Sentiment summary exported to", mode: .system),
            features: featureSet,
            preferredRoute: preferredRoute
        )
    }

    func exportSentimentStructuredJSON(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        let featureSet = features.withFeatureSet { $0 }
        guard let presentationResult = features.sentiment.presentationResult else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presentationResult),
              let text = String(data: data, encoding: .utf8) else {
            features.sidebar.setError(wordZText("无法生成情感 JSON 导出内容。", "Unable to generate the sentiment JSON export.", mode: .system))
            return
        }
        let document = PlainTextExportDocument(
            suggestedName: "sentiment-structured.json",
            text: text,
            allowedExtension: "json"
        )
        await analysisWorkflow.exportTextDocument(
            document,
            title: wordZText("导出情感 JSON", "Export Sentiment JSON", mode: .system),
            successStatus: wordZText("情感 JSON 已导出到", "Sentiment JSON exported to", mode: .system),
            features: featureSet,
            preferredRoute: preferredRoute
        )
    }
}
