import Foundation

extension LexiconSentimentAnalyzer {
    func cueContext(
        for match: SentimentPhraseMatch,
        resolvedTokens: [String],
        normalizedTokens: [String],
        tokenRanges: [Range<String.Index>],
        quoteSpans: [Range<String.Index>]
    ) -> SentimentCueContext {
        let insideQuotes = cueCharacterRange(for: match, tokenRanges: tokenRanges)
            .map { isInsideQuotes($0, quoteSpans: quoteSpans) } ?? false
        let reportingVerb = reportingVerb(
            near: match.tokenIndex,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens,
            allowFollowingVerb: insideQuotes
        )
        let isReportedSpeech: Bool
        if insideQuotes {
            isReportedSpeech = reportingVerb != nil
        } else {
            isReportedSpeech = reportingVerb != nil && reportingConnectorExists(
                before: match.tokenIndex,
                resolvedTokens: resolvedTokens,
                normalizedTokens: normalizedTokens
            )
        }
        return SentimentCueContext(
            insideQuotes: insideQuotes,
            reportingVerb: reportingVerb,
            isReportedSpeech: isReportedSpeech
        )
    }

    func tokenRanges(
        in text: String,
        tokens: [ParsedToken]
    ) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex

        for token in tokens {
            guard searchStart <= text.endIndex,
                  let range = text.range(of: token.original, range: searchStart..<text.endIndex) else {
                continue
            }
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }

    func quoteSpans(in text: String) -> [Range<String.Index>] {
        var spans: [Range<String.Index>] = []
        var openingQuote: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\"" || character == "“" || character == "”" {
                if let existingOpeningQuote = openingQuote {
                    let start = text.index(after: existingOpeningQuote)
                    if start <= index {
                        spans.append(start..<index)
                    }
                    self.consumeTrailingQuotePunctuation(in: text, from: &index)
                    openingQuote = nil
                } else {
                    openingQuote = index
                }
            }
            index = text.index(after: index)
        }

        return spans
    }

    func consumeTrailingQuotePunctuation(
        in text: String,
        from index: inout String.Index
    ) {
        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            guard nextIndex < text.endIndex else { return }
            let character = text[nextIndex]
            if character == "," || character == "." || character == ";" || character == ":" {
                index = nextIndex
                continue
            }
            return
        }
    }

    func cueCharacterRange(
        for match: SentimentPhraseMatch,
        tokenRanges: [Range<String.Index>]
    ) -> Range<String.Index>? {
        let startIndex = match.tokenIndex
        let endIndex = match.tokenIndex + match.tokenLength - 1
        guard tokenRanges.indices.contains(startIndex),
              tokenRanges.indices.contains(endIndex) else {
            return nil
        }
        return tokenRanges[startIndex].lowerBound..<tokenRanges[endIndex].upperBound
    }

    func isInsideQuotes(
        _ cueRange: Range<String.Index>,
        quoteSpans: [Range<String.Index>]
    ) -> Bool {
        quoteSpans.contains { span in
            span.lowerBound <= cueRange.lowerBound && span.upperBound >= cueRange.upperBound
        }
    }

    func reportingVerb(
        near tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String],
        allowFollowingVerb: Bool
    ) -> String? {
        guard !resolvedTokens.isEmpty else { return nil }
        let start = max(0, tokenIndex - 4)
        let end = min(resolvedTokens.count - 1, allowFollowingVerb ? tokenIndex + 4 : tokenIndex)

        if tokenIndex > 0 {
            for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
                let resolved = resolvedTokens[candidateIndex]
                let normalized = normalizedTokens[candidateIndex]
                if lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) {
                    return resolved
                }
            }
        }

        guard allowFollowingVerb, tokenIndex + 1 <= end else { return nil }
        for candidateIndex in (tokenIndex + 1)...end {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            if lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) {
                return resolved
            }
        }

        return nil
    }

    func reportingConnectorExists(
        before tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String]
    ) -> Bool {
        guard tokenIndex > 0 else { return false }
        let start = max(0, tokenIndex - 4)
        let connectors: Set<String> = ["as", "that", "to", "be", "being", "is", "are", "was", "were"]

        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            guard lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) else {
                continue
            }
            let betweenResolved = resolvedTokens[(candidateIndex + 1)..<tokenIndex]
            let betweenNormalized = normalizedTokens[(candidateIndex + 1)..<tokenIndex]
            return betweenResolved.contains(where: connectors.contains)
                || betweenNormalized.contains(where: connectors.contains)
        }

        return false
    }

}
