import Foundation

struct KeywordRunConfiguration: Equatable {
    let configuration: KeywordSuiteConfiguration
}

@MainActor
final class KeywordPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling, AnalysisSelectedRowControlling {
    static let defaultVisibleColumns: Set<KeywordColumnKey> = [
        .rank, .item, .direction, .focusFrequency, .referenceFrequency,
        .focusNormFrequency, .referenceNormFrequency, .keyness, .logRatio,
        .pValue, .focusRange, .referenceRange, .diffStatus, .leftRank,
        .rightRank, .logRatioDelta, .coverageCount, .coverageRate,
        .meanKeyness, .meanAbsLogRatio, .lastSeenAt
    ]

    var isApplyingState = false
    var sceneBuildRevision = 0
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

    @Published var activeTab: KeywordSuiteTab = .words {
        didSet {
            guard oldValue != activeTab else { return }
            if activeTab == .lists {
                rebuildScene()
            } else {
                handleInputChange()
            }
        }
    }
    @Published var focusSelectionKind: KeywordTargetSelectionKind = .singleCorpus {
        didSet {
            guard oldValue != focusSelectionKind else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var referenceSourceKind: KeywordReferenceSourceKind = .singleCorpus {
        didSet {
            guard oldValue != referenceSourceKind else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var selectedFocusCorpusID: String? {
        didSet {
            guard oldValue != selectedFocusCorpusID else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var selectedFocusCorpusIDs: Set<String> = [] {
        didSet {
            guard oldValue != selectedFocusCorpusIDs else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var selectedFocusCorpusSetID: String? {
        didSet {
            guard oldValue != selectedFocusCorpusSetID else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var selectedReferenceCorpusID: String? {
        didSet {
            guard oldValue != selectedReferenceCorpusID else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var selectedReferenceCorpusSetID: String? {
        didSet {
            guard oldValue != selectedReferenceCorpusSetID else { return }
            handleSelectionConfigurationChange()
        }
    }
    @Published var importedReferenceListText = "" {
        didSet {
            guard oldValue != importedReferenceListText else { return }
            handleInputChange()
        }
    }
    @Published var importedReferenceListSourceName: String?
    @Published var importedReferenceListImportedAt: String?
    @Published var annotationProfile: WorkspaceAnnotationProfile = .surface {
        didSet {
            guard oldValue != annotationProfile else { return }
            let nextUnit = annotationProfile.keywordUnit
            if unit != nextUnit {
                unit = nextUnit
            } else {
                handleInputChange()
            }
        }
    }
    @Published var unit: KeywordUnit = .normalizedSurface {
        didSet {
            guard oldValue != unit else { return }
            handleInputChange()
        }
    }
    @Published var direction: KeywordDirection = .positive {
        didSet {
            guard oldValue != direction else { return }
            handleInputChange()
        }
    }
    @Published var statistic: KeywordStatisticMethod = .logLikelihood {
        didSet {
            guard oldValue != statistic else { return }
            handleInputChange()
        }
    }
    @Published var languagePreset: TokenizeLanguagePreset = .mixedChineseEnglish {
        didSet {
            guard oldValue != languagePreset else { return }
            handleInputChange()
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange()
        }
    }
    @Published var minFocusFrequency = "2" {
        didSet {
            guard oldValue != minFocusFrequency else { return }
            handleInputChange()
        }
    }
    @Published var minReferenceFrequency = "0" {
        didSet {
            guard oldValue != minReferenceFrequency else { return }
            handleInputChange()
        }
    }
    @Published var minCombinedFrequency = "2" {
        didSet {
            guard oldValue != minCombinedFrequency else { return }
            handleInputChange()
        }
    }
    @Published var maxPValue = "1.0" {
        didSet {
            guard oldValue != maxPValue else { return }
            handleInputChange()
        }
    }
    @Published var minAbsLogRatio = "0.0" {
        didSet {
            guard oldValue != minAbsLogRatio else { return }
            handleInputChange()
        }
    }
    @Published var selectedScripts: Set<TokenScript> = [] {
        didSet {
            guard oldValue != selectedScripts else { return }
            handleInputChange()
        }
    }
    @Published var selectedLexicalClasses: Set<TokenLexicalClass> = [] {
        didSet {
            guard oldValue != selectedLexicalClasses else { return }
            handleInputChange()
        }
    }
    @Published var isEditingStopwords = false
    @Published var savedListName = ""
    @Published var savedListViewMode: KeywordSavedListViewMode = .pairwiseDiff {
        didSet {
            guard oldValue != savedListViewMode else { return }
            rebuildScene()
        }
    }
    @Published var selectedSavedListID: String? {
        didSet {
            guard oldValue != selectedSavedListID else { return }
            handleSavedListSelectionChange()
        }
    }
    @Published var comparisonSavedListID: String? {
        didSet {
            guard oldValue != comparisonSavedListID else { return }
            handleSavedListSelectionChange()
        }
    }
    @Published var corpusOptions: [KeywordCorpusOptionSceneItem] = []
    @Published var corpusSetOptions: [KeywordCorpusSetOptionSceneItem] = []
    @Published var savedLists: [KeywordSavedList] = []
    @Published var scene: KeywordSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?

    let sceneBuilder: KeywordSceneBuilder
    var result: KeywordSuiteResult?
    var sortMode: KeywordSortMode = .keynessDescending
    var pageSize: KeywordPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<KeywordColumnKey> = KeywordPageViewModel.defaultVisibleColumns
    var availableCorpora: [LibraryCorpusItem] = []
    var availableCorpusSets: [LibraryCorpusSetItem] = []
    var lastRunConfiguration: KeywordRunConfiguration?

    init(sceneBuilder: KeywordSceneBuilder = KeywordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var currentResultRowCountForPaging: Int? {
        scene?.totalRows
    }

    var currentRunConfiguration: KeywordRunConfiguration {
        KeywordRunConfiguration(configuration: suiteConfiguration)
    }

    var workspaceAnnotationState: WorkspaceAnnotationState {
        WorkspaceAnnotationState(
            profile: annotationProfile,
            lexicalClasses: Array(selectedLexicalClasses),
            scripts: Array(selectedScripts)
        )
    }

    var suiteConfiguration: KeywordSuiteConfiguration {
        KeywordSuiteConfiguration(
            focusSelection: KeywordTargetSelection(
                kind: focusSelectionKind,
                corpusIDs: orderedFocusCorpusIDs,
                corpusSetID: selectedFocusCorpusSetID ?? ""
            ),
            referenceSource: KeywordReferenceSource(
                kind: referenceSourceKind,
                corpusID: selectedReferenceCorpusID ?? "",
                corpusSetID: selectedReferenceCorpusSetID ?? "",
                importedListText: importedReferenceListText,
                importedListSourceName: importedReferenceListSourceName,
                importedListImportedAt: importedReferenceListImportedAt
            ),
            unit: annotationProfile.keywordUnit,
            direction: direction,
            statistic: statistic,
            thresholds: KeywordThresholds(
                minFocusFreq: minFocusFrequencyValue,
                minReferenceFreq: minReferenceFrequencyValue,
                minCombinedFreq: minCombinedFrequencyValue,
                maxPValue: maxPValueValue,
                minAbsLogRatio: minAbsLogRatioValue
            ),
            tokenFilters: KeywordTokenFilterState(
                languagePreset: languagePreset,
                lemmaStrategy: annotationProfile.tokenizeLemmaStrategy,
                scripts: selectedScripts.sorted { $0.rawValue < $1.rawValue },
                lexicalClasses: selectedLexicalClasses.sorted { $0.rawValue < $1.rawValue },
                stopwordFilter: stopwordFilter
            )
        )
    }

    var hasPendingRunChanges: Bool {
        guard let lastRunConfiguration else { return false }
        return lastRunConfiguration != currentRunConfiguration
    }

    var minFocusFrequencyValue: Int {
        max(1, Int(minFocusFrequency) ?? 2)
    }

    // Legacy keyword controls and workspace persistence still speak the v1 form shape.
    var lowercased: Bool {
        get { true }
        set {}
    }

    var removePunctuation: Bool {
        get { true }
        set {}
    }

    var minimumFrequency: String {
        get { minFocusFrequency }
        set {
            minFocusFrequency = newValue
            minCombinedFrequency = newValue
        }
    }

    var minReferenceFrequencyValue: Int {
        max(0, Int(minReferenceFrequency) ?? 0)
    }

    var minCombinedFrequencyValue: Int {
        max(1, Int(minCombinedFrequency) ?? 2)
    }

    var maxPValueValue: Double {
        min(1, max(0, Double(maxPValue) ?? 1))
    }

    var minAbsLogRatioValue: Double {
        max(0, Double(minAbsLogRatio) ?? 0)
    }

    func annotationSummary(in mode: AppLanguageMode) -> String {
        workspaceAnnotationState.summary(in: mode)
    }
}
