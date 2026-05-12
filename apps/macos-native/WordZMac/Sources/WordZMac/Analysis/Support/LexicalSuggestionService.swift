import Foundation

struct LexicalSuggestionCorpusFrequencyArtifact: Sendable {
    let corpusID: String
    let artifact: StoredFrequencyArtifact
}

struct LexicalSuggestionCollocateArtifact: Sendable {
    let corpusID: String
    let tokenizedArtifact: StoredTokenizedArtifact
    let positionIndex: StoredTokenPositionIndexArtifact
}

struct LexicalSuggestionIndex: Sendable {
    private struct Entry: Sendable {
        let sourceIndex: Int
        let normalizedTerm: String
        let suggestion: LexicalSuggestion
    }

    static let empty = LexicalSuggestionIndex(artifacts: [])

    private let entries: [Entry]
    private let normalizedTerms: Set<String>

    init(artifacts: [LexicalSuggestionCorpusFrequencyArtifact]) {
        var grouped: [String: (term: String, count: Int, rank: Int?, sourceIndex: Int, bestRowCount: Int)] = [:]
        var sourceIndex = 0

        for artifact in artifacts {
            for row in artifact.artifact.frequencyRows {
                defer { sourceIndex += 1 }
                let normalizedTerm = AnalysisTextNormalizationSupport.normalizeToken(row.word)
                guard !normalizedTerm.isEmpty else { continue }

                if var existing = grouped[normalizedTerm] {
                    let previousBestRowCount = existing.bestRowCount
                    existing.count += row.count
                    if row.rank > 0 {
                        existing.rank = existing.rank.map { min($0, row.rank) } ?? row.rank
                    }
                    if row.count > previousBestRowCount {
                        existing.term = row.word
                        existing.bestRowCount = row.count
                    }
                    grouped[normalizedTerm] = existing
                } else {
                    grouped[normalizedTerm] = (
                        term: row.word,
                        count: row.count,
                        rank: row.rank > 0 ? row.rank : nil,
                        sourceIndex: sourceIndex,
                        bestRowCount: row.count
                    )
                }
            }
        }

        self.entries = grouped.map { normalizedTerm, value in
            Entry(
                sourceIndex: value.sourceIndex,
                normalizedTerm: normalizedTerm,
                suggestion: LexicalSuggestion(
                    term: value.term,
                    count: value.count,
                    rank: value.rank,
                    source: .prefix
                )
            )
        }
        .sorted(by: Self.areInSuggestionOrder)
        self.normalizedTerms = Set(grouped.keys)
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    func containsExactTerm(_ normalizedTerm: String) -> Bool {
        normalizedTerms.contains(normalizedTerm)
    }

    func prefixSuggestions(
        for normalizedPrefix: String,
        limit: Int,
        stopwordFilter: StopwordFilterState
    ) -> [LexicalSuggestion] {
        guard !normalizedPrefix.isEmpty else { return [] }
        let filter = LexicalSuggestionStopwordFilter(state: stopwordFilter)
        let safeLimit = max(1, limit)
        return Array(
            entries.lazy
                .filter { $0.normalizedTerm.hasPrefix(normalizedPrefix) }
                .map(\.suggestion)
                .filter { filter.matches($0.term) }
                .prefix(safeLimit)
        )
    }

    private static func areInSuggestionOrder(_ lhs: Entry, _ rhs: Entry) -> Bool {
        if lhs.suggestion.count != rhs.suggestion.count {
            return lhs.suggestion.count > rhs.suggestion.count
        }

        if lhs.normalizedTerm != rhs.normalizedTerm {
            return lhs.normalizedTerm < rhs.normalizedTerm
        }

        if lhs.suggestion.term != rhs.suggestion.term {
            return lhs.suggestion.term < rhs.suggestion.term
        }

        return lhs.sourceIndex < rhs.sourceIndex
    }
}

struct LexicalSuggestionService: Sendable {
    static let empty = LexicalSuggestionService(
        index: .empty,
        collocateArtifact: nil
    )

    let index: LexicalSuggestionIndex
    let collocateArtifact: LexicalSuggestionCollocateArtifact?

    init(
        frequencyArtifacts: [LexicalSuggestionCorpusFrequencyArtifact],
        collocateArtifact: LexicalSuggestionCollocateArtifact?
    ) {
        self.index = LexicalSuggestionIndex(artifacts: frequencyArtifacts)
        self.collocateArtifact = frequencyArtifacts.count == 1 ? collocateArtifact : nil
    }

    private init(
        index: LexicalSuggestionIndex,
        collocateArtifact: LexicalSuggestionCollocateArtifact?
    ) {
        self.index = index
        self.collocateArtifact = collocateArtifact
    }

    var isEmpty: Bool {
        index.isEmpty
    }

    func normalizedSingleTokenQuery(
        for request: LexicalSuggestionRequest
    ) -> String {
        guard request.options.regex == false,
              request.options.matchMode == .token else {
            return ""
        }

        let trimmed = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= request.configuration.minimumQueryLength else { return "" }
        guard trimmed.contains("*") == false, trimmed.contains("?") == false else {
            return ""
        }

        let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(
            in: trimmed,
            caseSensitive: request.options.caseSensitive
        )
        guard tokens.count == 1, let token = tokens.first else {
            return ""
        }

        return token
    }

    func prefixSuggestions(for request: LexicalSuggestionRequest) -> [LexicalSuggestion] {
        let normalizedPrefix = normalizedSingleTokenQuery(for: request)
        guard !normalizedPrefix.isEmpty else { return [] }
        return index.prefixSuggestions(
            for: normalizedPrefix,
            limit: min(request.configuration.maxPrefixSuggestions, request.configuration.maxSuggestions),
            stopwordFilter: request.stopwordFilter
        )
    }

    func canSuggestCollocates(for request: LexicalSuggestionRequest) -> Bool {
        guard request.configuration.maxCollocateSuggestions > 0,
              collocateArtifact != nil else {
            return false
        }
        let normalizedQuery = normalizedSingleTokenQuery(for: request)
        guard !normalizedQuery.isEmpty else { return false }
        return index.containsExactTerm(normalizedQuery)
    }

    func collocateSuggestions(for request: LexicalSuggestionRequest) -> [LexicalSuggestion] {
        guard let artifact = collocateArtifact else { return [] }
        let normalizedQuery = normalizedSingleTokenQuery(for: request)
        guard !normalizedQuery.isEmpty,
              index.containsExactTerm(normalizedQuery) else {
            return []
        }

        let lookup = StoredTokenPositionIndexArtifact.Lookup(
            mode: request.options.caseSensitive ? .exact : .normalized,
            key: normalizedQuery
        )
        let positions = artifact.positionIndex.positions(for: lookup)
        guard !positions.isEmpty else { return [] }

        let rows = CollocateAssociationCalculator.calculate(
            sentences: artifact.tokenizedArtifact.sentences.map(CollocateAssociationCalculator.Sentence.init),
            nodeRanges: positions.map {
                CollocateAssociationCalculator.NodeRange(
                    sentenceId: $0.sentenceId,
                    startIndex: $0.tokenIndex,
                    endIndex: $0.tokenIndex
                )
            },
            frequencyMap: artifact.tokenizedArtifact.frequencyMap,
            tokenCount: artifact.tokenizedArtifact.tokenCount,
            leftWindow: request.configuration.collocateLeftWindow,
            rightWindow: request.configuration.collocateRightWindow,
            minFreq: request.configuration.collocateMinFrequency
        )

        let filter = LexicalSuggestionStopwordFilter(state: request.stopwordFilter)
        return rows
            .filter { row in
                row.word != normalizedQuery && filter.matches(row.word)
            }
            .sorted {
                if $0.logDice != $1.logDice {
                    return $0.logDice > $1.logDice
                }
                if $0.total != $1.total {
                    return $0.total > $1.total
                }
                return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
            .prefix(request.configuration.maxCollocateSuggestions)
            .map { row in
                LexicalSuggestion(
                    term: row.word,
                    count: row.wordFreq,
                    rank: nil,
                    source: .collocate,
                    score: row.logDice,
                    cooccurrence: row.total
                )
            }
    }

    func combinedSuggestions(
        prefixSuggestions: [LexicalSuggestion],
        collocateSuggestions: [LexicalSuggestion],
        configuration: LexicalSuggestionConfiguration
    ) -> [LexicalSuggestion] {
        let prefixLimit = min(configuration.maxPrefixSuggestions, configuration.maxSuggestions)
        var combined = Array(prefixSuggestions.prefix(prefixLimit))
        var seen = Set(combined.map { AnalysisTextNormalizationSupport.normalizeToken($0.term) })
        let remaining = max(0, configuration.maxSuggestions - combined.count)
        guard remaining > 0 else {
            return Array(combined.prefix(configuration.maxSuggestions))
        }

        for suggestion in collocateSuggestions.prefix(min(configuration.maxCollocateSuggestions, remaining)) {
            let normalized = AnalysisTextNormalizationSupport.normalizeToken(suggestion.term)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            combined.append(suggestion)
            if combined.count >= configuration.maxSuggestions {
                break
            }
        }

        return combined
    }
}

private struct LexicalSuggestionStopwordFilter {
    let state: StopwordFilterState
    let stopwordSet: Set<String>

    init(state: StopwordFilterState) {
        self.state = state
        self.stopwordSet = Set(state.parsedWords)
    }

    func matches(_ term: String) -> Bool {
        guard state.enabled, !stopwordSet.isEmpty else { return true }
        let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: term)
        let containsStopword = tokens.contains { stopwordSet.contains($0) }
        switch state.mode {
        case .exclude:
            return !containsStopword
        case .include:
            return containsStopword
        }
    }
}
