import Foundation

struct SearchTextMatcher {
    let normalizedQuery: String
    let options: SearchOptionsState
    let error: String

    private let regex: NSRegularExpression?
    private let wildcardRegex: NSRegularExpression?

    init(query: String, options: SearchOptionsState) {
        self.normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.options = options

        if options.regex, !normalizedQuery.isEmpty {
            let pattern = options.words ? "^(?:\(normalizedQuery))$" : normalizedQuery
            do {
                let flags: NSRegularExpression.Options = []
                self.regex = try NSRegularExpression(
                    pattern: pattern,
                    options: flags
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
        if normalizedQuery.isEmpty {
            return true
        }

        if options.regex {
            guard let regex else { return false }
            let candidate = value as NSString
            let fullRange = NSRange(location: 0, length: candidate.length)
            if options.caseSensitive {
                return regex.firstMatch(in: value, options: [], range: fullRange) != nil
            }
            let mutablePattern = regex.pattern
            let regexOptions: NSRegularExpression.Options = [.caseInsensitive]
            guard let caseInsensitiveRegex = try? NSRegularExpression(pattern: mutablePattern, options: regexOptions) else {
                return false
            }
            return caseInsensitiveRegex.firstMatch(in: value, options: [], range: fullRange) != nil
        }

        if let wildcardRegex {
            let candidate = value as NSString
            let fullRange = NSRange(location: 0, length: candidate.length)
            return wildcardRegex.firstMatch(in: value, options: [], range: fullRange) != nil
        }

        let needle = options.caseSensitive ? normalizedQuery : normalizedQuery.lowercased()
        let haystack = options.caseSensitive ? value : value.lowercased()
        return options.words ? haystack == needle : haystack.contains(needle)
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

    init(state: StopwordFilterState) {
        self.state = state
        self.stopwordSet = Set(state.parsedWords)
    }

    func matches(_ text: String) -> Bool {
        guard state.enabled, !stopwordSet.isEmpty else { return true }
        let contains = tokenize(text).contains { stopwordSet.contains($0) }
        switch state.mode {
        case .include:
            return contains
        case .exclude:
            return !contains
        }
    }

    private func tokenize(_ value: String) -> [String] {
        let lowercase = value.lowercased()
        let pattern = "[^\\p{L}\\p{N}'-]+"
        let normalized = lowercase.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        return normalized
            .split(separator: " ")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
