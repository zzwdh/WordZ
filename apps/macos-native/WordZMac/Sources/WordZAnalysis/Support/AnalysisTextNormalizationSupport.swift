import Foundation
import NaturalLanguage

package enum AnalysisTextNormalizationSupport {
    private static let searchableScalars = CharacterSet.alphanumerics
    private static let joinerScalars: Set<UnicodeScalar> = ["'", "-", "’"]

    package static func normalizeToken(_ value: String) -> String {
        normalizeSearchText(value, caseSensitive: false)
    }

    package static func normalizeSearchText(_ value: String, caseSensitive: Bool) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let normalized = trimmed.precomposedStringWithCompatibilityMapping
        guard !caseSensitive else { return normalized }

        return normalized.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
    }

    package static func containsWordLikeContent(_ value: String) -> Bool {
        value.unicodeScalars.contains { searchableScalars.contains($0) }
    }

    package static func tokenizeWordLikeSegments(in text: String, caseSensitive: Bool = false) -> [String] {
        let normalized = normalizeSearchText(text, caseSensitive: caseSensitive)
        guard !normalized.isEmpty else { return [] }
        if containsCJKContent(normalized) {
            return tokenizeNaturalLanguageSegments(in: normalized, caseSensitive: caseSensitive)
        }

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

    private static func tokenizeNaturalLanguageSegments(in text: String, caseSensitive: Bool) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let value = normalizeSearchText(String(text[range]), caseSensitive: caseSensitive)
            if containsWordLikeContent(value) {
                tokens.append(value)
            }
            return true
        }
        return tokens
    }

    private static func containsCJKContent(_ value: String) -> Bool {
        value.unicodeScalars.contains(where: isCJK)
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF,
             0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
