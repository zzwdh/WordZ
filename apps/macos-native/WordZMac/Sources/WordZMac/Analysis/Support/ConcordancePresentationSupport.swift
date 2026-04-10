import Foundation

enum ConcordancePresentationSupport {
    static func normalizedContext(_ text: String) -> String {
        guard !text.isEmpty else { return "" }

        var normalized = String()
        normalized.reserveCapacity(text.count)
        var needsSeparator = false

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !normalized.isEmpty {
                    needsSeparator = true
                }
                continue
            }

            if needsSeparator {
                normalized.append(" ")
                needsSeparator = false
            }

            normalized.unicodeScalars.append(scalar)
        }

        return normalized
    }

    static func annotatedLine(left: String, keyword: String, right: String) -> String {
        annotatedLine(
            normalizedLeft: normalizedContext(left),
            normalizedKeyword: normalizedContext(keyword),
            normalizedRight: normalizedContext(right)
        )
    }

    static func annotatedLine(
        normalizedLeft: String,
        normalizedKeyword: String,
        normalizedRight: String
    ) -> String {
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
        citationText(
            sentenceNumber: sentenceNumber,
            normalizedKeyword: normalizedContext(keyword),
            normalizedLeft: normalizedContext(left),
            normalizedRight: normalizedContext(right),
            normalizedFullText: fullText.map(normalizedContext)
        )
    }

    static func citationText(
        sentenceNumber: Int,
        normalizedKeyword: String,
        normalizedLeft: String,
        normalizedRight: String,
        normalizedFullText: String? = nil
    ) -> String {
        let concordance = annotatedLine(
            normalizedLeft: normalizedLeft,
            normalizedKeyword: normalizedKeyword,
            normalizedRight: normalizedRight
        )
        let visibleFullText = normalizedFullText ?? ""
        var lines = ["Sentence \(sentenceNumber)", concordance]
        if !visibleFullText.isEmpty, visibleFullText != concordance {
            lines.append("Full: \(visibleFullText)")
        }
        return lines.joined(separator: "\n")
    }
}
