import Foundation

extension NativeAnalysisEngine {
    func runStats(text: String, documentKey: DocumentCacheKey? = nil) -> StatsResult {
        let index = indexedDocument(for: text, documentKey: documentKey)

        return StatsResult(
            tokenCount: index.tokenCount,
            typeCount: index.typeCount,
            ttr: index.ttr,
            sttr: index.sttr,
            sentenceCount: index.sentenceCount,
            paragraphCount: index.paragraphCount,
            frequencyRows: index.sortedFrequencyRows
        )
    }

    func runNgram(text: String, n: Int, documentKey: DocumentCacheKey? = nil) -> NgramResult {
        let document = indexedDocument(for: text, documentKey: documentKey).document
        let safeN = max(1, n)
        var counts: [String: Int] = [:]

        for sentence in document.sentences {
            let tokens = sentence.tokens.map(\.normalized)
            guard tokens.count >= safeN else { continue }
            for start in 0...(tokens.count - safeN) {
                let phrase = tokens[start..<(start + safeN)].joined(separator: " ")
                counts[phrase, default: 0] += 1
            }
        }

        let rows = counts
            .map { NgramRow(phrase: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
                }
                return $0.count > $1.count
            }

        return NgramResult(n: safeN, rows: rows)
    }

    func runTokenize(text: String, documentKey: DocumentCacheKey? = nil) -> TokenizeResult {
        let document = indexedDocument(for: text, documentKey: documentKey).document
        return TokenizeResult(
            sentences: document.sentences.map { sentence in
                TokenizedSentence(
                    sentenceId: sentence.sentenceId,
                    text: sentence.text,
                    tokens: sentence.tokens.map { token in
                        TokenizedToken(
                            original: token.original,
                            normalized: token.normalized,
                            sentenceId: token.sentenceId,
                            tokenIndex: token.tokenIndex,
                            annotations: token.annotations
                        )
                    }
                )
            }
        )
    }
}
