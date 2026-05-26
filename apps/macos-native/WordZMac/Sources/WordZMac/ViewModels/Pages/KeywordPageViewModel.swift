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
    @Published var selectionState = KeywordSuiteSelectionState()
    @Published var filterState = KeywordSuiteFilterState()
    @Published var savedListState = KeywordSavedListState()
    @Published var corpusOptions: [KeywordCorpusOptionSceneItem] = []
    @Published var corpusSetOptions: [KeywordCorpusSetOptionSceneItem] = []
    @Published var scene: KeywordSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?

    let sceneBuilder: KeywordSceneBuilder
    var result: KeywordSuiteResult?
    var tablePresentation = AnalysisTablePresentationState<KeywordColumnKey, KeywordSortMode, KeywordPageSize>(
        sortMode: .keynessDescending,
        pageSize: .fifty,
        visibleColumns: KeywordPageViewModel.defaultVisibleColumns
    )
    var availableCorpora: [LibraryCorpusItem] = []
    var availableCorpusSets: [LibraryCorpusSetItem] = []
    var lastRunConfiguration: KeywordRunConfiguration?

    init(sceneBuilder: KeywordSceneBuilder = KeywordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var currentResultRowCountForPaging: Int? {
        if let totalRows = scene?.totalRows {
            return totalRows
        }
        let estimatedRows = estimatedSceneBuildRowCount(
            result: result,
            activeTab: activeTab,
            listMode: savedListViewMode,
            primarySavedList: selectedSavedList,
            secondarySavedList: comparisonSavedList,
            savedLists: savedLists
        )
        return estimatedRows > 0 ? estimatedRows : nil
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
