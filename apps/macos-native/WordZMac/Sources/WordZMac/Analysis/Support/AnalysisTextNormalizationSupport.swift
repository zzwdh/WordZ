import Foundation

enum AnalysisTextNormalizationSupport {
    private static let searchableScalars = CharacterSet.alphanumerics
    private static let joinerScalars: Set<UnicodeScalar> = ["'", "-", "’"]

    static func normalizeToken(_ value: String) -> String {
        normalizeSearchText(value, caseSensitive: false)
    }

    static func normalizeSearchText(_ value: String, caseSensitive: Bool) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed.precomposedStringWithCompatibilityMapping
        guard !caseSensitive else { return normalized }

        return normalized.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }

    static func containsWordLikeContent(_ value: String) -> Bool {
        value.unicodeScalars.contains { searchableScalars.contains($0) }
    }

    static func tokenizeWordLikeSegments(in text: String, caseSensitive: Bool = false) -> [String] {
        let normalized = normalizeSearchText(text, caseSensitive: caseSensitive)
        guard !normalized.isEmpty else { return [] }

        var tokens: [String] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let cleaned = buffer.trimmingCharacters(in: CharacterSet(charactersIn: "'-’"))
            if !cleaned.isEmpty {
                tokens.append(cleaned)
            }
            buffer.removeAll(keepingCapacity: true)
        }

        for scalar in normalized.unicodeScalars {
            if searchableScalars.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if joinerScalars.contains(scalar), !buffer.isEmpty {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            flushBuffer()
        }

        flushBuffer()
        return tokens
    }
}
