import Foundation

enum StopwordFilterMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case exclude
    case include

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .exclude:
            return wordZText("筛去词表内词项", "Exclude listed words", mode: mode)
        case .include:
            return wordZText("仅保留词表内词项（白名单）", "Keep only listed words (allowlist)", mode: mode)
        }
    }

    var title: String {
        title(in: .system)
    }
}

struct SearchOptionsState: Equatable, Codable, Sendable {
    var words: Bool = true
    var caseSensitive: Bool = false
    var regex: Bool = false

    static let `default` = SearchOptionsState()

    init(words: Bool = true, caseSensitive: Bool = false, regex: Bool = false) {
        self.words = words
        self.caseSensitive = caseSensitive
        self.regex = regex
    }

    init(json: JSONObject) {
        self.words = JSONFieldReader.bool(json, key: "words", fallback: true)
        self.caseSensitive = JSONFieldReader.bool(json, key: "caseSensitive")
            || JSONFieldReader.bool(json, key: "case")
        self.regex = JSONFieldReader.bool(json, key: "regex")
    }

    func asJSONObject() -> JSONObject {
        [
            "words": words,
            "caseSensitive": caseSensitive,
            "regex": regex
        ]
    }

    func summaryText(in mode: AppLanguageMode) -> String {
        var enabled: [String] = []
        if words { enabled.append(wordZText("整词", "Whole words", mode: mode)) }
        if caseSensitive { enabled.append(wordZText("区分大小写", "Case sensitive", mode: mode)) }
        if regex { enabled.append("Regex") }
        return enabled.isEmpty
            ? wordZText("默认匹配", "Default matching", mode: mode)
            : enabled.joined(separator: " / ")
    }

    var summaryText: String {
        summaryText(in: .system)
    }
}

struct StopwordFilterState: Equatable, Codable, Sendable {
    static let defaultListText = """
    a
    an
    and
    are
    as
    at
    be
    been
    being
    but
    by
    for
    from
    had
    has
    have
    he
    her
    hers
    him
    his
    i
    if
    in
    into
    is
    it
    its
    me
    my
    of
    on
    or
    our
    ours
    she
    that
    the
    their
    theirs
    them
    they
    this
    to
    us
    was
    we
    were
    with
    you
    your
    yours
    """

    var enabled: Bool = false
    var mode: StopwordFilterMode = .exclude
    var listText: String = StopwordFilterState.defaultListText

    static let `default` = StopwordFilterState()

    init(
        enabled: Bool = false,
        mode: StopwordFilterMode = .exclude,
        listText: String = StopwordFilterState.defaultListText
    ) {
        self.enabled = enabled
        self.mode = mode
        self.listText = Self.normalizeListText(listText)
    }

    init(json: JSONObject) {
        self.enabled = JSONFieldReader.bool(json, key: "enabled")
        self.mode = StopwordFilterMode(rawValue: JSONFieldReader.string(json, key: "mode", fallback: "exclude")) ?? .exclude
        self.listText = Self.normalizeListText(
            JSONFieldReader.string(json, key: "listText", fallback: StopwordFilterState.defaultListText)
        )
    }

    func asJSONObject() -> JSONObject {
        [
            "enabled": enabled,
            "mode": mode.rawValue,
            "listText": Self.normalizeListText(listText)
        ]
    }

    var parsedWords: [String] {
        Self.parseList(listText)
    }

    func summaryText(in mode: AppLanguageMode) -> String {
        let count = parsedWords.count
        if !enabled {
            return wordZText("停用词关闭", "Stopwords off", mode: mode)
        }
        if count == 0 {
            return wordZText("词表为空 · 当前不生效", "List is empty · inactive", mode: mode)
        }
        switch self.mode {
        case .include:
            return wordZText("白名单模式 · \(count) 词", "Allowlist mode · \(count) terms", mode: mode)
        case .exclude:
            return wordZText("筛去词表内词项 · \(count) 词", "Exclude listed words · \(count) terms", mode: mode)
        }
    }

    var summaryText: String {
        summaryText(in: .system)
    }

    static func normalizeListText(_ value: String) -> String {
        parseList(value).joined(separator: "\n")
    }

    static func parseList(_ value: String) -> [String] {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        var seen = Set<String>()
        var words: [String] = []
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，;；"))
        for part in normalized.components(separatedBy: separators) {
            let word = AnalysisTextNormalizationSupport.normalizeToken(part)
            guard !word.isEmpty, !seen.contains(word) else { continue }
            seen.insert(word)
            words.append(word)
        }
        return words
    }
}
