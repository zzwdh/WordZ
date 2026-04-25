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
    let annotationProfile: WorkspaceAnnotationProfile
    let annotationLexicalClasses: [TokenLexicalClass]
    let annotationScripts: [TokenScript]
    let tokenizeLanguagePreset: TokenizeLanguagePreset
    let tokenizeLemmaStrategy: TokenLemmaStrategy
    let compareReferenceCorpusID: String
    let compareSelectedCorpusIDs: [String]
    let sentimentSource: SentimentInputSource
    let sentimentUnit: SentimentAnalysisUnit
    let sentimentContextBasis: SentimentContextBasis
    let sentimentBackend: SentimentBackendKind
    let sentimentDomainPackID: SentimentDomainPackID
    let sentimentRuleProfileID: String
    let sentimentCalibrationProfileID: String
    let sentimentChartKind: SentimentChartKind
    let sentimentThresholdPreset: SentimentThresholdPreset
    let sentimentDecisionThreshold: Double
    let sentimentMinimumEvidence: Double
    let sentimentNeutralBias: Double
    let sentimentRowFilterQuery: String
    let sentimentLabelFilter: SentimentLabel?
    let sentimentReviewFilter: SentimentReviewFilter
    let sentimentReviewStatusFilter: SentimentReviewStatusFilter
    let sentimentShowOnlyHardCases: Bool
    let sentimentWorkspaceCalibrationProfile: SentimentCalibrationProfile
    let sentimentImportedLexiconBundles: [SentimentUserLexiconBundle]
    let sentimentSelectedCorpusIDs: [String]
    let sentimentReferenceCorpusID: String
    let keywordActiveTab: KeywordSuiteTab
    let keywordSuiteConfiguration: KeywordSuiteConfiguration
    let keywordTargetCorpusID: String
    let keywordReferenceCorpusID: String
    let keywordLowercased: Bool
    let keywordRemovePunctuation: Bool
    let keywordMinimumFrequency: String
    let keywordStatistic: KeywordStatisticMethod
    let keywordStopwordFilter: StopwordFilterState
    let plotQuery: String
    let plotSearchOptions: SearchOptionsState
    let ngramSize: String
    let ngramPageSize: String
    let clusterSelectedN: String
    let clusterMinFrequency: String
    let clusterSortMode: ClusterSortMode
    let clusterCaseSensitive: Bool
    let clusterStopwordFilter: StopwordFilterState
    let clusterPunctuationMode: ClusterPunctuationMode
    let clusterSelectedPhrase: String
    let clusterPageSize: String
    let clusterReferenceCorpusID: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String
    let topicsMinTopicSize: String
    let topicsKeywordDisplayCount: String
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
        case annotationProfile
        case annotationLexicalClasses
        case annotationScripts
        case tokenizeLanguagePreset
        case tokenizeLemmaStrategy
        case compareReferenceCorpusID
        case compareSelectedCorpusIDs
        case sentimentSource
        case sentimentUnit
        case sentimentContextBasis
        case sentimentBackend
        case sentimentDomainPackID
        case sentimentRuleProfileID
        case sentimentCalibrationProfileID
        case sentimentChartKind
        case sentimentThresholdPreset
        case sentimentDecisionThreshold
        case sentimentMinimumEvidence
        case sentimentNeutralBias
        case sentimentRowFilterQuery
        case sentimentLabelFilter
        case sentimentReviewFilter
        case sentimentReviewStatusFilter
        case sentimentShowOnlyHardCases
        case sentimentWorkspaceCalibrationProfile
        case sentimentImportedLexiconBundles
        case sentimentSelectedCorpusIDs
        case sentimentReferenceCorpusID
        case keywordActiveTab
        case keywordSuiteConfiguration
        case keywordTargetCorpusID
        case keywordReferenceCorpusID
        case keywordLowercased
        case keywordRemovePunctuation
        case keywordMinimumFrequency
        case keywordStatistic
        case keywordStopwordFilter
        case plotQuery
        case plotSearchOptions
        case ngramSize
        case ngramPageSize
        case clusterSelectedN
        case clusterMinFrequency
        case clusterSortMode
        case clusterCaseSensitive
        case clusterStopwordFilter
        case clusterPunctuationMode
        case clusterSelectedPhrase
        case clusterPageSize
        case clusterReferenceCorpusID
        case kwicLeftWindow
        case kwicRightWindow
        case collocateLeftWindow
        case collocateRightWindow
        case collocateMinFreq
        case topicsMinTopicSize
        case topicsKeywordDisplayCount
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
        annotationProfile: WorkspaceAnnotationProfile = .surface,
        annotationLexicalClasses: [TokenLexicalClass] = [],
        annotationScripts: [TokenScript] = [],
        tokenizeLanguagePreset: TokenizeLanguagePreset,
        tokenizeLemmaStrategy: TokenLemmaStrategy,
        compareReferenceCorpusID: String,
        compareSelectedCorpusIDs: [String],
        sentimentSource: SentimentInputSource = .openedCorpus,
        sentimentUnit: SentimentAnalysisUnit = .sentence,
        sentimentContextBasis: SentimentContextBasis = .visibleContext,
        sentimentBackend: SentimentBackendKind = .lexicon,
        sentimentDomainPackID: SentimentDomainPackID = .mixed,
        sentimentRuleProfileID: String = SentimentRuleProfile.default.id,
        sentimentCalibrationProfileID: String = SentimentCalibrationProfile.default.id,
        sentimentChartKind: SentimentChartKind = .distributionBar,
        sentimentThresholdPreset: SentimentThresholdPreset = .conservative,
        sentimentDecisionThreshold: Double = SentimentThresholds.default.decisionThreshold,
        sentimentMinimumEvidence: Double = SentimentThresholds.default.minimumEvidence,
        sentimentNeutralBias: Double = SentimentThresholds.default.neutralBias,
        sentimentRowFilterQuery: String = "",
        sentimentLabelFilter: SentimentLabel? = nil,
        sentimentReviewFilter: SentimentReviewFilter = .all,
        sentimentReviewStatusFilter: SentimentReviewStatusFilter = .all,
        sentimentShowOnlyHardCases: Bool = false,
        sentimentWorkspaceCalibrationProfile: SentimentCalibrationProfile = .workspaceDefault,
        sentimentImportedLexiconBundles: [SentimentUserLexiconBundle] = [],
        sentimentSelectedCorpusIDs: [String] = [],
        sentimentReferenceCorpusID: String = "",
        keywordActiveTab: KeywordSuiteTab,
        keywordSuiteConfiguration: KeywordSuiteConfiguration,
        keywordTargetCorpusID: String,
        keywordReferenceCorpusID: String,
        keywordLowercased: Bool,
        keywordRemovePunctuation: Bool,
        keywordMinimumFrequency: String,
        keywordStatistic: KeywordStatisticMethod,
        keywordStopwordFilter: StopwordFilterState,
        plotQuery: String,
        plotSearchOptions: SearchOptionsState,
        ngramSize: String,
        ngramPageSize: String,
        clusterSelectedN: String,
        clusterMinFrequency: String,
        clusterSortMode: ClusterSortMode,
        clusterCaseSensitive: Bool,
        clusterStopwordFilter: StopwordFilterState,
        clusterPunctuationMode: ClusterPunctuationMode,
        clusterSelectedPhrase: String,
        clusterPageSize: String,
        clusterReferenceCorpusID: String,
        kwicLeftWindow: String,
        kwicRightWindow: String,
        collocateLeftWindow: String,
        collocateRightWindow: String,
        collocateMinFreq: String,
        topicsMinTopicSize: String,
        topicsKeywordDisplayCount: String = "5",
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
        self.annotationProfile = annotationProfile
        self.annotationLexicalClasses = annotationLexicalClasses
        self.annotationScripts = annotationScripts
        self.tokenizeLanguagePreset = tokenizeLanguagePreset
        self.tokenizeLemmaStrategy = tokenizeLemmaStrategy
        self.compareReferenceCorpusID = compareReferenceCorpusID
        self.compareSelectedCorpusIDs = compareSelectedCorpusIDs
        self.sentimentSource = sentimentSource
        self.sentimentUnit = sentimentUnit
        self.sentimentContextBasis = sentimentContextBasis
        self.sentimentBackend = sentimentBackend
        self.sentimentDomainPackID = sentimentDomainPackID
        self.sentimentRuleProfileID = sentimentRuleProfileID
        self.sentimentCalibrationProfileID = sentimentCalibrationProfileID
        self.sentimentChartKind = sentimentChartKind
        self.sentimentThresholdPreset = sentimentThresholdPreset
        self.sentimentDecisionThreshold = sentimentDecisionThreshold
        self.sentimentMinimumEvidence = sentimentMinimumEvidence
        self.sentimentNeutralBias = sentimentNeutralBias
        self.sentimentRowFilterQuery = sentimentRowFilterQuery
        self.sentimentLabelFilter = sentimentLabelFilter
        self.sentimentReviewFilter = sentimentReviewFilter
        self.sentimentReviewStatusFilter = sentimentReviewStatusFilter
        self.sentimentShowOnlyHardCases = sentimentShowOnlyHardCases
        self.sentimentWorkspaceCalibrationProfile = sentimentWorkspaceCalibrationProfile
        self.sentimentImportedLexiconBundles = sentimentImportedLexiconBundles
        self.sentimentSelectedCorpusIDs = sentimentSelectedCorpusIDs
        self.sentimentReferenceCorpusID = sentimentReferenceCorpusID
        self.keywordActiveTab = keywordActiveTab
        self.keywordSuiteConfiguration = keywordSuiteConfiguration
        self.keywordTargetCorpusID = keywordTargetCorpusID
        self.keywordReferenceCorpusID = keywordReferenceCorpusID
        self.keywordLowercased = keywordLowercased
        self.keywordRemovePunctuation = keywordRemovePunctuation
        self.keywordMinimumFrequency = keywordMinimumFrequency
        self.keywordStatistic = keywordStatistic
        self.keywordStopwordFilter = keywordStopwordFilter
        self.plotQuery = plotQuery
        self.plotSearchOptions = plotSearchOptions
        self.ngramSize = ngramSize
        self.ngramPageSize = ngramPageSize
        self.clusterSelectedN = clusterSelectedN
        self.clusterMinFrequency = clusterMinFrequency
        self.clusterSortMode = clusterSortMode
        self.clusterCaseSensitive = clusterCaseSensitive
        self.clusterStopwordFilter = clusterStopwordFilter
        self.clusterPunctuationMode = clusterPunctuationMode
        self.clusterSelectedPhrase = clusterSelectedPhrase
        self.clusterPageSize = clusterPageSize
        self.clusterReferenceCorpusID = clusterReferenceCorpusID
        self.kwicLeftWindow = kwicLeftWindow
        self.kwicRightWindow = kwicRightWindow
        self.collocateLeftWindow = collocateLeftWindow
        self.collocateRightWindow = collocateRightWindow
        self.collocateMinFreq = collocateMinFreq
        self.topicsMinTopicSize = topicsMinTopicSize
        self.topicsKeywordDisplayCount = topicsKeywordDisplayCount
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
            annotationProfile: draft.annotationProfile,
            annotationLexicalClasses: draft.annotationLexicalClasses,
            annotationScripts: draft.annotationScripts,
            tokenizeLanguagePreset: draft.tokenizeLanguagePreset,
            tokenizeLemmaStrategy: draft.tokenizeLemmaStrategy,
            compareReferenceCorpusID: draft.compareReferenceCorpusID,
            compareSelectedCorpusIDs: draft.compareSelectedCorpusIDs,
            sentimentSource: draft.sentimentSource,
            sentimentUnit: draft.sentimentUnit,
            sentimentContextBasis: draft.sentimentContextBasis,
            sentimentBackend: draft.sentimentBackend,
            sentimentDomainPackID: draft.sentimentDomainPackID,
            sentimentRuleProfileID: draft.sentimentRuleProfileID,
            sentimentCalibrationProfileID: draft.sentimentCalibrationProfileID,
            sentimentChartKind: draft.sentimentChartKind,
            sentimentThresholdPreset: draft.sentimentThresholdPreset,
            sentimentDecisionThreshold: draft.sentimentDecisionThreshold,
            sentimentMinimumEvidence: draft.sentimentMinimumEvidence,
            sentimentNeutralBias: draft.sentimentNeutralBias,
            sentimentRowFilterQuery: draft.sentimentRowFilterQuery,
            sentimentLabelFilter: draft.sentimentLabelFilter,
            sentimentReviewFilter: draft.sentimentReviewFilter,
            sentimentReviewStatusFilter: draft.sentimentReviewStatusFilter,
            sentimentShowOnlyHardCases: draft.sentimentShowOnlyHardCases,
            sentimentWorkspaceCalibrationProfile: draft.sentimentWorkspaceCalibrationProfile,
            sentimentImportedLexiconBundles: draft.sentimentImportedLexiconBundles,
            sentimentSelectedCorpusIDs: draft.sentimentSelectedCorpusIDs,
            sentimentReferenceCorpusID: draft.sentimentReferenceCorpusID,
            keywordActiveTab: draft.keywordActiveTab,
            keywordSuiteConfiguration: draft.keywordSuiteConfiguration,
            keywordTargetCorpusID: draft.keywordTargetCorpusID,
            keywordReferenceCorpusID: draft.keywordReferenceCorpusID,
            keywordLowercased: draft.keywordLowercased,
            keywordRemovePunctuation: draft.keywordRemovePunctuation,
            keywordMinimumFrequency: draft.keywordMinimumFrequency,
            keywordStatistic: draft.keywordStatistic,
            keywordStopwordFilter: draft.keywordStopwordFilter,
            plotQuery: draft.plotQuery,
            plotSearchOptions: draft.plotSearchOptions,
            ngramSize: draft.ngramSize,
            ngramPageSize: draft.ngramPageSize,
            clusterSelectedN: draft.clusterSelectedN,
            clusterMinFrequency: draft.clusterMinFrequency,
            clusterSortMode: draft.clusterSortMode,
            clusterCaseSensitive: draft.clusterCaseSensitive,
            clusterStopwordFilter: draft.clusterStopwordFilter,
            clusterPunctuationMode: draft.clusterPunctuationMode,
            clusterSelectedPhrase: draft.clusterSelectedPhrase,
            clusterPageSize: draft.clusterPageSize,
            clusterReferenceCorpusID: draft.clusterReferenceCorpusID,
            kwicLeftWindow: draft.kwicLeftWindow,
            kwicRightWindow: draft.kwicRightWindow,
            collocateLeftWindow: draft.collocateLeftWindow,
            collocateRightWindow: draft.collocateRightWindow,
            collocateMinFreq: draft.collocateMinFreq,
            topicsMinTopicSize: draft.topicsMinTopicSize,
            topicsKeywordDisplayCount: draft.topicsKeywordDisplayCount,
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
        self.annotationProfile = try container.decodeIfPresent(WorkspaceAnnotationProfile.self, forKey: .annotationProfile) ?? .surface
        self.annotationLexicalClasses = try container.decodeIfPresent([TokenLexicalClass].self, forKey: .annotationLexicalClasses) ?? []
        self.annotationScripts = try container.decodeIfPresent([TokenScript].self, forKey: .annotationScripts) ?? []
        self.tokenizeLanguagePreset = try container.decodeIfPresent(TokenizeLanguagePreset.self, forKey: .tokenizeLanguagePreset) ?? .mixedChineseEnglish
        self.tokenizeLemmaStrategy = try container.decodeIfPresent(TokenLemmaStrategy.self, forKey: .tokenizeLemmaStrategy) ?? .normalizedSurface
        self.compareReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .compareReferenceCorpusID) ?? ""
        self.compareSelectedCorpusIDs = try container.decodeIfPresent([String].self, forKey: .compareSelectedCorpusIDs) ?? []
        self.sentimentSource = try container.decodeIfPresent(SentimentInputSource.self, forKey: .sentimentSource) ?? .openedCorpus
        self.sentimentUnit = try container.decodeIfPresent(SentimentAnalysisUnit.self, forKey: .sentimentUnit) ?? .sentence
        self.sentimentContextBasis = try container.decodeIfPresent(SentimentContextBasis.self, forKey: .sentimentContextBasis) ?? .visibleContext
        self.sentimentBackend = try container.decodeIfPresent(SentimentBackendKind.self, forKey: .sentimentBackend) ?? .lexicon
        self.sentimentDomainPackID = try container.decodeIfPresent(SentimentDomainPackID.self, forKey: .sentimentDomainPackID) ?? .mixed
        self.sentimentRuleProfileID = try container.decodeIfPresent(String.self, forKey: .sentimentRuleProfileID) ?? SentimentRuleProfile.default.id
        self.sentimentCalibrationProfileID = try container.decodeIfPresent(String.self, forKey: .sentimentCalibrationProfileID) ?? SentimentCalibrationProfile.default.id
        self.sentimentChartKind = try container.decodeIfPresent(SentimentChartKind.self, forKey: .sentimentChartKind) ?? .distributionBar
        self.sentimentThresholdPreset = try container.decodeIfPresent(SentimentThresholdPreset.self, forKey: .sentimentThresholdPreset) ?? .conservative
        self.sentimentDecisionThreshold = try container.decodeIfPresent(Double.self, forKey: .sentimentDecisionThreshold) ?? SentimentThresholds.default.decisionThreshold
        self.sentimentMinimumEvidence = try container.decodeIfPresent(Double.self, forKey: .sentimentMinimumEvidence) ?? SentimentThresholds.default.minimumEvidence
        self.sentimentNeutralBias = try container.decodeIfPresent(Double.self, forKey: .sentimentNeutralBias) ?? SentimentThresholds.default.neutralBias
        self.sentimentRowFilterQuery = try container.decodeIfPresent(String.self, forKey: .sentimentRowFilterQuery) ?? ""
        self.sentimentLabelFilter = try container.decodeIfPresent(SentimentLabel.self, forKey: .sentimentLabelFilter)
        self.sentimentReviewFilter = try container.decodeIfPresent(SentimentReviewFilter.self, forKey: .sentimentReviewFilter) ?? .all
        self.sentimentReviewStatusFilter = try container.decodeIfPresent(SentimentReviewStatusFilter.self, forKey: .sentimentReviewStatusFilter) ?? .all
        self.sentimentShowOnlyHardCases = try container.decodeIfPresent(Bool.self, forKey: .sentimentShowOnlyHardCases) ?? false
        self.sentimentWorkspaceCalibrationProfile = try container.decodeIfPresent(SentimentCalibrationProfile.self, forKey: .sentimentWorkspaceCalibrationProfile) ?? .workspaceDefault
        self.sentimentImportedLexiconBundles = try container.decodeIfPresent([SentimentUserLexiconBundle].self, forKey: .sentimentImportedLexiconBundles) ?? []
        self.sentimentSelectedCorpusIDs = try container.decodeIfPresent([String].self, forKey: .sentimentSelectedCorpusIDs) ?? []
        self.sentimentReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .sentimentReferenceCorpusID) ?? ""
        self.keywordActiveTab = try container.decodeIfPresent(KeywordSuiteTab.self, forKey: .keywordActiveTab) ?? .words
        self.keywordTargetCorpusID = try container.decodeIfPresent(String.self, forKey: .keywordTargetCorpusID) ?? ""
        self.keywordReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .keywordReferenceCorpusID) ?? ""
        self.keywordLowercased = try container.decodeIfPresent(Bool.self, forKey: .keywordLowercased) ?? true
        self.keywordRemovePunctuation = try container.decodeIfPresent(Bool.self, forKey: .keywordRemovePunctuation) ?? true
        self.keywordMinimumFrequency = try container.decodeIfPresent(String.self, forKey: .keywordMinimumFrequency) ?? "2"
        self.keywordStatistic = try container.decodeIfPresent(KeywordStatisticMethod.self, forKey: .keywordStatistic) ?? .logLikelihood
        self.keywordStopwordFilter = try container.decodeIfPresent(StopwordFilterState.self, forKey: .keywordStopwordFilter) ?? .default
        self.keywordSuiteConfiguration = try container.decodeIfPresent(KeywordSuiteConfiguration.self, forKey: .keywordSuiteConfiguration)
            ?? .legacy(
                targetCorpusID: self.keywordTargetCorpusID,
                referenceCorpusID: self.keywordReferenceCorpusID,
                options: KeywordPreprocessingOptions(
                    lowercased: self.keywordLowercased,
                    removePunctuation: self.keywordRemovePunctuation,
                    stopwordFilter: self.keywordStopwordFilter,
                    minimumFrequency: Int(self.keywordMinimumFrequency) ?? 2,
                    statistic: self.keywordStatistic
                )
            )
        self.plotQuery = try container.decodeIfPresent(String.self, forKey: .plotQuery) ?? ""
        self.plotSearchOptions = try container.decodeIfPresent(SearchOptionsState.self, forKey: .plotSearchOptions) ?? .default
        self.ngramSize = try container.decodeIfPresent(String.self, forKey: .ngramSize) ?? "2"
        self.ngramPageSize = try container.decodeIfPresent(String.self, forKey: .ngramPageSize) ?? "10"
        self.clusterSelectedN = try container.decodeIfPresent(String.self, forKey: .clusterSelectedN) ?? "3"
        self.clusterMinFrequency = try container.decodeIfPresent(String.self, forKey: .clusterMinFrequency) ?? "3"
        self.clusterSortMode = try container.decodeIfPresent(ClusterSortMode.self, forKey: .clusterSortMode) ?? .frequencyDescending
        self.clusterCaseSensitive = try container.decodeIfPresent(Bool.self, forKey: .clusterCaseSensitive) ?? false
        self.clusterStopwordFilter = try container.decodeIfPresent(StopwordFilterState.self, forKey: .clusterStopwordFilter) ?? .default
        self.clusterPunctuationMode = try container.decodeIfPresent(ClusterPunctuationMode.self, forKey: .clusterPunctuationMode) ?? .boundary
        self.clusterSelectedPhrase = try container.decodeIfPresent(String.self, forKey: .clusterSelectedPhrase) ?? ""
        self.clusterPageSize = try container.decodeIfPresent(String.self, forKey: .clusterPageSize) ?? "100"
        self.clusterReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .clusterReferenceCorpusID) ?? ""
        self.kwicLeftWindow = try container.decodeIfPresent(String.self, forKey: .kwicLeftWindow) ?? "5"
        self.kwicRightWindow = try container.decodeIfPresent(String.self, forKey: .kwicRightWindow) ?? "5"
        self.collocateLeftWindow = try container.decodeIfPresent(String.self, forKey: .collocateLeftWindow) ?? "5"
        self.collocateRightWindow = try container.decodeIfPresent(String.self, forKey: .collocateRightWindow) ?? "5"
        self.collocateMinFreq = try container.decodeIfPresent(String.self, forKey: .collocateMinFreq) ?? "1"
        self.topicsMinTopicSize = try container.decodeIfPresent(String.self, forKey: .topicsMinTopicSize) ?? "2"
        self.topicsKeywordDisplayCount = try container.decodeIfPresent(String.self, forKey: .topicsKeywordDisplayCount) ?? "5"
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
            annotationProfile: annotationProfile,
            annotationLexicalClasses: annotationLexicalClasses,
            annotationScripts: annotationScripts,
            tokenizeLanguagePreset: tokenizeLanguagePreset,
            tokenizeLemmaStrategy: tokenizeLemmaStrategy,
            compareReferenceCorpusID: compareReferenceCorpusID,
            compareSelectedCorpusIDs: compareSelectedCorpusIDs,
            sentimentSource: sentimentSource,
            sentimentUnit: sentimentUnit,
            sentimentContextBasis: sentimentContextBasis,
            sentimentBackend: sentimentBackend,
            sentimentDomainPackID: sentimentDomainPackID,
            sentimentRuleProfileID: sentimentRuleProfileID,
            sentimentCalibrationProfileID: sentimentCalibrationProfileID,
            sentimentChartKind: sentimentChartKind,
            sentimentThresholdPreset: sentimentThresholdPreset,
            sentimentDecisionThreshold: sentimentDecisionThreshold,
            sentimentMinimumEvidence: sentimentMinimumEvidence,
            sentimentNeutralBias: sentimentNeutralBias,
            sentimentRowFilterQuery: sentimentRowFilterQuery,
            sentimentLabelFilter: sentimentLabelFilter,
            sentimentReviewFilter: sentimentReviewFilter,
            sentimentReviewStatusFilter: sentimentReviewStatusFilter,
            sentimentShowOnlyHardCases: sentimentShowOnlyHardCases,
            sentimentWorkspaceCalibrationProfile: sentimentWorkspaceCalibrationProfile,
            sentimentImportedLexiconBundles: sentimentImportedLexiconBundles,
            sentimentSelectedCorpusIDs: sentimentSelectedCorpusIDs,
            sentimentReferenceCorpusID: sentimentReferenceCorpusID,
            keywordActiveTab: keywordActiveTab,
            keywordSuiteConfiguration: keywordSuiteConfiguration,
            keywordTargetCorpusID: keywordTargetCorpusID,
            keywordReferenceCorpusID: keywordReferenceCorpusID,
            keywordLowercased: keywordLowercased,
            keywordRemovePunctuation: keywordRemovePunctuation,
            keywordMinimumFrequency: keywordMinimumFrequency,
            keywordStatistic: keywordStatistic,
            keywordStopwordFilter: keywordStopwordFilter,
            plotQuery: plotQuery,
            plotSearchOptions: plotSearchOptions,
            ngramSize: ngramSize,
            ngramPageSize: ngramPageSize,
            clusterSelectedN: clusterSelectedN,
            clusterMinFrequency: clusterMinFrequency,
            clusterSortMode: clusterSortMode,
            clusterCaseSensitive: clusterCaseSensitive,
            clusterStopwordFilter: clusterStopwordFilter,
            clusterPunctuationMode: clusterPunctuationMode,
            clusterSelectedPhrase: clusterSelectedPhrase,
            clusterPageSize: clusterPageSize,
            clusterReferenceCorpusID: clusterReferenceCorpusID,
            kwicLeftWindow: kwicLeftWindow,
            kwicRightWindow: kwicRightWindow,
            collocateLeftWindow: collocateLeftWindow,
            collocateRightWindow: collocateRightWindow,
            collocateMinFreq: collocateMinFreq,
            topicsMinTopicSize: topicsMinTopicSize,
            topicsKeywordDisplayCount: topicsKeywordDisplayCount,
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
