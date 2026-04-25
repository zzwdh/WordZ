import Foundation

extension KeywordSuiteAnalyzer {
    static func parseImportedReference(_ text: String) -> KeywordImportedReferenceParseResult {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard !normalized.isEmpty else { return .empty }

        var lines = normalized.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        guard !lines.isEmpty else { return .empty }

        var merged: [String: Int] = [:]
        var acceptedLineCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "\t")
            let rawTerm = parts.first ?? trimmed
            let normalizedTerm = normalizeImportedItem(rawTerm)
            guard !normalizedTerm.isEmpty else { continue }

            let frequency: Int
            if parts.count >= 2 {
                guard let parsedFrequency = Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)),
                      parsedFrequency > 0 else {
                    continue
                }
                frequency = parsedFrequency
            } else {
                frequency = 1
            }

            merged[normalizedTerm, default: 0] += frequency
            acceptedLineCount += 1
        }

        let items = merged.keys.sorted().map {
            KeywordReferenceWordListItem(term: $0, frequency: merged[$0, default: 1])
        }
        let rejectedLineCount = max(0, lines.count - acceptedLineCount)
        return KeywordImportedReferenceParseResult(
            items: items,
            totalLineCount: lines.count,
            acceptedLineCount: acceptedLineCount,
            rejectedLineCount: rejectedLineCount
        )
    }

    static func parseImportedReferenceItems(_ text: String) -> [KeywordReferenceWordListItem] {
        parseImportedReference(text).items
    }

    static func normalizeImportedItem(_ value: String) -> String {
        let normalized = AnalysisTextNormalizationSupport.normalizeSearchText(value, caseSensitive: false)
        guard !normalized.isEmpty else { return "" }
        return normalized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func importedReferenceItemBelongsToGroup(
        _ item: KeywordReferenceWordListItem,
        group: KeywordResultGroup
    ) -> Bool {
        let tokenCount = importedReferenceTokenCount(item.term)
        switch group {
        case .words:
            return tokenCount == 1
        case .terms, .ngrams:
            return (2...5).contains(tokenCount)
        }
    }

    static func importedReferenceTokenCount(_ term: String) -> Int {
        max(1, term.split(separator: " ", omittingEmptySubsequences: true).count)
    }
}
