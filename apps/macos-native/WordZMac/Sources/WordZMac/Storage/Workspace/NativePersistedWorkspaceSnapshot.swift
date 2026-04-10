import Foundation

struct NativePersistedWorkspaceSnapshot: Codable, Equatable {
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

    private enum CodingKeys: String, CodingKey {
        case currentTab
        case currentLibraryFolderId
        case selectedCorpusSetID
        case corpusIds
        case corpusNames
        case searchQuery
        case searchOptions
        case stopwordFilter
        case tokenizeLanguagePreset
        case tokenizeLemmaStrategy
        case compareReferenceCorpusID
        case compareSelectedCorpusIDs
        case keywordTargetCorpusID
        case keywordReferenceCorpusID
        case keywordLowercased
        case keywordRemovePunctuation
        case keywordMinimumFrequency
        case keywordStatistic
        case keywordStopwordFilter
        case ngramSize
        case ngramPageSize
        case kwicLeftWindow
        case kwicRightWindow
        case collocateLeftWindow
        case collocateRightWindow
        case collocateMinFreq
        case topicsMinTopicSize
        case topicsIncludeOutliers
        case topicsPageSize
        case topicsActiveTopicID
        case frequencyNormalizationUnit
        case frequencyRangeMode
        case chiSquareA
        case chiSquareB
        case chiSquareC
        case chiSquareD
        case chiSquareUseYates
    }

    static let empty = NativePersistedWorkspaceSnapshot(draft: .empty)

    init(
        currentTab: String,
        currentLibraryFolderId: String,
        selectedCorpusSetID: String,
        corpusIds: [String],
        corpusNames: [String],
        searchQuery: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        tokenizeLanguagePreset: TokenizeLanguagePreset,
        tokenizeLemmaStrategy: TokenLemmaStrategy,
        compareReferenceCorpusID: String,
        compareSelectedCorpusIDs: [String],
        keywordTargetCorpusID: String,
        keywordReferenceCorpusID: String,
        keywordLowercased: Bool,
        keywordRemovePunctuation: Bool,
        keywordMinimumFrequency: String,
        keywordStatistic: KeywordStatisticMethod,
        keywordStopwordFilter: StopwordFilterState,
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentTab = try container.decodeIfPresent(String.self, forKey: .currentTab) ?? "stats"
        self.currentLibraryFolderId = try container.decodeIfPresent(String.self, forKey: .currentLibraryFolderId) ?? "all"
        self.selectedCorpusSetID = try container.decodeIfPresent(String.self, forKey: .selectedCorpusSetID) ?? ""
        self.corpusIds = try container.decodeIfPresent([String].self, forKey: .corpusIds) ?? []
        self.corpusNames = try container.decodeIfPresent([String].self, forKey: .corpusNames) ?? []
        self.searchQuery = try container.decodeIfPresent(String.self, forKey: .searchQuery) ?? ""
        self.searchOptions = try container.decodeIfPresent(SearchOptionsState.self, forKey: .searchOptions) ?? .default
        self.stopwordFilter = try container.decodeIfPresent(StopwordFilterState.self, forKey: .stopwordFilter) ?? .default
        self.tokenizeLanguagePreset = try container.decodeIfPresent(TokenizeLanguagePreset.self, forKey: .tokenizeLanguagePreset) ?? .mixedChineseEnglish
        self.tokenizeLemmaStrategy = try container.decodeIfPresent(TokenLemmaStrategy.self, forKey: .tokenizeLemmaStrategy) ?? .normalizedSurface
        self.compareReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .compareReferenceCorpusID) ?? ""
        self.compareSelectedCorpusIDs = try container.decodeIfPresent([String].self, forKey: .compareSelectedCorpusIDs) ?? []
        self.keywordTargetCorpusID = try container.decodeIfPresent(String.self, forKey: .keywordTargetCorpusID) ?? ""
        self.keywordReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .keywordReferenceCorpusID) ?? ""
        self.keywordLowercased = try container.decodeIfPresent(Bool.self, forKey: .keywordLowercased) ?? true
        self.keywordRemovePunctuation = try container.decodeIfPresent(Bool.self, forKey: .keywordRemovePunctuation) ?? true
        self.keywordMinimumFrequency = try container.decodeIfPresent(String.self, forKey: .keywordMinimumFrequency) ?? "2"
        self.keywordStatistic = try container.decodeIfPresent(KeywordStatisticMethod.self, forKey: .keywordStatistic) ?? .logLikelihood
        self.keywordStopwordFilter = try container.decodeIfPresent(StopwordFilterState.self, forKey: .keywordStopwordFilter) ?? .default
        self.ngramSize = try container.decodeIfPresent(String.self, forKey: .ngramSize) ?? "2"
        self.ngramPageSize = try container.decodeIfPresent(String.self, forKey: .ngramPageSize) ?? "10"
        self.kwicLeftWindow = try container.decodeIfPresent(String.self, forKey: .kwicLeftWindow) ?? "5"
        self.kwicRightWindow = try container.decodeIfPresent(String.self, forKey: .kwicRightWindow) ?? "5"
        self.collocateLeftWindow = try container.decodeIfPresent(String.self, forKey: .collocateLeftWindow) ?? "5"
        self.collocateRightWindow = try container.decodeIfPresent(String.self, forKey: .collocateRightWindow) ?? "5"
        self.collocateMinFreq = try container.decodeIfPresent(String.self, forKey: .collocateMinFreq) ?? "1"
        self.topicsMinTopicSize = try container.decodeIfPresent(String.self, forKey: .topicsMinTopicSize) ?? "2"
        self.topicsIncludeOutliers = try container.decodeIfPresent(Bool.self, forKey: .topicsIncludeOutliers) ?? true
        self.topicsPageSize = try container.decodeIfPresent(String.self, forKey: .topicsPageSize) ?? "50"
        self.topicsActiveTopicID = try container.decodeIfPresent(String.self, forKey: .topicsActiveTopicID) ?? ""
        self.frequencyNormalizationUnit = try container.decodeIfPresent(FrequencyNormalizationUnit.self, forKey: .frequencyNormalizationUnit) ?? FrequencyMetricDefinition.default.normalizationUnit
        self.frequencyRangeMode = try container.decodeIfPresent(FrequencyRangeMode.self, forKey: .frequencyRangeMode) ?? FrequencyMetricDefinition.default.rangeMode
        self.chiSquareA = try container.decodeIfPresent(String.self, forKey: .chiSquareA) ?? ""
        self.chiSquareB = try container.decodeIfPresent(String.self, forKey: .chiSquareB) ?? ""
        self.chiSquareC = try container.decodeIfPresent(String.self, forKey: .chiSquareC) ?? ""
        self.chiSquareD = try container.decodeIfPresent(String.self, forKey: .chiSquareD) ?? ""
        self.chiSquareUseYates = try container.decodeIfPresent(Bool.self, forKey: .chiSquareUseYates) ?? false
    }

    var workspaceSnapshot: WorkspaceSnapshotSummary {
        workspaceDraft.snapshotSummary
    }

    private var workspaceDraft: WorkspaceStateDraft {
        WorkspaceStateDraft(
            currentTab: currentTab,
            currentLibraryFolderId: currentLibraryFolderId,
            selectedCorpusSetID: selectedCorpusSetID,
            corpusIds: corpusIds,
            corpusNames: corpusNames,
            searchQuery: searchQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            tokenizeLanguagePreset: tokenizeLanguagePreset,
            tokenizeLemmaStrategy: tokenizeLemmaStrategy,
            compareReferenceCorpusID: compareReferenceCorpusID,
            compareSelectedCorpusIDs: compareSelectedCorpusIDs,
            keywordTargetCorpusID: keywordTargetCorpusID,
            keywordReferenceCorpusID: keywordReferenceCorpusID,
            keywordLowercased: keywordLowercased,
            keywordRemovePunctuation: keywordRemovePunctuation,
            keywordMinimumFrequency: keywordMinimumFrequency,
            keywordStatistic: keywordStatistic,
            keywordStopwordFilter: keywordStopwordFilter,
            ngramSize: ngramSize,
            ngramPageSize: ngramPageSize,
            kwicLeftWindow: kwicLeftWindow,
            kwicRightWindow: kwicRightWindow,
            collocateLeftWindow: collocateLeftWindow,
            collocateRightWindow: collocateRightWindow,
            collocateMinFreq: collocateMinFreq,
            topicsMinTopicSize: topicsMinTopicSize,
            topicsIncludeOutliers: topicsIncludeOutliers,
            topicsPageSize: topicsPageSize,
            topicsActiveTopicID: topicsActiveTopicID,
            frequencyNormalizationUnit: frequencyNormalizationUnit,
            frequencyRangeMode: frequencyRangeMode,
            chiSquareA: chiSquareA,
            chiSquareB: chiSquareB,
            chiSquareC: chiSquareC,
            chiSquareD: chiSquareD,
            chiSquareUseYates: chiSquareUseYates
        )
    }
}
