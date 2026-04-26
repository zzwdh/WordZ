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
    let evidenceReviewFilter: EvidenceReviewFilter
    let evidenceSourceFilter: EvidenceSourceFilter
    let evidenceSentimentFilter: EvidenceSentimentFilter
    let evidenceTagFilterQuery: String
    let evidenceCorpusFilterQuery: String
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
        evidenceReviewFilter: EvidenceReviewFilter = .all,
        evidenceSourceFilter: EvidenceSourceFilter = .all,
        evidenceSentimentFilter: EvidenceSentimentFilter = .all,
        evidenceTagFilterQuery: String = "",
        evidenceCorpusFilterQuery: String = "",
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
        self.evidenceReviewFilter = evidenceReviewFilter
        self.evidenceSourceFilter = evidenceSourceFilter
        self.evidenceSentimentFilter = evidenceSentimentFilter
        self.evidenceTagFilterQuery = evidenceTagFilterQuery
        self.evidenceCorpusFilterQuery = evidenceCorpusFilterQuery
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
        let annotation = JSONFieldReader.dictionary(json, key: "annotation")
        self.annotationProfile = WorkspaceAnnotationProfile(
            rawValue: JSONFieldReader.string(annotation, key: "profile", fallback: WorkspaceAnnotationProfile.surface.rawValue)
        ) ?? .surface
        self.annotationLexicalClasses = JSONFieldReader.array(annotation, key: "lexicalClasses")
            .compactMap { value in
                guard let rawValue = value as? String else { return nil }
                return TokenLexicalClass(rawValue: rawValue)
            }
        self.annotationScripts = JSONFieldReader.array(annotation, key: "scripts")
            .compactMap { value in
                guard let rawValue = value as? String else { return nil }
                return TokenScript(rawValue: rawValue)
            }
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
        let sentiment = JSONFieldReader.dictionary(json, key: "sentiment")
        self.sentimentSource = SentimentInputSource(
            rawValue: JSONFieldReader.string(sentiment, key: "source", fallback: SentimentInputSource.openedCorpus.rawValue)
        ) ?? .openedCorpus
        self.sentimentUnit = SentimentAnalysisUnit(
            rawValue: JSONFieldReader.string(sentiment, key: "unit", fallback: SentimentAnalysisUnit.sentence.rawValue)
        ) ?? .sentence
        self.sentimentContextBasis = SentimentContextBasis(
            rawValue: JSONFieldReader.string(sentiment, key: "contextBasis", fallback: SentimentContextBasis.visibleContext.rawValue)
        ) ?? .visibleContext
        self.sentimentBackend = SentimentBackendKind(
            rawValue: JSONFieldReader.string(sentiment, key: "backend", fallback: SentimentBackendKind.lexicon.rawValue)
        ) ?? .lexicon
        self.sentimentDomainPackID = SentimentDomainPackID(
            rawValue: JSONFieldReader.string(sentiment, key: "domainPackID", fallback: SentimentDomainPackID.mixed.rawValue)
        ) ?? .mixed
        self.sentimentRuleProfileID = JSONFieldReader.string(
            sentiment,
            key: "ruleProfileID",
            fallback: SentimentRuleProfile.default.id
        )
        self.sentimentCalibrationProfileID = JSONFieldReader.string(
            sentiment,
            key: "calibrationProfileID",
            fallback: SentimentCalibrationProfile.default.id
        )
        self.sentimentChartKind = SentimentChartKind(
            rawValue: JSONFieldReader.string(sentiment, key: "chartKind", fallback: SentimentChartKind.distributionBar.rawValue)
        ) ?? .distributionBar
        self.sentimentThresholdPreset = SentimentThresholdPreset(
            rawValue: JSONFieldReader.string(sentiment, key: "thresholdPreset", fallback: SentimentThresholdPreset.conservative.rawValue)
        ) ?? .conservative
        self.sentimentDecisionThreshold = JSONFieldReader.double(
            sentiment,
            key: "decisionThreshold",
            fallback: SentimentThresholds.default.decisionThreshold
        )
        self.sentimentMinimumEvidence = JSONFieldReader.double(
            sentiment,
            key: "minimumEvidence",
            fallback: SentimentThresholds.default.minimumEvidence
        )
        self.sentimentNeutralBias = JSONFieldReader.double(
            sentiment,
            key: "neutralBias",
            fallback: SentimentThresholds.default.neutralBias
        )
        self.sentimentRowFilterQuery = JSONFieldReader.string(sentiment, key: "rowFilterQuery")
        self.sentimentLabelFilter = SentimentLabel(
            rawValue: JSONFieldReader.string(sentiment, key: "labelFilter")
        )
        self.sentimentReviewFilter = SentimentReviewFilter(
            rawValue: JSONFieldReader.string(sentiment, key: "reviewFilter", fallback: SentimentReviewFilter.all.rawValue)
        ) ?? .all
        self.sentimentReviewStatusFilter = SentimentReviewStatusFilter(
            rawValue: JSONFieldReader.string(sentiment, key: "reviewStatusFilter", fallback: SentimentReviewStatusFilter.all.rawValue)
        ) ?? .all
        self.sentimentShowOnlyHardCases = JSONFieldReader.bool(sentiment, key: "showOnlyHardCases", fallback: false)
        self.sentimentWorkspaceCalibrationProfile = decodeSentimentCalibrationProfileFromJSONObject(
            JSONFieldReader.dictionary(sentiment, key: "workspaceCalibrationProfile")
        ) ?? .workspaceDefault
        self.sentimentImportedLexiconBundles = decodeSentimentLexiconBundlesFromJSONObject(
            JSONFieldReader.array(sentiment, key: "userLexiconBundles")
        )
        self.sentimentSelectedCorpusIDs = JSONFieldReader.array(sentiment, key: "selectedCorpusIDs").compactMap { $0 as? String }
        self.sentimentReferenceCorpusID = JSONFieldReader.string(sentiment, key: "referenceCorpusID")
        let evidence = JSONFieldReader.dictionary(json, key: "evidence")
        self.evidenceReviewFilter = EvidenceReviewFilter(
            rawValue: JSONFieldReader.string(evidence, key: "reviewFilter", fallback: EvidenceReviewFilter.all.rawValue)
        ) ?? .all
        self.evidenceSourceFilter = EvidenceSourceFilter(
            rawValue: JSONFieldReader.string(evidence, key: "sourceFilter", fallback: EvidenceSourceFilter.all.rawValue)
        ) ?? .all
        self.evidenceSentimentFilter = EvidenceSentimentFilter(
            rawValue: JSONFieldReader.string(evidence, key: "sentimentFilter", fallback: EvidenceSentimentFilter.all.rawValue)
        ) ?? .all
        self.evidenceTagFilterQuery = JSONFieldReader.string(evidence, key: "tagFilterQuery")
        self.evidenceCorpusFilterQuery = JSONFieldReader.string(evidence, key: "corpusFilterQuery")
        let keyword = JSONFieldReader.dictionary(json, key: "keyword")
        self.keywordActiveTab = KeywordSuiteTab(
            rawValue: JSONFieldReader.string(keyword, key: "activeTab", fallback: KeywordSuiteTab.words.rawValue)
        ) ?? .words
        self.keywordTargetCorpusID = JSONFieldReader.string(keyword, key: "targetCorpusID")
        self.keywordReferenceCorpusID = JSONFieldReader.string(keyword, key: "referenceCorpusID")
        self.keywordLowercased = JSONFieldReader.bool(keyword, key: "lowercased", fallback: true)
        self.keywordRemovePunctuation = JSONFieldReader.bool(keyword, key: "removePunctuation", fallback: true)
        self.keywordMinimumFrequency = JSONFieldReader.string(keyword, key: "minimumFrequency", fallback: "2")
        self.keywordStatistic = KeywordStatisticMethod(
            rawValue: JSONFieldReader.string(keyword, key: "statistic", fallback: KeywordStatisticMethod.logLikelihood.rawValue)
        ) ?? .logLikelihood
        self.keywordStopwordFilter = StopwordFilterState(json: JSONFieldReader.dictionary(keyword, key: "stopwordFilter"))
        let suiteConfigurationObject = JSONFieldReader.dictionary(keyword, key: "suiteConfiguration")
        if suiteConfigurationObject.isEmpty {
            self.keywordSuiteConfiguration = .legacy(
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
        } else {
            self.keywordSuiteConfiguration = KeywordSuiteConfiguration(json: suiteConfigurationObject)
        }
        let plot = JSONFieldReader.dictionary(json, key: "plot")
        self.plotQuery = JSONFieldReader.string(plot, key: "query")
        self.plotSearchOptions = SearchOptionsState(json: JSONFieldReader.dictionary(plot, key: "options"))
        let ngram = JSONFieldReader.dictionary(json, key: "ngram")
        self.ngramSize = JSONFieldReader.string(ngram, key: "size", fallback: "2")
        self.ngramPageSize = JSONFieldReader.string(ngram, key: "pageSize", fallback: "10")
        let cluster = JSONFieldReader.dictionary(json, key: "cluster")
        self.clusterSelectedN = JSONFieldReader.string(cluster, key: "selectedN", fallback: "3")
        self.clusterMinFrequency = JSONFieldReader.string(cluster, key: "minFrequency", fallback: "3")
        self.clusterSortMode = ClusterSortMode(
            rawValue: JSONFieldReader.string(cluster, key: "sortMode", fallback: ClusterSortMode.frequencyDescending.rawValue)
        ) ?? .frequencyDescending
        self.clusterCaseSensitive = JSONFieldReader.bool(cluster, key: "caseSensitive", fallback: false)
        self.clusterStopwordFilter = StopwordFilterState(json: JSONFieldReader.dictionary(cluster, key: "stopwordFilter"))
        self.clusterPunctuationMode = ClusterPunctuationMode(
            rawValue: JSONFieldReader.string(cluster, key: "punctuationMode", fallback: ClusterPunctuationMode.boundary.rawValue)
        ) ?? .boundary
        self.clusterSelectedPhrase = JSONFieldReader.string(cluster, key: "selectedPhrase")
        self.clusterPageSize = JSONFieldReader.string(cluster, key: "pageSize", fallback: "100")
        self.clusterReferenceCorpusID = JSONFieldReader.string(cluster, key: "referenceCorpusID")
        let kwic = JSONFieldReader.dictionary(json, key: "kwic")
        self.kwicLeftWindow = JSONFieldReader.string(kwic, key: "leftWindow", fallback: "5")
        self.kwicRightWindow = JSONFieldReader.string(kwic, key: "rightWindow", fallback: "5")
        let collocate = JSONFieldReader.dictionary(json, key: "collocate")
        self.collocateLeftWindow = JSONFieldReader.string(collocate, key: "leftWindow", fallback: "5")
        self.collocateRightWindow = JSONFieldReader.string(collocate, key: "rightWindow", fallback: "5")
        self.collocateMinFreq = JSONFieldReader.string(collocate, key: "minFreq", fallback: "1")
        let topics = JSONFieldReader.dictionary(json, key: "topics")
        self.topicsMinTopicSize = JSONFieldReader.string(topics, key: "minTopicSize", fallback: "2")
        self.topicsKeywordDisplayCount = JSONFieldReader.string(topics, key: "keywordDisplayCount", fallback: "5")
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
            evidenceReviewFilter: draft.evidenceReviewFilter,
            evidenceSourceFilter: draft.evidenceSourceFilter,
            evidenceSentimentFilter: draft.evidenceSentimentFilter,
            evidenceTagFilterQuery: draft.evidenceTagFilterQuery,
            evidenceCorpusFilterQuery: draft.evidenceCorpusFilterQuery,
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
}

private func decodeSentimentLexiconBundlesFromJSONObject(
    _ values: [Any]
) -> [SentimentUserLexiconBundle] {
    values.compactMap { value in
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value)
        else {
            return nil
        }
        return try? JSONDecoder().decode(SentimentUserLexiconBundle.self, from: data)
    }
}

private func decodeSentimentCalibrationProfileFromJSONObject(
    _ value: JSONObject
) -> SentimentCalibrationProfile? {
    guard !value.isEmpty,
          JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value)
    else {
        return nil
    }
    return try? JSONDecoder().decode(SentimentCalibrationProfile.self, from: data)
}
