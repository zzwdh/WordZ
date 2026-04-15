import Foundation

enum ReadingExportSupport {
    static func document(
        for format: ReadingExportFormat,
        currentKWICRow row: KWICSceneRow,
        scene: KWICSceneModel
    ) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "kwic-\(format.rawValue).txt",
            metadataLines: scene.exportMetadataLines,
            body: render(kwicRows: [row], format: format)
        )
    }

    static func document(
        for format: ReadingExportFormat,
        visibleKWICRows rows: [KWICSceneRow],
        scene: KWICSceneModel
    ) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "kwic-visible-\(format.rawValue).txt",
            metadataLines: scene.exportMetadataLines,
            body: render(kwicRows: rows, format: format)
        )
    }

    static func document(
        for format: ReadingExportFormat,
        currentLocatorRow row: LocatorSceneRow,
        scene: LocatorSceneModel
    ) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "locator-\(format.rawValue).txt",
            metadataLines: locatorMetadataLines(scene),
            body: render(locatorRows: [row], format: format)
        )
    }

    static func document(
        for format: ReadingExportFormat,
        visibleLocatorRows rows: [LocatorSceneRow],
        scene: LocatorSceneModel
    ) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "locator-visible-\(format.rawValue).txt",
            metadataLines: locatorMetadataLines(scene),
            body: render(locatorRows: rows, format: format)
        )
    }

    static func document(currentCompareRow row: CompareSceneRow, scene: CompareSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "compare-summary.txt",
            metadataLines: scene.exportMetadataLines + [scene.referenceSummary, scene.methodSummary],
            body: render(compareRows: [row], scene: scene)
        )
    }

    static func document(visibleCompareRows rows: [CompareSceneRow], scene: CompareSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "compare-visible-summary.txt",
            metadataLines: scene.exportMetadataLines + [scene.referenceSummary, scene.methodSummary],
            body: render(compareRows: rows, scene: scene)
        )
    }

    static func document(currentCollocateRow row: CollocateSceneRow, scene: CollocateSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "collocate-summary.txt",
            metadataLines: scene.exportMetadataLines + [scene.methodSummary, scene.focusMetricSummary],
            body: render(collocateRows: [row], scene: scene)
        )
    }

    static func document(visibleCollocateRows rows: [CollocateSceneRow], scene: CollocateSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "collocate-visible-summary.txt",
            metadataLines: scene.exportMetadataLines + [scene.methodSummary, scene.focusMetricSummary],
            body: render(collocateRows: rows, scene: scene)
        )
    }

    static func compareMethodDocument(scene: CompareSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "compare-method-summary.txt",
            metadataLines: scene.exportMetadataLines,
            body: renderMethodSummary(
                summary: scene.methodSummary,
                notes: [scene.referenceSummary] + scene.methodNotes
            )
        )
    }

    static func collocateMethodDocument(scene: CollocateSceneModel) -> PlainTextExportDocument {
        makeDocument(
            suggestedName: "collocate-method-summary.txt",
            metadataLines: scene.exportMetadataLines,
            body: renderMethodSummary(
                summary: scene.methodSummary,
                notes: scene.methodNotes
            )
        )
    }

    static func keywordRowContextDocument(
        row: KeywordSuiteRow,
        scene: KeywordSceneModel
    ) -> PlainTextExportDocument {
        let slug = row.item
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        let lines = [
            row.item,
            "Direction: \(row.direction.title(in: .system))",
            "Keyness: \(String(format: "%.2f", row.keynessScore))",
            "Log Ratio: \(String(format: "%.2f", row.logRatio))",
            "p: \(row.pValue < 0.001 && row.pValue > 0 ? "<0.001" : String(format: "%.3f", row.pValue))",
            "Focus Frequency: \(row.focusFrequency)",
            "Reference Frequency: \(row.referenceFrequency)",
            "Focus Normalized Frequency: \(String(format: "%.1f", row.focusNormalizedFrequency))",
            "Reference Normalized Frequency: \(String(format: "%.1f", row.referenceNormalizedFrequency))",
            "Focus Range: \(row.focusRange)",
            "Reference Range: \(row.referenceRange)",
            scene.focusSummary.isEmpty ? "" : "Focus: \(scene.focusSummary)",
            scene.referenceSummary.isEmpty ? "" : "Reference: \(scene.referenceSummary)",
            row.example.isEmpty ? "" : "Example: \(row.example)"
        ]

        return makeDocument(
            suggestedName: "\(slug.isEmpty ? "keyword-row" : slug)-context.txt",
            metadataLines: scene.exportMetadataLines,
            body: lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        )
    }

    private static func render(kwicRows rows: [KWICSceneRow], format: ReadingExportFormat) -> String {
        rows.map { row in
            switch format {
            case .concordance:
                return row.concordanceText
            case .fullSentence:
                return [row.leftContext, row.keyword, row.rightContext]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
            case .citation:
                return row.citationText
            case .summary:
                return row.citationText
            }
        }
        .joined(separator: "\n\n")
    }

    private static func render(locatorRows rows: [LocatorSceneRow], format: ReadingExportFormat) -> String {
        rows.map { row in
            switch format {
            case .concordance:
                return row.concordanceText
            case .fullSentence:
                return row.text
            case .citation:
                return row.citationText
            case .summary:
                return row.citationText
            }
        }
        .joined(separator: "\n\n")
    }

    private static func render(compareRows rows: [CompareSceneRow], scene: CompareSceneModel) -> String {
        rows.map { row in
            """
            \(row.word)
            Keyness: \(row.keynessText)
            Log Ratio: \(row.effectText)
            p: \(row.pValueText)
            Spread: \(row.spreadText)
            Total: \(row.totalText)
            Range: \(row.rangeText)
            Reference: \(row.referenceLabelText)
            Dominant Corpus: \(row.dominantCorpus)
            Distribution: \(row.distributionText)
            """
        }
        .joined(separator: "\n\n")
    }

    private static func render(collocateRows rows: [CollocateSceneRow], scene: CollocateSceneModel) -> String {
        rows.map { row in
            """
            \(row.word)
            Focus Metric: \(scene.focusMetric.title(in: .system))
            LogDice: \(row.logDiceText)
            MI: \(row.mutualInformationText)
            T-Score: \(row.tScoreText)
            Rate: \(row.rateText)
            FreqLR: \(row.totalText)
            FreqL: \(row.leftText)
            FreqR: \(row.rightText)
            Collocate Frequency: \(row.wordFreqText)
            Keyword Frequency: \(row.keywordFreqText)
            """
        }
        .joined(separator: "\n\n")
    }

    private static func renderMethodSummary(
        summary: String,
        notes: [String]
    ) -> String {
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return ([trimmedSummary] + trimmedNotes.map { "- \($0)" })
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func locatorMetadataLines(_ scene: LocatorSceneModel) -> [String] {
        [
            "Sentence: \(scene.source.sentenceId + 1)",
            "Node: \(scene.source.keyword)",
            "Window: L\(scene.leftWindow) / R\(scene.rightWindow)"
        ]
    }

    private static func makeDocument(
        suggestedName: String,
        metadataLines: [String],
        body: String
    ) -> PlainTextExportDocument {
        let trimmedMetadata = metadataLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = ([trimmedMetadata.joined(separator: "\n"), trimmedBody]
            .filter { !$0.isEmpty })
            .joined(separator: "\n\n")
        return PlainTextExportDocument(suggestedName: suggestedName, text: text)
    }
}
