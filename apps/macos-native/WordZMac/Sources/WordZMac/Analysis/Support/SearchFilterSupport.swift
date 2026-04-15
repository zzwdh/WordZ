import Foundation

struct SearchTextMatcher {
    let normalizedQuery: String
    let options: SearchOptionsState
    let error: String
    let phraseTokens: [String]

    private let regex: NSRegularExpression?
    private let wildcardRegex: NSRegularExpression?

    var isPassthrough: Bool {
        normalizedQuery.isEmpty
    }

    init(query: String, options: SearchOptionsState) {
        self.normalizedQuery = AnalysisTextNormalizationSupport.normalizeSearchText(
            query,
            caseSensitive: options.caseSensitive
        )
        self.phraseTokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(
            in: query,
            caseSensitive: options.caseSensitive
        )
        self.options = options

        if options.regex, !normalizedQuery.isEmpty {
            let pattern = options.words ? "^(?:\(normalizedQuery))$" : normalizedQuery
            do {
                self.regex = try NSRegularExpression(
                    pattern: pattern,
                    options: []
                )
                self.wildcardRegex = nil
                self.error = ""
            } catch {
                self.regex = nil
                self.wildcardRegex = nil
                self.error = "无效的正则表达式：\(error.localizedDescription)"
            }
            return
        }

        self.regex = nil
        self.wildcardRegex = SearchTextMatcher.buildWildcardRegex(
            for: normalizedQuery,
            words: options.words,
            caseSensitive: options.caseSensitive
        )
        self.error = ""
    }

    func matches(_ value: String) -> Bool {
        if isPassthrough {
            return true
        }

        if options.matchMode == .phraseExact {
            let candidateTokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(
                in: value,
                caseSensitive: options.caseSensitive
            )
            return matchesPhraseTokens(candidateTokens)
        }

        let candidateText = AnalysisTextNormalizationSupport.normalizeSearchText(
            value,
            caseSensitive: options.caseSensitive
        )

        if let regex {
            let candidate = candidateText as NSString
            let fullRange = NSRange(location: 0, length: candidate.length)
            return regex.firstMatch(in: candidateText, options: [], range: fullRange) != nil
        }

        if let wildcardRegex {
            let candidate = candidateText as NSString
            let fullRange = NSRange(location: 0, length: candidate.length)
            return wildcardRegex.firstMatch(in: candidateText, options: [], range: fullRange) != nil
        }

        return options.words ? candidateText == normalizedQuery : candidateText.contains(normalizedQuery)
    }

    func matchingPhraseRanges<T>(
        in tokens: [T],
        comparableText: (T) -> String
    ) -> [Range<Int>] {
        guard options.matchMode == .phraseExact else { return [] }
        guard !phraseTokens.isEmpty else { return [] }
        guard tokens.count >= phraseTokens.count else { return [] }

        var ranges: [Range<Int>] = []
        for startIndex in 0...(tokens.count - phraseTokens.count) {
            var matched = true
            for offset in phraseTokens.indices {
                let tokenText = AnalysisTextNormalizationSupport.normalizeSearchText(
                    comparableText(tokens[startIndex + offset]),
                    caseSensitive: options.caseSensitive
                )
                if tokenText != phraseTokens[offset] {
                    matched = false
                    break
                }
            }
            if matched {
                ranges.append(startIndex..<(startIndex + phraseTokens.count))
            }
        }
        return ranges
    }

    var exactLookup: StoredTokenPositionIndexArtifact.Lookup? {
        guard !normalizedQuery.isEmpty,
              options.matchMode == .token,
              options.words,
              !options.regex,
              wildcardRegex == nil else {
            return nil
        }

        return StoredTokenPositionIndexArtifact.Lookup(
            mode: options.caseSensitive ? .exact : .normalized,
            key: normalizedQuery
        )
    }

    private static func buildWildcardRegex(
        for query: String,
        words: Bool,
        caseSensitive: Bool
    ) -> NSRegularExpression? {
        guard query.contains("*") || query.contains("?") else { return nil }
        let escaped = NSRegularExpression.escapedPattern(for: query)
        let wildcardPattern = escaped
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let pattern = words ? "^(?:\(wildcardPattern))$" : wildcardPattern
        let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    private func matchesPhraseTokens(_ candidateTokens: [String]) -> Bool {
        guard !phraseTokens.isEmpty else { return true }
        guard candidateTokens.count >= phraseTokens.count else { return false }

        for startIndex in 0...(candidateTokens.count - phraseTokens.count) {
            let slice = Array(candidateTokens[startIndex..<(startIndex + phraseTokens.count)])
            if slice == phraseTokens {
                return true
            }
        }
        return false
    }
}

enum SearchFilterSupport {
    static func filterWordLikeRows<Row>(
        _ rows: [Row],
        query: String,
        options: SearchOptionsState,
        stopword: StopwordFilterState,
        text: (Row) -> String
    ) -> (rows: [Row], error: String) {
        let matcher = SearchTextMatcher(query: query, options: options)
        guard matcher.error.isEmpty else {
            return ([], matcher.error)
        }

        let stopwordMatcher = StopwordMatcher(state: stopword)
        if matcher.isPassthrough && stopwordMatcher.isPassthrough {
            return (rows, "")
        }
        let filtered = rows.filter { row in
            let value = text(row)
            return matcher.matches(value) && stopwordMatcher.matches(value)
        }
        return (filtered, "")
    }
}

private struct StopwordMatcher {
    let state: StopwordFilterState
    let stopwordSet: Set<String>

    var isPassthrough: Bool {
        !state.enabled || stopwordSet.isEmpty
    }

    init(state: StopwordFilterState) {
        self.state = state
        self.stopwordSet = Set(state.parsedWords)
    }

    func matches(_ text: String) -> Bool {
        guard !isPassthrough else { return true }
        let contains = tokenize(text).contains { stopwordSet.contains($0) }
        switch state.mode {
        case .include:
            return contains
        case .exclude:
            return !contains
        }
    }

    private func tokenize(_ value: String) -> [String] {
        AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: value)
    }
}
