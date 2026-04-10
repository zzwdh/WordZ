import Foundation

struct WorkspaceStateDraft: Equatable, Sendable {
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

    static let empty = WorkspaceStateDraft(
        currentTab: "stats",
        currentLibraryFolderId: "all",
        selectedCorpusSetID: "",
        corpusIds: [],
        corpusNames: [],
        searchQuery: "",
        searchOptions: .default,
        stopwordFilter: .default,
        tokenizeLanguagePreset: .mixedChineseEnglish,
        tokenizeLemmaStrategy: .normalizedSurface,
        compareReferenceCorpusID: "",
        compareSelectedCorpusIDs: [],
        keywordTargetCorpusID: "",
        keywordReferenceCorpusID: "",
        keywordLowercased: true,
        keywordRemovePunctuation: true,
        keywordMinimumFrequency: "2",
        keywordStatistic: .logLikelihood,
        keywordStopwordFilter: .default,
        ngramSize: "2",
        ngramPageSize: "10",
        kwicLeftWindow: "5",
        kwicRightWindow: "5",
        collocateLeftWindow: "5",
        collocateRightWindow: "5",
        collocateMinFreq: "1",
        topicsMinTopicSize: "2",
        topicsIncludeOutliers: true,
        topicsPageSize: "50",
        topicsActiveTopicID: "",
        frequencyNormalizationUnit: FrequencyMetricDefinition.default.normalizationUnit,
        frequencyRangeMode: FrequencyMetricDefinition.default.rangeMode,
        chiSquareA: "",
        chiSquareB: "",
        chiSquareC: "",
        chiSquareD: "",
        chiSquareUseYates: false
    )

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
        frequencyNormalizationUnit: FrequencyNormalizationUnit = FrequencyMetricDefinition.default.normalizationUnit,
        frequencyRangeMode: FrequencyRangeMode = FrequencyMetricDefinition.default.rangeMode,
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

    func asJSONObject() -> JSONObject {
        [
            "currentTab": currentTab,
            "currentLibraryFolderId": currentLibraryFolderId,
            "workspace": [
                "selectedCorpusSetID": selectedCorpusSetID,
                "corpusIds": corpusIds,
                "corpusNames": corpusNames
            ],
            "search": [
                "query": searchQuery,
                "options": searchOptions.asJSONObject(),
                "stopwordFilter": stopwordFilter.asJSONObject()
            ],
            "tokenize": [
                "languagePreset": tokenizeLanguagePreset.rawValue,
                "lemmaStrategy": tokenizeLemmaStrategy.rawValue
            ],
            "compare": [
                "referenceCorpusID": compareReferenceCorpusID,
                "selectedCorpusIDs": compareSelectedCorpusIDs
            ],
            "keyword": [
                "targetCorpusID": keywordTargetCorpusID,
                "referenceCorpusID": keywordReferenceCorpusID,
                "lowercased": keywordLowercased,
                "removePunctuation": keywordRemovePunctuation,
                "minimumFrequency": keywordMinimumFrequency,
                "statistic": keywordStatistic.rawValue,
                "stopwordFilter": keywordStopwordFilter.asJSONObject()
            ],
            "ngram": [
                "pageSize": ngramPageSize,
                "size": ngramSize
            ],
            "kwic": [
                "leftWindow": kwicLeftWindow,
                "rightWindow": kwicRightWindow,
                "pageSize": "10",
                "scope": "current",
                "sortMode": "original"
            ],
            "collocate": [
                "leftWindow": collocateLeftWindow,
                "rightWindow": collocateRightWindow,
                "minFreq": collocateMinFreq,
                "pageSize": "10"
            ],
            "topics": [
                "minTopicSize": topicsMinTopicSize,
                "includeOutliers": topicsIncludeOutliers,
                "pageSize": topicsPageSize,
                "activeTopicID": topicsActiveTopicID
            ],
            "frequencyMetrics": [
                "normalizationUnit": frequencyNormalizationUnit.rawValue,
                "rangeMode": frequencyRangeMode.rawValue
            ],
            "chiSquare": [
                "a": chiSquareA,
                "b": chiSquareB,
                "c": chiSquareC,
                "d": chiSquareD,
                "useYates": chiSquareUseYates
            ]
        ]
    }

    var snapshotSummary: WorkspaceSnapshotSummary {
        WorkspaceSnapshotSummary(draft: self)
    }
}
