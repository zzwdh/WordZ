import Foundation

struct SentimentClauseSegment: Sendable {
    let index: Int
    let startTokenIndex: Int
    let endTokenIndex: Int
    let weight: Double
}

struct SentimentScopeSegmenter: Sendable {
    func segment(
        tokens: [ParsedToken],
        resolvedTokens: [String],
        lexicon: SentimentLexiconStore
    ) -> [SentimentClauseSegment] {
        guard !tokens.isEmpty else { return [] }

        var boundaries: [Int] = [0]
        for index in tokens.indices {
            let original = tokens[index].original
            let normalized = resolvedTokens[index]
            if lexicon.contrastives.contains(normalized) {
                if index > 0 {
                    boundaries.append(index)
                }
                let nextIndex = min(index + 1, tokens.count)
                if nextIndex < tokens.count {
                    boundaries.append(nextIndex)
                }
            } else if [",", ";", ":", ".", "!", "?"].contains(original) {
                let nextIndex = min(index + 1, tokens.count)
                if nextIndex < tokens.count {
                    boundaries.append(nextIndex)
                }
            }
        }
        boundaries.append(tokens.count)

        let ordered = Array(Set(boundaries)).sorted()
        var segments: [SentimentClauseSegment] = []
        for pair in ordered.indices.dropLast() {
            let start = ordered[pair]
            let endExclusive = ordered[pair + 1]
            guard start < endExclusive else { continue }
            segments.append(
                SentimentClauseSegment(
                    index: segments.count,
                    startTokenIndex: start,
                    endTokenIndex: endExclusive - 1,
                    weight: 1.0
                )
            )
        }

        if segments.count == 1 {
            return [SentimentClauseSegment(index: 0, startTokenIndex: 0, endTokenIndex: tokens.count - 1, weight: 1.0)]
        }
        return segments
    }
}

struct SentimentRulePackResolver: Sendable {
    let lexicon: SentimentLexiconStore

    func resolve(for request: SentimentRunRequest) -> SentimentResolvedRulePack {
        lexicon.resolvePack(
            domainPackID: request.resolvedDomainPackID,
            customEntries: request.ruleProfile.customEntries
        )
    }
}

protocol SentimentCalibrationProfileProviding: Sendable {
    func calibrationProfile(for request: SentimentRunRequest) -> SentimentCalibrationProfile
}

struct DefaultSentimentCalibrationProfileProvider: SentimentCalibrationProfileProviding {
    func calibrationProfile(for request: SentimentRunRequest) -> SentimentCalibrationProfile {
        request.calibrationProfile
    }
}
