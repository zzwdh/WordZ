import Foundation

struct WorkspaceSnapshotSummary: Equatable, Sendable {
    let currentTab: String
    let currentLibraryFolderId: String
    let selectedCorpusSetID: String
    let corpusIds: [String]
    let corpusNames: [String]
    let searchQuery: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let tokenizeLanguagePreset: TokenizeLanguagePreset
    let tokenizeLemmaStrategy: TokenLemmaStrategy
    let compareReferenceCorpusID: String
    let compareSelectedCorpusIDs: [String]
    let keywordTargetCorpusID: String
    let keywordReferenceCorpusID: String
    let keywordLowercased: Bool
    let keywordRemovePunctuation: Bool
    let keywordMinimumFrequency: String
    let keywordStatistic: KeywordStatisticMethod
    let keywordStopwordFilter: StopwordFilterState
    let ngramSize: String
    let ngramPageSize: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String
    let topicsMinTopicSize: String
    let topicsIncludeOutliers: Bool
    let topicsPageSize: String
    let topicsActiveTopicID: String
    let frequencyNormalizationUnit: FrequencyNormalizationUnit
    let frequencyRangeMode: FrequencyRangeMode
    let chiSquareA: String
    let chiSquareB: String
    let chiSquareC: String
    let chiSquareD: String
    let chiSquareUseYates: Bool

    static let empty = WorkspaceSnapshotSummary(draft: WorkspaceStateDraft.empty)

    init(
        currentTab: String,
        currentLibraryFolderId: String,
        selectedCorpusSetID: String = "",
        corpusIds: [String],
        corpusNames: [String],
        searchQuery: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        tokenizeLanguagePreset: TokenizeLanguagePreset = .mixedChineseEnglish,
        tokenizeLemmaStrategy: TokenLemmaStrategy = .normalizedSurface,
        compareReferenceCorpusID: String = "",
        compareSelectedCorpusIDs: [String] = [],
        keywordTargetCorpusID: String = "",
        keywordReferenceCorpusID: String = "",
        keywordLowercased: Bool = true,
        keywordRemovePunctuation: Bool = true,
        keywordMinimumFrequency: String = "2",
        keywordStatistic: KeywordStatisticMethod = .logLikelihood,
        keywordStopwordFilter: StopwordFilterState = .default,
        ngramSize: String,
        ngramPageSize: String,
        kwicLeftWindow: String,
        kwicRightWindow: String,
        collocateLeftWindow: String,
        collocateRightWindow: String,
        collocateMinFreq: String,
        topicsMinTopicSize: String,
        topicsIncludeOutliers: Bool,
        topicsPageSize: String,
        topicsActiveTopicID: String,
        frequencyNormalizationUnit: FrequencyNormalizationUnit,
        frequencyRangeMode: FrequencyRangeMode,
        chiSquareA: String,
        chiSquareB: String,
        chiSquareC: String,
        chiSquareD: String,
        chiSquareUseYates: Bool
    ) {
        self.currentTab = currentTab
        self.currentLibraryFolderId = currentLibraryFolderId
        self.selectedCorpusSetID = selectedCorpusSetID
        self.corpusIds = corpusIds
        self.corpusNames = corpusNames
        self.searchQuery = searchQuery
        self.searchOptions = searchOptions
        self.stopwordFilter = stopwordFilter
        self.tokenizeLanguagePreset = tokenizeLanguagePreset
        self.tokenizeLemmaStrategy = tokenizeLemmaStrategy
        self.compareReferenceCorpusID = compareReferenceCorpusID
        self.compareSelectedCorpusIDs = compareSelectedCorpusIDs
        self.keywordTargetCorpusID = keywordTargetCorpusID
        self.keywordReferenceCorpusID = keywordReferenceCorpusID
        self.keywordLowercased = keywordLowercased
        self.keywordRemovePunctuation = keywordRemovePunctuation
        self.keywordMinimumFrequency = keywordMinimumFrequency
        self.keywordStatistic = keywordStatistic
        self.keywordStopwordFilter = keywordStopwordFilter
        self.ngramSize = ngramSize
        self.ngramPageSize = ngramPageSize
        self.kwicLeftWindow = kwicLeftWindow
        self.kwicRightWindow = kwicRightWindow
        self.collocateLeftWindow = collocateLeftWindow
        self.collocateRightWindow = collocateRightWindow
        self.collocateMinFreq = collocateMinFreq
        self.topicsMinTopicSize = topicsMinTopicSize
        self.topicsIncludeOutliers = topicsIncludeOutliers
        self.topicsPageSize = topicsPageSize
        self.topicsActiveTopicID = topicsActiveTopicID
        self.frequencyNormalizationUnit = frequencyNormalizationUnit
        self.frequencyRangeMode = frequencyRangeMode
        self.chiSquareA = chiSquareA
        self.chiSquareB = chiSquareB
        self.chiSquareC = chiSquareC
        self.chiSquareD = chiSquareD
        self.chiSquareUseYates = chiSquareUseYates
    }

    init(json: JSONObject) {
        self.currentTab = JSONFieldReader.string(json, key: "currentTab", fallback: "stats")
        self.currentLibraryFolderId = JSONFieldReader.string(json, key: "currentLibraryFolderId", fallback: "all")
        let workspace = JSONFieldReader.dictionary(json, key: "workspace")
        self.selectedCorpusSetID = JSONFieldReader.string(workspace, key: "selectedCorpusSetID")
        self.corpusIds = (workspace["corpusIds"] as? [String]) ?? []
        self.corpusNames = (workspace["corpusNames"] as? [String]) ?? []
        let search = JSONFieldReader.dictionary(json, key: "search")
        self.searchQuery = JSONFieldReader.string(search, key: "query")
        self.searchOptions = SearchOptionsState(json: JSONFieldReader.dictionary(search, key: "options"))
        self.stopwordFilter = StopwordFilterState(json: JSONFieldReader.dictionary(search, key: "stopwordFilter"))
        let tokenize = JSONFieldReader.dictionary(json, key: "tokenize")
        self.tokenizeLanguagePreset = TokenizeLanguagePreset(
            rawValue: JSONFieldReader.string(tokenize, key: "languagePreset", fallback: TokenizeLanguagePreset.mixedChineseEnglish.rawValue)
        ) ?? .mixedChineseEnglish
        self.tokenizeLemmaStrategy = TokenLemmaStrategy(
            rawValue: JSONFieldReader.string(tokenize, key: "lemmaStrategy", fallback: TokenLemmaStrategy.normalizedSurface.rawValue)
        ) ?? .normalizedSurface
        let compare = JSONFieldReader.dictionary(json, key: "compare")
        self.compareReferenceCorpusID = JSONFieldReader.string(compare, key: "referenceCorpusID")
        self.compareSelectedCorpusIDs = JSONFieldReader.array(compare, key: "selectedCorpusIDs").compactMap { $0 as? String }
        let keyword = JSONFieldReader.dictionary(json, key: "keyword")
        self.keywordTargetCorpusID = JSONFieldReader.string(keyword, key: "targetCorpusID")
        self.keywordReferenceCorpusID = JSONFieldReader.string(keyword, key: "referenceCorpusID")
        self.keywordLowercased = JSONFieldReader.bool(keyword, key: "lowercased", fallback: true)
        self.keywordRemovePunctuation = JSONFieldReader.bool(keyword, key: "removePunctuation", fallback: true)
        self.keywordMinimumFrequency = JSONFieldReader.string(keyword, key: "minimumFrequency", fallback: "2")
        self.keywordStatistic = KeywordStatisticMethod(
            rawValue: JSONFieldReader.string(keyword, key: "statistic", fallback: KeywordStatisticMethod.logLikelihood.rawValue)
        ) ?? .logLikelihood
        self.keywordStopwordFilter = StopwordFilterState(json: JSONFieldReader.dictionary(keyword, key: "stopwordFilter"))
        let ngram = JSONFieldReader.dictionary(json, key: "ngram")
        self.ngramSize = JSONFieldReader.string(ngram, key: "size", fallback: "2")
        self.ngramPageSize = JSONFieldReader.string(ngram, key: "pageSize", fallback: "10")
        let kwic = JSONFieldReader.dictionary(json, key: "kwic")
        self.kwicLeftWindow = JSONFieldReader.string(kwic, key: "leftWindow", fallback: "5")
        self.kwicRightWindow = JSONFieldReader.string(kwic, key: "rightWindow", fallback: "5")
        let collocate = JSONFieldReader.dictionary(json, key: "collocate")
        self.collocateLeftWindow = JSONFieldReader.string(collocate, key: "leftWindow", fallback: "5")
        self.collocateRightWindow = JSONFieldReader.string(collocate, key: "rightWindow", fallback: "5")
        self.collocateMinFreq = JSONFieldReader.string(collocate, key: "minFreq", fallback: "1")
        let topics = JSONFieldReader.dictionary(json, key: "topics")
        self.topicsMinTopicSize = JSONFieldReader.string(topics, key: "minTopicSize", fallback: "2")
        self.topicsIncludeOutliers = JSONFieldReader.bool(topics, key: "includeOutliers", fallback: true)
        self.topicsPageSize = JSONFieldReader.string(topics, key: "pageSize", fallback: "50")
        self.topicsActiveTopicID = JSONFieldReader.string(topics, key: "activeTopicID")
        let frequencyMetrics = JSONFieldReader.dictionary(json, key: "frequencyMetrics")
        self.frequencyNormalizationUnit = FrequencyNormalizationUnit(
            rawValue: JSONFieldReader.string(frequencyMetrics, key: "normalizationUnit", fallback: FrequencyMetricDefinition.default.normalizationUnit.rawValue)
        ) ?? FrequencyMetricDefinition.default.normalizationUnit
        self.frequencyRangeMode = FrequencyRangeMode(
            rawValue: JSONFieldReader.string(frequencyMetrics, key: "rangeMode", fallback: FrequencyMetricDefinition.default.rangeMode.rawValue)
        ) ?? FrequencyMetricDefinition.default.rangeMode
        let chiSquare = JSONFieldReader.dictionary(json, key: "chiSquare")
        self.chiSquareA = JSONFieldReader.string(chiSquare, key: "a")
        self.chiSquareB = JSONFieldReader.string(chiSquare, key: "b")
        self.chiSquareC = JSONFieldReader.string(chiSquare, key: "c")
        self.chiSquareD = JSONFieldReader.string(chiSquare, key: "d")
        self.chiSquareUseYates = JSONFieldReader.bool(chiSquare, key: "useYates", fallback: false)
    }

    init(draft: WorkspaceStateDraft) {
        self.init(
            currentTab: draft.currentTab,
            currentLibraryFolderId: draft.currentLibraryFolderId,
            selectedCorpusSetID: draft.selectedCorpusSetID,
            corpusIds: draft.corpusIds,
            corpusNames: draft.corpusNames,
            searchQuery: draft.searchQuery,
            searchOptions: draft.searchOptions,
            stopwordFilter: draft.stopwordFilter,
            tokenizeLanguagePreset: draft.tokenizeLanguagePreset,
            tokenizeLemmaStrategy: draft.tokenizeLemmaStrategy,
            compareReferenceCorpusID: draft.compareReferenceCorpusID,
            compareSelectedCorpusIDs: draft.compareSelectedCorpusIDs,
            keywordTargetCorpusID: draft.keywordTargetCorpusID,
            keywordReferenceCorpusID: draft.keywordReferenceCorpusID,
            keywordLowercased: draft.keywordLowercased,
            keywordRemovePunctuation: draft.keywordRemovePunctuation,
            keywordMinimumFrequency: draft.keywordMinimumFrequency,
            keywordStatistic: draft.keywordStatistic,
            keywordStopwordFilter: draft.keywordStopwordFilter,
            ngramSize: draft.ngramSize,
            ngramPageSize: draft.ngramPageSize,
            kwicLeftWindow: draft.kwicLeftWindow,
            kwicRightWindow: draft.kwicRightWindow,
            collocateLeftWindow: draft.collocateLeftWindow,
            collocateRightWindow: draft.collocateRightWindow,
            collocateMinFreq: draft.collocateMinFreq,
            topicsMinTopicSize: draft.topicsMinTopicSize,
            topicsIncludeOutliers: draft.topicsIncludeOutliers,
            topicsPageSize: draft.topicsPageSize,
            topicsActiveTopicID: draft.topicsActiveTopicID,
            frequencyNormalizationUnit: draft.frequencyNormalizationUnit,
            frequencyRangeMode: draft.frequencyRangeMode,
            chiSquareA: draft.chiSquareA,
            chiSquareB: draft.chiSquareB,
            chiSquareC: draft.chiSquareC,
            chiSquareD: draft.chiSquareD,
            chiSquareUseYates: draft.chiSquareUseYates
        )
    }
}
