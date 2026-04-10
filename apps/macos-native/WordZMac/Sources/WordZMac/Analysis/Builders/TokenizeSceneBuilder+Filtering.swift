import Foundation

extension TokenizeSceneBuilder {
    func filterRows(
        _ rows: [TokenizedToken],
        query: String,
        options: SearchOptionsState,
        stopword: StopwordFilterState,
        lemmaStrategy: TokenLemmaStrategy
    ) -> (rows: [TokenizedToken], error: String) {
        let matcher = SearchTextMatcher(query: query, options: options)
        guard matcher.error.isEmpty else {
            return ([], matcher.error)
        }

        let stopwordSet = Set(stopword.parsedWords)
        if matcher.isPassthrough && (!stopword.enabled || stopwordSet.isEmpty) {
            return (rows, "")
        }

        let filtered = rows.filter { token in
            let candidates = searchableCandidates(for: token, lemmaStrategy: lemmaStrategy)
            let queryMatches = matcher.isPassthrough || candidates.contains(where: matcher.matches)
            let containsStopword = candidates.contains { candidate in
                stopwordSet.contains(AnalysisTextNormalizationSupport.normalizeToken(candidate))
            }
            let stopwordMatches: Bool
            if !stopword.enabled || stopwordSet.isEmpty {
                stopwordMatches = true
            } else {
                switch stopword.mode {
                case .include:
                    stopwordMatches = containsStopword
                case .exclude:
                    stopwordMatches = !containsStopword
                }
            }
            return queryMatches && stopwordMatches
        }
        return (filtered, "")
    }

    func searchableCandidates(
        for token: TokenizedToken,
        lemmaStrategy: TokenLemmaStrategy
    ) -> [String] {
        let resolvedLemma = lemmaStrategy.resolvedToken(normalized: token.normalized, annotations: token.annotations)
        var seen = Set<String>()
        return [
            token.original,
            token.normalized,
            token.annotations.lemma,
            resolvedLemma
        ]
        .compactMap { value in
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let normalized = AnalysisTextNormalizationSupport.normalizeToken(trimmed)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return trimmed
        }
    }
}
