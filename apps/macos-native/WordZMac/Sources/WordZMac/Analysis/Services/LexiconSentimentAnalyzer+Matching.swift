import Foundation

extension LexiconSentimentAnalyzer {
    func sentimentMatches(
        in tokens: [ParsedToken],
        resolvedPack: SentimentResolvedRulePack
    ) -> [SentimentPhraseMatch] {
        let lemmaTokens = tokens.map {
            TokenLemmaStrategy.lemmaPreferred.resolvedToken(
                normalized: $0.normalized,
                annotations: $0.annotations
            )
        }

        var matches: [SentimentPhraseMatch] = []
        var index = 0

        while index < tokens.count {
            var matchedPhrase: SentimentPhraseMatch?
            let remaining = tokens.count - index
            let maxLength = min(resolvedPack.maxEntryLength, remaining)

            if maxLength > 0 {
                for length in stride(from: maxLength, through: 1, by: -1) {
                    guard let entries = resolvedPack.entriesByLength[length] else { continue }
                    let normalizedSlice = Array(tokens[index..<(index + length)].map(\.normalized))
                    let lemmaSlice = Array(lemmaTokens[index..<(index + length)])
                    if let entry = entries.first(where: {
                        switch $0.matchMode {
                        case .lemma:
                            return $0.tokens == lemmaSlice
                        case .surface:
                            return $0.tokens == normalizedSlice
                        case .either:
                            return $0.tokens == lemmaSlice || $0.tokens == normalizedSlice
                        }
                    }) {
                        matchedPhrase = SentimentPhraseMatch(
                            entry: entry,
                            tokenIndex: index,
                            tokenLength: length,
                            surface: tokens[index..<(index + length)].map(\.original).joined(separator: " "),
                            lemma: lemmaSlice.joined(separator: " ")
                        )
                        break
                    }
                }
            }

            if let matchedPhrase {
                matches.append(matchedPhrase)
                index += matchedPhrase.tokenLength
            } else {
                index += 1
            }
        }

        return matches
    }

}
