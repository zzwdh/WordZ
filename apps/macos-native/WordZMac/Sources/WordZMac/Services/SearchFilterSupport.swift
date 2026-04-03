import Foundation

struct SearchTextMatcher {
    let normalizedQuery: String
    let options: SearchOptionsState
    let error: String

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
