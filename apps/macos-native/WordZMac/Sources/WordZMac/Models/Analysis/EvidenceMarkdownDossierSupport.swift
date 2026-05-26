import Foundation

enum EvidenceMarkdownDossierSupport {
    enum DossierError: LocalizedError {
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有已标记为保留的摘录。", "There are no kept excerpts to save.", mode: .system)
            }
        }
    }

    static func document(
        items: [EvidenceItem],
        exportedAt: Date = Date(),
        filterSummary: String? = nil
    ) throws -> PlainTextExportDocument {
        let keptItems = items.filter { $0.reviewStatus == .keep }
        guard !keptItems.isEmpty else {
            throw DossierError.emptySelection
        }

        var lines: [String] = [
            wordZText("摘录文本", "Excerpt Text", mode: .system),
            "",
            wordZText("保存时间", "Saved At", mode: .system) + ": " + ISO8601DateFormatter().string(from: exportedAt),
            wordZText("保留摘录", "Kept Excerpts", mode: .system) + ": \(keptItems.count)"
        ]
        if let filterSummary = normalizedValue(filterSummary) {
            lines.append(wordZText("保存范围", "Save Scope", mode: .system) + ": " + filterSummary)
        }

        for (index, item) in keptItems.enumerated() {
            lines.append("")
            lines.append("[\(index + 1)] " + excerptTitle(for: item))
            lines.append(sourceLine(for: item))
            if let savedSetName = normalizedValue(item.savedSetName) {
                lines.append(wordZText("命中集", "Hit Set", mode: .system) + ": " + savedSetName)
            }

            lines.append("")
            lines.append(wordZText("索引行", "Concordance", mode: .system) + ":")
            lines.append(item.concordanceText)
            lines.append("")
            lines.append(wordZText("完整句", "Full Sentence", mode: .system) + ":")
            lines.append(item.fullSentenceText)
            lines.append("")
            lines.append(wordZText("引文", "Citation", mode: .system) + ":")
            lines.append(item.styledCitationText)

            if let note = normalizedValue(item.note) {
                lines.append("")
                lines.append(wordZText("备注", "Note", mode: .system) + ":")
                lines.append(note)
            }
        }

        return PlainTextExportDocument(
            suggestedName: "wordz-excerpts.txt",
            text: lines.joined(separator: "\n"),
            allowedExtension: "txt"
        )
    }

    private static func excerptTitle(for item: EvidenceItem) -> String {
        normalizedValue(item.keyword) ?? wordZText("未命名摘录", "Untitled Excerpt", mode: .system)
    }

    private static func sourceLine(for item: EvidenceItem) -> String {
        [
            wordZText("来源", "Source", mode: .system) + ": " + item.sourceKind.title(in: .system),
            wordZText("语料", "Corpus", mode: .system) + ": " + item.corpusName,
            wordZText("句号", "Sentence", mode: .system) + ": \(item.sentenceId + 1)"
        ].joined(separator: " · ")
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
