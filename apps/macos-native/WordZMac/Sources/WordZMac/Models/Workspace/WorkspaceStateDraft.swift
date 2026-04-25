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

    static let empty = WorkspaceStateDraft(
        currentTab: "stats",
        currentLibraryFolderId: "all",
        selectedCorpusSetID: "",
        corpusIds: [],
        corpusNames: [],
        searchQuery: "",
        searchOptions: .default,
        stopwordFilter: .default,
        annotationProfile: .surface,
        annotationLexicalClasses: [],
        annotationScripts: [],
        tokenizeLanguagePreset: .mixedChineseEnglish,
        tokenizeLemmaStrategy: .normalizedSurface,
        compareReferenceCorpusID: "",
        compareSelectedCorpusIDs: [],
        sentimentSource: .openedCorpus,
        sentimentUnit: .sentence,
        sentimentContextBasis: .visibleContext,
        sentimentBackend: .lexicon,
        sentimentDomainPackID: .mixed,
        sentimentRuleProfileID: SentimentRuleProfile.default.id,
        sentimentCalibrationProfileID: SentimentCalibrationProfile.default.id,
        sentimentChartKind: .distributionBar,
        sentimentThresholdPreset: .conservative,
        sentimentDecisionThreshold: SentimentThresholds.default.decisionThreshold,
        sentimentMinimumEvidence: SentimentThresholds.default.minimumEvidence,
        sentimentNeutralBias: SentimentThresholds.default.neutralBias,
        sentimentRowFilterQuery: "",
        sentimentLabelFilter: nil,
        sentimentReviewFilter: .all,
        sentimentReviewStatusFilter: .all,
        sentimentShowOnlyHardCases: false,
        sentimentWorkspaceCalibrationProfile: .workspaceDefault,
        sentimentImportedLexiconBundles: [],
        sentimentSelectedCorpusIDs: [],
        sentimentReferenceCorpusID: "",
        keywordActiveTab: .words,
        keywordSuiteConfiguration: .default,
        keywordTargetCorpusID: "",
        keywordReferenceCorpusID: "",
        keywordLowercased: true,
        keywordRemovePunctuation: true,
        keywordMinimumFrequency: "2",
        keywordStatistic: .logLikelihood,
        keywordStopwordFilter: .default,
        plotQuery: "",
        plotSearchOptions: .default,
        ngramSize: "2",
        ngramPageSize: "10",
        clusterSelectedN: "3",
        clusterMinFrequency: "3",
        clusterSortMode: .frequencyDescending,
        clusterCaseSensitive: false,
        clusterStopwordFilter: .default,
        clusterPunctuationMode: .boundary,
        clusterSelectedPhrase: "",
        clusterPageSize: "100",
        clusterReferenceCorpusID: "",
        kwicLeftWindow: "5",
        kwicRightWindow: "5",
        collocateLeftWindow: "5",
        collocateRightWindow: "5",
        collocateMinFreq: "1",
        topicsMinTopicSize: "2",
        topicsKeywordDisplayCount: "5",
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
        annotationProfile: WorkspaceAnnotationProfile = .surface,
        annotationLexicalClasses: [TokenLexicalClass] = [],
        annotationScripts: [TokenScript] = [],
        tokenizeLanguagePreset: TokenizeLanguagePreset = .mixedChineseEnglish,
        tokenizeLemmaStrategy: TokenLemmaStrategy = .normalizedSurface,
        compareReferenceCorpusID: String = "",
        compareSelectedCorpusIDs: [String] = [],
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
        keywordActiveTab: KeywordSuiteTab = .words,
        keywordSuiteConfiguration: KeywordSuiteConfiguration = .default,
        keywordTargetCorpusID: String = "",
        keywordReferenceCorpusID: String = "",
        keywordLowercased: Bool = true,
        keywordRemovePunctuation: Bool = true,
        keywordMinimumFrequency: String = "2",
        keywordStatistic: KeywordStatisticMethod = .logLikelihood,
        keywordStopwordFilter: StopwordFilterState = .default,
        plotQuery: String = "",
        plotSearchOptions: SearchOptionsState = .default,
        ngramSize: String,
        ngramPageSize: String,
        clusterSelectedN: String = "3",
        clusterMinFrequency: String = "3",
        clusterSortMode: ClusterSortMode = .frequencyDescending,
        clusterCaseSensitive: Bool = false,
        clusterStopwordFilter: StopwordFilterState = .default,
        clusterPunctuationMode: ClusterPunctuationMode = .boundary,
        clusterSelectedPhrase: String = "",
        clusterPageSize: String = "100",
        clusterReferenceCorpusID: String = "",
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
            "annotation": [
                "profile": annotationProfile.rawValue,
                "lexicalClasses": annotationLexicalClasses.map(\.rawValue),
                "scripts": annotationScripts.map(\.rawValue)
            ],
            "tokenize": [
                "languagePreset": tokenizeLanguagePreset.rawValue,
                "lemmaStrategy": tokenizeLemmaStrategy.rawValue
            ],
            "compare": [
                "referenceCorpusID": compareReferenceCorpusID,
                "selectedCorpusIDs": compareSelectedCorpusIDs
            ],
            "sentiment": [
                "source": sentimentSource.rawValue,
                "unit": sentimentUnit.rawValue,
                "contextBasis": sentimentContextBasis.rawValue,
                "backend": sentimentBackend.rawValue,
                "chartKind": sentimentChartKind.rawValue,
                "thresholdPreset": sentimentThresholdPreset.rawValue,
                "calibrationProfileID": sentimentCalibrationProfileID,
                "workspaceCalibrationProfile": encodeSentimentCalibrationProfileToJSONObject(sentimentWorkspaceCalibrationProfile) as Any,
                "decisionThreshold": sentimentDecisionThreshold,
                "minimumEvidence": sentimentMinimumEvidence,
                "neutralBias": sentimentNeutralBias,
                "rowFilterQuery": sentimentRowFilterQuery,
                "labelFilter": sentimentLabelFilter?.rawValue as Any,
                "domainPackID": sentimentDomainPackID.rawValue,
                "ruleProfileID": sentimentRuleProfileID,
                "reviewFilter": sentimentReviewFilter.rawValue,
                "reviewStatusFilter": sentimentReviewStatusFilter.rawValue,
                "showOnlyHardCases": sentimentShowOnlyHardCases,
                "userLexiconBundles": encodeSentimentLexiconBundlesToJSONObject(sentimentImportedLexiconBundles),
                "selectedCorpusIDs": sentimentSelectedCorpusIDs,
                "referenceCorpusID": sentimentReferenceCorpusID
            ],
            "keyword": [
                "activeTab": keywordActiveTab.rawValue,
                "suiteConfiguration": keywordSuiteConfiguration.jsonObject,
                "targetCorpusID": keywordTargetCorpusID,
                "referenceCorpusID": keywordReferenceCorpusID,
                "lowercased": keywordLowercased,
                "removePunctuation": keywordRemovePunctuation,
                "minimumFrequency": keywordMinimumFrequency,
                "statistic": keywordStatistic.rawValue,
                "stopwordFilter": keywordStopwordFilter.asJSONObject()
            ],
            "plot": [
                "query": plotQuery,
                "options": plotSearchOptions.asJSONObject()
            ],
            "ngram": [
                "pageSize": ngramPageSize,
                "size": ngramSize
            ],
            "cluster": [
                "selectedN": clusterSelectedN,
                "minFrequency": clusterMinFrequency,
                "sortMode": clusterSortMode.rawValue,
                "caseSensitive": clusterCaseSensitive,
                "stopwordFilter": clusterStopwordFilter.asJSONObject(),
                "punctuationMode": clusterPunctuationMode.rawValue,
                "selectedPhrase": clusterSelectedPhrase,
                "pageSize": clusterPageSize,
                "referenceCorpusID": clusterReferenceCorpusID
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
                "keywordDisplayCount": topicsKeywordDisplayCount,
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

private func encodeSentimentLexiconBundlesToJSONObject(
    _ bundles: [SentimentUserLexiconBundle]
) -> [JSONObject] {
    bundles.compactMap { bundle in
        guard let data = try? JSONEncoder().encode(bundle),
              let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
        else {
            return nil
        }
        return object
    }
}

private func encodeSentimentCalibrationProfileToJSONObject(
    _ profile: SentimentCalibrationProfile
) -> JSONObject? {
    guard let data = try? JSONEncoder().encode(profile),
          let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
    else {
        return nil
    }
    return object
}
