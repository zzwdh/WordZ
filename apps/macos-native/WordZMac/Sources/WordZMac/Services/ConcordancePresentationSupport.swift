import Foundation

enum ConcordancePresentationSupport {
    static func normalizedContext(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func annotatedLine(left: String, keyword: String, right: String) -> String {
        let normalizedLeft = normalizedContext(left)
        let normalizedKeyword = normalizedContext(keyword)
        let normalizedRight = normalizedContext(right)
        var components: [String] = []
        if !normalizedLeft.isEmpty {
            components.append(normalizedLeft)
        }
        if !normalizedKeyword.isEmpty {
            components.append("[\(normalizedKeyword)]")
        }
        if !normalizedRight.isEmpty {
            components.append(normalizedRight)
        }
        return components.joined(separator: " ")
    }

    static func citationText(
        sentenceNumber: Int,
        keyword: String,
        left: String,
        right: String,
        fullText: String? = nil
    ) -> String {
        let concordance = annotatedLine(left: left, keyword: keyword, right: right)
        let normalizedFullText = fullText.map(normalizedContext) ?? ""
        var lines = ["Sentence \(sentenceNumber)", concordance]
        if !normalizedFullText.isEmpty, normalizedFullText != concordance {
            lines.append("Full: \(normalizedFullText)")
        }
        return lines.joined(separator: "\n")
    }
}
