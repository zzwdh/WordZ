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
            "方向: \(row.direction.title(in: .system))",
            "显著性: \(String(format: "%.2f", row.keynessScore))",
            "差异强度: \(String(format: "%.2f", row.logRatio))",
            "p 值: \(row.pValue < 0.001 && row.pValue > 0 ? "<0.001" : String(format: "%.3f", row.pValue))",
            "目标频次: \(row.focusFrequency)",
            "参照频次: \(row.referenceFrequency)",
            "目标标准频次: \(String(format: "%.1f", row.focusNormalizedFrequency))",
            "参照标准频次: \(String(format: "%.1f", row.referenceNormalizedFrequency))",
            "目标覆盖: \(row.focusRange)",
            "参照覆盖: \(row.referenceRange)",
            scene.focusSummary.isEmpty ? "" : "目标语料: \(scene.focusSummary)",
            scene.referenceSummary.isEmpty ? "" : "参照语料: \(scene.referenceSummary)",
            row.example.isEmpty ? "" : "示例: \(row.example)"
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
            显著性: \(row.keynessText)
            差异强度: \(row.effectText)
            p 值: \(row.pValueText)
            覆盖: \(row.spreadText)
            总频次: \(row.totalText)
            差异: \(row.rangeText)
            参考语料: \(row.referenceLabelText)
            主导语料: \(row.dominantCorpus)
            分布: \(row.distributionText)
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
