import Foundation

extension KeywordSuiteAnalyzer {
    static func prepareCorpus(
        entry: KeywordRequestEntry,
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        let index = ParsedDocumentIndex(text: entry.content)
        return prepareCorpus(
            entry: entry,
            tokenCount: index.tokenCount,
            typeCount: index.typeCount,
            sentences: index.document.sentences.map { sentence in
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
            },
            configuration: configuration
        )
    }

    static func prepareCorpus(
        entry: KeywordRequestEntry,
        tokenizedArtifact: StoredTokenizedArtifact,
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        prepareCorpus(
            entry: entry,
            tokenCount: tokenizedArtifact.tokenCount,
            typeCount: Set(tokenizedArtifact.frequencyMap.keys).count,
            sentences: tokenizedArtifact.sentences,
            configuration: configuration
        )
    }

    static func prepareCorpus(
        entry: KeywordRequestEntry,
        tokenCount: Int,
        typeCount: Int,
        sentences: [TokenizedSentence],
        configuration: KeywordSuiteConfiguration
    ) -> KeywordPreparedCorpus {
        let resolver = configuration.unit.lemmaStrategy
        let stopwordFilter = configuration.tokenFilters.stopwordFilter
        let stopwordSet = Set(stopwordFilter.parsedWords)
        let scriptFilter = configuration.tokenFilters.scriptFilterSet
        let lexicalClassFilter = configuration.tokenFilters.lexicalClassFilterSet

        var words = KeywordPreparedGroupAccumulator()
        var terms = KeywordPreparedGroupAccumulator()
        var ngrams = KeywordPreparedGroupAccumulator()

        for sentence in sentences {
            let resolvedTokens = sentence.tokens.compactMap { token -> KeywordResolvedToken? in
                guard configuration.tokenFilters.languagePreset.keeps(token.annotations) else { return nil }
                if !scriptFilter.isEmpty, !scriptFilter.contains(token.annotations.script) {
                    return nil
                }
                if !lexicalClassFilter.isEmpty {
                    guard let lexicalClass = token.annotations.lexicalClass, lexicalClassFilter.contains(lexicalClass) else {
                        return nil
                    }
                }

                let value = resolver.resolvedToken(
                    normalized: token.normalized,
                    annotations: token.annotations
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return nil }
                guard matchesStopwordPolicy(value, filter: stopwordFilter, stopwordSet: stopwordSet) else {
                    return nil
                }
                return KeywordResolvedToken(value: value, token: token)
            }

            for token in resolvedTokens {
                words.add(
                    item: token.value,
                    corpusID: entry.corpusId,
                    example: sentence.text
                )
            }

            for n in 2...5 {
                guard resolvedTokens.count >= n else { continue }
                for start in 0...(resolvedTokens.count - n) {
                    let slice = Array(resolvedTokens[start..<(start + n)])
                    let phrase = slice.map(\.value).joined(separator: " ")
                    ngrams.add(
                        item: phrase,
                        corpusID: entry.corpusId,
                        example: sentence.text
                    )
                    if matchesTermGrammar(tokens: slice, languagePreset: configuration.tokenFilters.languagePreset) {
                        terms.add(
                            item: phrase,
                            corpusID: entry.corpusId,
                            example: sentence.text
                        )
                    }
                }
            }
        }

        return KeywordPreparedCorpus(
            entry: entry,
            tokenCount: tokenCount,
            typeCount: typeCount,
            words: words.materialize(),
            terms: terms.materialize(),
            ngrams: ngrams.materialize()
        )
    }

    static func matchesStopwordPolicy(
        _ token: String,
        filter: StopwordFilterState,
        stopwordSet: Set<String>
    ) -> Bool {
        guard filter.enabled, !stopwordSet.isEmpty else { return true }
        let contains = stopwordSet.contains(token)
        switch filter.mode {
        case .exclude:
            return !contains
        case .include:
            return contains
        }
    }

    static func matchesTermGrammar(
        tokens: [KeywordResolvedToken],
        languagePreset: TokenizeLanguagePreset
    ) -> Bool {
        guard let last = tokens.last?.token.annotations.lexicalClass else { return false }
        let preceding = tokens.dropLast()
        let lexicalClasses = tokens.compactMap(\.token.annotations.lexicalClass)
        guard lexicalClasses.count == tokens.count else { return false }

        switch languagePreset {
        case .latinFocused:
            let allowedFinal: Set<TokenLexicalClass> = [.noun, .idiom]
            let allowedPrefix: Set<TokenLexicalClass> = [.adjective, .noun, .classifier, .idiom]
            guard allowedFinal.contains(last) else { return false }
            guard preceding.allSatisfy({ token in
                guard let lexicalClass = token.token.annotations.lexicalClass else { return false }
                return allowedPrefix.contains(lexicalClass)
            }) else {
                return false
            }
            return lexicalClasses.contains(where: { [.noun, .idiom].contains($0) })
        case .mixedChineseEnglish, .cjkFocused:
            let allowedFinal: Set<TokenLexicalClass> = [.noun, .classifier, .idiom, .other]
            let allowedPrefix: Set<TokenLexicalClass> = [.noun, .adjective, .classifier, .idiom, .other]
            guard allowedFinal.contains(last) else { return false }
            guard preceding.allSatisfy({ token in
                guard let lexicalClass = token.token.annotations.lexicalClass else { return false }
                return allowedPrefix.contains(lexicalClass)
            }) else {
                return false
            }
            return lexicalClasses.contains(where: { [.noun, .adjective, .classifier, .idiom].contains($0) })
        }
    }
}

struct KeywordPreparedCorpus {
    let entry: KeywordRequestEntry
    let tokenCount: Int
    let typeCount: Int
    let words: KeywordPreparedGroupAggregate
    let terms: KeywordPreparedGroupAggregate
    let ngrams: KeywordPreparedGroupAggregate
}

struct KeywordPreparedSideAggregate {
    let summary: KeywordSuiteScopeSummary
    let groups: [KeywordResultGroup: KeywordPreparedGroupAggregate]
}

struct KeywordPreparedGroupAggregate {
    let counts: [String: Int]
    let corpusRanges: [String: Set<String>]
    let examples: [String: KeywordExampleHit]
    let totalCount: Int

    static let empty = KeywordPreparedGroupAggregate(
        counts: [:],
        corpusRanges: [:],
        examples: [:],
        totalCount: 0
    )
}

struct KeywordPreparedGroupAccumulator {
    var counts: [String: Int] = [:]
    var ranges: [String: Set<String>] = [:]
    var examples: [String: KeywordExampleHit] = [:]
    var totalCount = 0

    mutating func add(item: String, corpusID: String, example: String) {
        counts[item, default: 0] += 1
        ranges[item, default: []].insert(corpusID)
        if examples[item] == nil {
            examples[item] = KeywordExampleHit(text: example, corpusID: corpusID)
        }
        totalCount += 1
    }

    func materialize() -> KeywordPreparedGroupAggregate {
        KeywordPreparedGroupAggregate(
            counts: counts,
            corpusRanges: ranges,
            examples: examples,
            totalCount: totalCount
        )
    }
}

struct KeywordResolvedToken {
    let value: String
    let token: TokenizedToken
}

struct KeywordExampleHit {
    let text: String
    let corpusID: String
}
