import Foundation

enum LexicalSuggestionSource: String, Codable, Sendable, Hashable {
    case prefix
    case collocate
}

struct LexicalSuggestion: Equatable, Sendable {
    let term: String
    let count: Int
    let rank: Int?
    let source: LexicalSuggestionSource
    let score: Double?
    let cooccurrence: Int?

    init(
        term: String,
        count: Int,
        rank: Int? = nil,
        source: LexicalSuggestionSource = .prefix,
        score: Double? = nil,
        cooccurrence: Int? = nil
    ) {
        self.term = term
        self.count = count
        self.rank = rank
        self.source = source
        self.score = score
        self.cooccurrence = cooccurrence
    }
}

typealias LexicalAutocompleteSuggestion = LexicalSuggestion

enum LexicalSuggestionStatus: Equatable, Sendable {
    case ready
    case noCorpus
    case loading
    case unavailable
    case queryTooShort(minimumLength: Int)
    case unsupportedMode
    case noMatches
    case relatedLoading
    case noRelatedMatches
}

struct LexicalSuggestionSnapshot: Equatable, Sendable {
    let suggestions: [LexicalSuggestion]
    let status: LexicalSuggestionStatus
}

enum LexicalSuggestionScope: Equatable, Sendable {
    case none
    case corpora([String])

    static func corpusID(_ corpusID: String?) -> LexicalSuggestionScope {
        guard let corpusID else { return .none }
        let trimmed = corpusID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .none : .corpora([trimmed])
    }

    var corpusIDs: [String] {
        switch self {
        case .none:
            return []
        case .corpora(let ids):
            var seen = Set<String>()
            return ids.compactMap { id in
                let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !seen.contains(trimmed) else { return nil }
                seen.insert(trimmed)
                return trimmed
            }
        }
    }

    var primaryCorpusID: String? {
        corpusIDs.first
    }
}

struct LexicalSuggestionConfiguration: Equatable, Sendable {
    var minimumQueryLength: Int
    var maxSuggestions: Int
    var maxPrefixSuggestions: Int
    var maxCollocateSuggestions: Int
    var collocateLeftWindow: Int
    var collocateRightWindow: Int
    var collocateMinFrequency: Int
    var collocateDebounceNanoseconds: UInt64

    static let `default` = LexicalSuggestionConfiguration()

    init(
        minimumQueryLength: Int = 2,
        maxSuggestions: Int = 8,
        maxPrefixSuggestions: Int = 6,
        maxCollocateSuggestions: Int = 4,
        collocateLeftWindow: Int = 5,
        collocateRightWindow: Int = 5,
        collocateMinFrequency: Int = 2,
        collocateDebounceNanoseconds: UInt64 = 180_000_000
    ) {
        self.minimumQueryLength = max(1, minimumQueryLength)
        self.maxSuggestions = max(1, maxSuggestions)
        self.maxPrefixSuggestions = max(1, maxPrefixSuggestions)
        self.maxCollocateSuggestions = max(0, maxCollocateSuggestions)
        self.collocateLeftWindow = max(0, collocateLeftWindow)
        self.collocateRightWindow = max(0, collocateRightWindow)
        self.collocateMinFrequency = max(1, collocateMinFrequency)
        self.collocateDebounceNanoseconds = collocateDebounceNanoseconds
    }

    func limitingSuggestions(to limit: Int) -> LexicalSuggestionConfiguration {
        var copy = self
        copy.maxSuggestions = max(1, limit)
        copy.maxPrefixSuggestions = min(copy.maxPrefixSuggestions, copy.maxSuggestions)
        return copy
    }
}

struct LexicalSuggestionRequest: Equatable, Sendable {
    let query: String
    let options: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let scope: LexicalSuggestionScope
    let configuration: LexicalSuggestionConfiguration

    init(
        query: String,
        options: SearchOptionsState,
        stopwordFilter: StopwordFilterState = .default,
        scope: LexicalSuggestionScope = .none,
        configuration: LexicalSuggestionConfiguration = .default
    ) {
        self.query = query
        self.options = options
        self.stopwordFilter = stopwordFilter
        self.scope = scope
        self.configuration = configuration
    }
}
