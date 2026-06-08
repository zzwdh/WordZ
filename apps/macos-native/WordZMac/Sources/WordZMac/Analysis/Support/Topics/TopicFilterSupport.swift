import Foundation

enum TopicFilterSupport {
    static func filteredTerms(_ terms: [String], state: StopwordFilterState) -> [String] {
        let matcher = TopicStopwordMatcher(state: state)
        return terms.filter { matcher.matchesToken($0) }
    }

    static func matchesSegment(
        text: String,
        query: String,
        options: SearchOptionsState,
        stopword: StopwordFilterState,
        keywords: [String] = [],
        pretokenizedText: [String]? = nil,
        pretokenizedHaystack: [String]? = nil
    ) -> (matches: Bool, error: String) {
        let matcher = SearchTextMatcher(query: query, options: options)
        guard matcher.error.isEmpty else {
            return (false, matcher.error)
        }

        let stopwordMatcher = TopicStopwordMatcher(state: stopword)
        if let pretokenizedText {
            guard stopwordMatcher.matchesTextTokens(pretokenizedText) else {
                return (false, "")
            }
        } else if !stopwordMatcher.matchesText(text) {
            return (false, "")
        }

        let haystack = keywords.isEmpty ? text : "\(keywords.joined(separator: " ")) \(text)"
        if options.words {
            let tokens = pretokenizedHaystack ?? tokenize(haystack)
            return (tokens.contains(where: matcher.matches), "")
        }
        return (matcher.matches(haystack), "")
    }

    static func summaryTerms(
        from candidates: [TopicKeywordCandidate],
        filter: StopwordFilterState,
        limit: Int
    ) -> [TopicKeywordCandidate] {
        let filtered = candidates.filter { TopicStopwordMatcher(state: filter).matchesToken($0.term) }
        return Array(filtered.prefix(max(1, limit)))
    }

    static func tokenize(_ value: String) -> [String] {
        if containsCJKContent(value) {
            return AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: value)
        }

        let lowercase = value.lowercased()
        let pattern = "[^\\p{L}\\p{N}'-]+"
        let normalized = lowercase.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        return normalized
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func containsCJKContent(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF,
                 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }
}

struct TopicStopwordMatcher {
    let state: StopwordFilterState
    private let stopwordSet: Set<String>

    init(state: StopwordFilterState) {
        self.state = state
        self.stopwordSet = Set(state.parsedWords)
    }

    func matchesText(_ text: String) -> Bool {
        guard state.enabled, !stopwordSet.isEmpty else { return true }
        return matchesTextTokens(TopicFilterSupport.tokenize(text))
    }

    func matchesTextTokens(_ tokens: [String]) -> Bool {
        guard state.enabled, !stopwordSet.isEmpty else { return true }
        let contains = tokens.contains { stopwordSet.contains($0) }
        switch state.mode {
        case .include:
            return contains
        case .exclude:
            return !contains
        }
    }

    func matchesToken(_ token: String) -> Bool {
        guard state.enabled, !stopwordSet.isEmpty else { return true }
        let contains = stopwordSet.contains(token.lowercased())
        switch state.mode {
        case .include:
            return contains
        case .exclude:
            return !contains
        }
    }
}
