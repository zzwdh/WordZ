import Foundation

enum KeywordSuiteTab: String, CaseIterable, Identifiable, Codable, Sendable {
    case words
    case terms
    case ngrams
    case lists

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .words:
            return wordZText("词", "Words", mode: mode)
        case .terms:
            return wordZText("术语", "Terms", mode: mode)
        case .ngrams:
            return wordZText("N-grams", "N-grams", mode: mode)
        case .lists:
            return wordZText("词表", "Lists", mode: mode)
        }
    }
}

enum KeywordTargetSelectionKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case singleCorpus
    case selectedCorpora
    case namedCorpusSet

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .singleCorpus:
            return wordZText("单条语料", "Single Corpus", mode: mode)
        case .selectedCorpora:
            return wordZText("所选语料（合并）", "Selected Corpora (Pooled)", mode: mode)
        case .namedCorpusSet:
            return wordZText("命名语料集", "Named Corpus Set", mode: mode)
        }
    }
}

struct KeywordTargetSelection: Equatable, Codable, Sendable {
    var kind: KeywordTargetSelectionKind
    var corpusIDs: [String]
    var corpusSetID: String

    static let empty = KeywordTargetSelection(kind: .singleCorpus, corpusIDs: [], corpusSetID: "")

    init(
        kind: KeywordTargetSelectionKind = .singleCorpus,
        corpusIDs: [String] = [],
        corpusSetID: String = ""
    ) {
        self.kind = kind
        self.corpusIDs = corpusIDs
        self.corpusSetID = corpusSetID
    }
}

enum KeywordReferenceSourceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case singleCorpus
    case namedCorpusSet
    case importedWordList

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .singleCorpus:
            return wordZText("单条语料", "Single Corpus", mode: mode)
        case .namedCorpusSet:
            return wordZText("命名语料集", "Named Corpus Set", mode: mode)
        case .importedWordList:
            return wordZText("导入词表", "Imported Word List", mode: mode)
        }
    }
}

struct KeywordReferenceSource: Equatable, Codable, Sendable {
    var kind: KeywordReferenceSourceKind
    var corpusID: String
    var corpusSetID: String
    var importedListText: String
    var importedListSourceName: String?
    var importedListImportedAt: String?

    static let empty = KeywordReferenceSource(
        kind: .singleCorpus,
        corpusID: "",
        corpusSetID: "",
        importedListText: "",
        importedListSourceName: nil,
        importedListImportedAt: nil
    )

    init(
        kind: KeywordReferenceSourceKind = .singleCorpus,
        corpusID: String = "",
        corpusSetID: String = "",
        importedListText: String = "",
        importedListSourceName: String? = nil,
        importedListImportedAt: String? = nil
    ) {
        self.kind = kind
        self.corpusID = corpusID
        self.corpusSetID = corpusSetID
        self.importedListText = importedListText
        self.importedListSourceName = importedListSourceName
        self.importedListImportedAt = importedListImportedAt
    }
}

enum KeywordUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalizedSurface
    case lemmaPreferred

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .normalizedSurface:
            return wordZText("规范词", "Normalized Surface", mode: mode)
        case .lemmaPreferred:
            return wordZText("词形优先", "Lemma Preferred", mode: mode)
        }
    }

    var lemmaStrategy: TokenLemmaStrategy {
        switch self {
        case .normalizedSurface:
            return .normalizedSurface
        case .lemmaPreferred:
            return .lemmaPreferred
        }
    }
}

enum KeywordDirection: String, CaseIterable, Identifiable, Codable, Sendable {
    case positive
    case negative
    case both

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .positive:
            return wordZText("正关键词", "Positive", mode: mode)
        case .negative:
            return wordZText("负关键词", "Negative", mode: mode)
        case .both:
            return wordZText("双向", "Both", mode: mode)
        }
    }
}

struct KeywordThresholds: Equatable, Codable, Sendable {
    var minFocusFreq: Int
    var minReferenceFreq: Int
    var minCombinedFreq: Int
    var maxPValue: Double
    var minAbsLogRatio: Double

    static let `default` = KeywordThresholds(
        minFocusFreq: 2,
        minReferenceFreq: 0,
        minCombinedFreq: 2,
        maxPValue: 1,
        minAbsLogRatio: 0
    )
}

struct KeywordTokenFilterState: Equatable, Codable, Sendable {
    var languagePreset: TokenizeLanguagePreset
    var lemmaStrategy: TokenLemmaStrategy
    var scripts: [TokenScript]
    var lexicalClasses: [TokenLexicalClass]
    var stopwordFilter: StopwordFilterState

    static let `default` = KeywordTokenFilterState(
        languagePreset: .mixedChineseEnglish,
        lemmaStrategy: .normalizedSurface,
        scripts: [],
        lexicalClasses: [],
        stopwordFilter: .default
    )

    var scriptFilterSet: Set<TokenScript> { Set(scripts) }
    var lexicalClassFilterSet: Set<TokenLexicalClass> { Set(lexicalClasses) }
}

struct KeywordSuiteConfiguration: Equatable, Codable, Sendable {
    var focusSelection: KeywordTargetSelection
    var referenceSource: KeywordReferenceSource
    var unit: KeywordUnit
    var direction: KeywordDirection
    var statistic: KeywordStatisticMethod
    var thresholds: KeywordThresholds
    var tokenFilters: KeywordTokenFilterState

    static let `default` = KeywordSuiteConfiguration(
        focusSelection: .empty,
        referenceSource: .empty,
        unit: .normalizedSurface,
        direction: .positive,
        statistic: .logLikelihood,
        thresholds: .default,
        tokenFilters: .default
    )
}

enum KeywordResultGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case words
    case terms
    case ngrams

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .words:
            return wordZText("词", "Words", mode: mode)
        case .terms:
            return wordZText("术语", "Terms", mode: mode)
        case .ngrams:
            return wordZText("N-grams", "N-grams", mode: mode)
        }
    }
}

enum KeywordRowDirection: String, CaseIterable, Identifiable, Codable, Sendable {
    case positive
    case negative

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .positive:
            return wordZText("正关键词", "Positive", mode: mode)
        case .negative:
            return wordZText("负关键词", "Negative", mode: mode)
        }
    }
}

struct KeywordReferenceWordListItem: Identifiable, Equatable, Codable, Sendable {
    let term: String
    let frequency: Int

    var id: String { term }
}

struct KeywordImportedReferenceParseResult: Equatable, Sendable {
    let items: [KeywordReferenceWordListItem]
    let totalLineCount: Int
    let acceptedLineCount: Int
    let rejectedLineCount: Int

    static let empty = KeywordImportedReferenceParseResult(
        items: [],
        totalLineCount: 0,
        acceptedLineCount: 0,
        rejectedLineCount: 0
    )

    var acceptedItemCount: Int { items.count }
    var hasAcceptedItems: Bool { !items.isEmpty }
}

struct KeywordSuiteRunRequest: Equatable, Sendable {
    let focusEntries: [KeywordRequestEntry]
    let referenceEntries: [KeywordRequestEntry]
    let importedReferenceItems: [KeywordReferenceWordListItem]
    let focusLabel: String
    let referenceLabel: String
    let configuration: KeywordSuiteConfiguration
}

struct KeywordSuiteScopeSummary: Equatable, Codable, Sendable {
    let label: String
    let corpusCount: Int
    let corpusIDs: [String]
    let corpusNames: [String]
    let tokenCount: Int
    let typeCount: Int
    let isWordList: Bool
}

struct KeywordSuiteRow: Identifiable, Equatable, Codable, Sendable {
    let group: KeywordResultGroup
    let item: String
    let direction: KeywordRowDirection
    let focusFrequency: Int
    let referenceFrequency: Int
    let focusNormalizedFrequency: Double
    let referenceNormalizedFrequency: Double
    let keynessScore: Double
    let logRatio: Double
    let pValue: Double
    let focusRange: Int
    let referenceRange: Int
    let example: String
    let focusExampleCorpusID: String?
    let referenceExampleCorpusID: String?

    var id: String {
        [group.rawValue, item, direction.rawValue].joined(separator: "::")
    }
}

struct KeywordSuiteResult: Equatable, Codable, Sendable {
    let configuration: KeywordSuiteConfiguration
    let focusSummary: KeywordSuiteScopeSummary
    let referenceSummary: KeywordSuiteScopeSummary
    let words: [KeywordSuiteRow]
    let terms: [KeywordSuiteRow]
    let ngrams: [KeywordSuiteRow]

    func rows(for group: KeywordResultGroup) -> [KeywordSuiteRow] {
        switch group {
        case .words:
            return words
        case .terms:
            return terms
        case .ngrams:
            return ngrams
        }
    }
}

enum KeywordSavedListViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case pairwiseDiff
    case keywordDatabase

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .pairwiseDiff:
            return wordZText("词表对比", "Pairwise Diff", mode: mode)
        case .keywordDatabase:
            return wordZText("关键词数据库", "Keyword Database", mode: mode)
        }
    }
}

struct KeywordSavedList: Identifiable, Equatable, Codable, Sendable {
    let id: String
    var name: String
    let group: KeywordResultGroup
    let createdAt: String
    var updatedAt: String
    let focusLabel: String
    let referenceLabel: String
    let configuration: KeywordSuiteConfiguration
    let rows: [KeywordSuiteRow]
}

struct KeywordSavedListDiffRow: Identifiable, Equatable, Sendable {
    enum DiffStatus: String, CaseIterable, Identifiable, Sendable {
        case onlyLeft
        case onlyRight
        case shared

        var id: String { rawValue }
    }

    let item: String
    let status: DiffStatus
    let leftRank: Int?
    let rightRank: Int?
    let meanLogRatioDelta: Double

    var id: String { item }
}

struct KeywordDatabaseRow: Identifiable, Equatable, Sendable {
    let item: String
    let coverageCount: Int
    let coverageRate: Double
    let meanKeyness: Double
    let meanAbsLogRatio: Double
    let lastSeenAt: String

    var id: String { item }
}

extension KeywordSuiteConfiguration {
    init(json: JSONObject) {
        guard JSONSerialization.isValidJSONObject(json),
              let data = try? JSONSerialization.data(withJSONObject: json),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            self = .default
            return
        }
        self = decoded
    }

    var jsonObject: JSONObject {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject else {
            return [:]
        }
        return object
    }

    static func legacy(
        targetCorpusID: String,
        referenceCorpusID: String,
        options: KeywordPreprocessingOptions
    ) -> Self {
        KeywordSuiteConfiguration(
            focusSelection: KeywordTargetSelection(kind: .singleCorpus, corpusIDs: [targetCorpusID]),
            referenceSource: KeywordReferenceSource(kind: .singleCorpus, corpusID: referenceCorpusID),
            unit: .normalizedSurface,
            direction: .positive,
            statistic: options.statistic,
            thresholds: KeywordThresholds(
                minFocusFreq: max(1, options.minimumFrequency),
                minReferenceFreq: 0,
                minCombinedFreq: max(1, options.minimumFrequency),
                maxPValue: 1,
                minAbsLogRatio: 0
            ),
            tokenFilters: KeywordTokenFilterState(
                languagePreset: .mixedChineseEnglish,
                lemmaStrategy: .normalizedSurface,
                scripts: [],
                lexicalClasses: [],
                stopwordFilter: options.stopwordFilter
            )
        )
    }
}

extension KeywordResult {
    init(suiteResult: KeywordSuiteResult) {
        let rows = suiteResult.words.enumerated().map { index, row in
            KeywordResultRow(
                word: row.item,
                rank: index + 1,
                targetFrequency: row.focusFrequency,
                referenceFrequency: row.referenceFrequency,
                targetNormalizedFrequency: row.focusNormalizedFrequency,
                referenceNormalizedFrequency: row.referenceNormalizedFrequency,
                keynessScore: row.keynessScore,
                logRatio: row.logRatio,
                pValue: row.pValue
            )
        }
        self.init(
            statistic: suiteResult.configuration.statistic,
            targetCorpus: KeywordCorpusSummary(
                corpusId: suiteResult.focusSummary.corpusIDs.first ?? "",
                corpusName: suiteResult.focusSummary.label,
                folderName: "",
                tokenCount: suiteResult.focusSummary.tokenCount,
                typeCount: suiteResult.focusSummary.typeCount
            ),
            referenceCorpus: KeywordCorpusSummary(
                corpusId: suiteResult.referenceSummary.corpusIDs.first ?? "",
                corpusName: suiteResult.referenceSummary.label,
                folderName: "",
                tokenCount: suiteResult.referenceSummary.tokenCount,
                typeCount: suiteResult.referenceSummary.typeCount
            ),
            rows: rows
        )
    }
}
