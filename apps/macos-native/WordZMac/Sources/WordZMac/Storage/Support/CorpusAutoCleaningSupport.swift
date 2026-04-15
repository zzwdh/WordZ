import Foundation

struct CorpusAutoCleaningResult: Equatable {
    let rawText: String
    let cleanedText: String
    let ruleHits: [LibraryCorpusCleaningRuleHit]

    var hasChanges: Bool {
        rawText != cleanedText
    }

    var originalCharacterCount: Int {
        rawText.count
    }

    var cleanedCharacterCount: Int {
        cleanedText.count
    }
}

enum CorpusAutoCleaningSupport {
    static let profileVersion = "v1"

    static func clean(_ text: String) -> CorpusAutoCleaningResult {
        let rawText = text
        var workingText = text
        var hits: [LibraryCorpusCleaningRuleHit] = []

        let compatibilityMapped = workingText.precomposedStringWithCompatibilityMapping
        if compatibilityMapped != workingText {
            workingText = compatibilityMapped
            hits.append(.init(id: "compatibility-mapping", count: 1))
        }

        let normalizedLineEndingCount = countOccurrences(of: "\r\n", in: workingText)
            + countStandaloneCarriageReturns(in: workingText)
            + countOccurrences(of: "\u{000C}", in: workingText)
            + countOccurrences(of: "\u{2028}", in: workingText)
            + countOccurrences(of: "\u{2029}", in: workingText)
        if normalizedLineEndingCount > 0 {
            workingText = workingText
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .replacingOccurrences(of: "\u{000C}", with: "\n")
                .replacingOccurrences(of: "\u{2028}", with: "\n")
                .replacingOccurrences(of: "\u{2029}", with: "\n")
            hits.append(.init(id: "line-ending-normalization", count: normalizedLineEndingCount))
        }

        let spaceNormalizationCount = countOccurrences(of: "\u{00A0}", in: workingText)
            + countOccurrences(of: "\u{3000}", in: workingText)
            + countOccurrences(of: "\t", in: workingText)
        if spaceNormalizationCount > 0 {
            workingText = workingText
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: "\u{3000}", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
            hits.append(.init(id: "space-normalization", count: spaceNormalizationCount))
        }

        let bomCount = countOccurrences(of: "\u{FEFF}", in: workingText)
        if bomCount > 0 {
            workingText = workingText.replacingOccurrences(of: "\u{FEFF}", with: "")
            hits.append(.init(id: "bom-removal", count: bomCount))
        }

        let zeroWidthScalars: Set<UInt32> = [0x200B, 0x200C, 0x200D, 0x2060]
        let zeroWidthCount = workingText.unicodeScalars.reduce(into: 0) { count, scalar in
            if zeroWidthScalars.contains(scalar.value) {
                count += 1
            }
        }
        if zeroWidthCount > 0 {
            workingText.unicodeScalars.removeAll { zeroWidthScalars.contains($0.value) }
            hits.append(.init(id: "zero-width-removal", count: zeroWidthCount))
        }

        let nullCount = countOccurrences(of: "\u{0000}", in: workingText)
        if nullCount > 0 {
            workingText = workingText.replacingOccurrences(of: "\u{0000}", with: "")
            hits.append(.init(id: "null-removal", count: nullCount))
        }

        let controlCharacterCount = workingText.unicodeScalars.reduce(into: 0) { count, scalar in
            guard CharacterSet.controlCharacters.contains(scalar) else { return }
            if scalar == "\n" {
                return
            }
            count += 1
        }
        if controlCharacterCount > 0 {
            workingText.unicodeScalars.removeAll {
                CharacterSet.controlCharacters.contains($0) && $0 != "\n"
            }
            hits.append(.init(id: "control-character-removal", count: controlCharacterCount))
        }

        let trimmedTrailingWhitespace = trimTrailingWhitespace(in: workingText)
        workingText = trimmedTrailingWhitespace.text
        if trimmedTrailingWhitespace.trimmedLineCount > 0 {
            hits.append(.init(id: "trailing-whitespace-trim", count: trimmedTrailingWhitespace.trimmedLineCount))
        }

        let outerBlankLineTrim = trimOuterBlankLines(in: workingText)
        workingText = outerBlankLineTrim.text
        if outerBlankLineTrim.removedLineCount > 0 {
            hits.append(.init(id: "outer-blank-line-trim", count: outerBlankLineTrim.removedLineCount))
        }

        let collapsedBlankLineRuns = collapseBlankLineRuns(in: workingText, maxConsecutiveBlankLines: 2)
        workingText = collapsedBlankLineRuns.text
        if collapsedBlankLineRuns.removedLineCount > 0 {
            hits.append(.init(id: "blank-line-collapse", count: collapsedBlankLineRuns.removedLineCount))
        }

        return CorpusAutoCleaningResult(
            rawText: rawText,
            cleanedText: workingText,
            ruleHits: hits.filter { $0.count > 0 }
        )
    }

    static func makeReportSummary(
        from result: CorpusAutoCleaningResult,
        cleanedAt: String
    ) -> LibraryCorpusCleaningReportSummary {
        LibraryCorpusCleaningReportSummary(
            status: result.hasChanges ? .cleanedWithChanges : .cleaned,
            cleanedAt: cleanedAt,
            profileVersion: profileVersion,
            originalCharacterCount: result.originalCharacterCount,
            cleanedCharacterCount: result.cleanedCharacterCount,
            ruleHits: result.ruleHits
        )
    }

    private static func countOccurrences(of target: String, in text: String) -> Int {
        guard !target.isEmpty, !text.isEmpty else { return 0 }
        return text.components(separatedBy: target).count - 1
    }

    private static func countStandaloneCarriageReturns(in text: String) -> Int {
        max(0, countOccurrences(of: "\r", in: text) - countOccurrences(of: "\r\n", in: text))
    }

    private static func trimTrailingWhitespace(in text: String) -> (text: String, trimmedLineCount: Int) {
        let lines = text.components(separatedBy: "\n")
        var trimmedLineCount = 0
        let normalized = lines.map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed != line {
                trimmedLineCount += 1
            }
            return trimmed
        }
        return (normalized.joined(separator: "\n"), trimmedLineCount)
    }

    private static func trimOuterBlankLines(in text: String) -> (text: String, removedLineCount: Int) {
        var lines = text.components(separatedBy: "\n")
        var removedLineCount = 0

        while let first = lines.first, first.isEmpty {
            lines.removeFirst()
            removedLineCount += 1
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
            removedLineCount += 1
        }

        return (lines.joined(separator: "\n"), removedLineCount)
    }

    private static func collapseBlankLineRuns(
        in text: String,
        maxConsecutiveBlankLines: Int
    ) -> (text: String, removedLineCount: Int) {
        let lines = text.components(separatedBy: "\n")
        guard !lines.isEmpty else { return (text, 0) }

        var collapsed: [String] = []
        collapsed.reserveCapacity(lines.count)

        var consecutiveBlankLines = 0
        var removedLineCount = 0

        for line in lines {
            if line.isEmpty {
                consecutiveBlankLines += 1
                if consecutiveBlankLines > maxConsecutiveBlankLines {
                    removedLineCount += 1
                    continue
                }
            } else {
                consecutiveBlankLines = 0
            }
            collapsed.append(line)
        }

        return (collapsed.joined(separator: "\n"), removedLineCount)
    }
}
