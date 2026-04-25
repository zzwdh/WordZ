import Foundation

struct SentimentSelectableCorpusSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct SentimentReferenceOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct SentimentCalibrationProfileSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

@MainActor
package final class SentimentPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisSelectedRowControlling {
    typealias AnalysisPageSize = SentimentPageSize
    typealias AnalysisSortMode = SentimentSortMode

    static let defaultVisibleColumns: Set<SentimentColumnKey> = [
        .source, .text, .positivity, .neutrality, .negativity, .finalLabel
    ]

    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }

    @Published var source: SentimentInputSource = .openedCorpus {
        didSet {
            guard oldValue != source else { return }
            clampUnitForSource()
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var unit: SentimentAnalysisUnit = .sentence {
        didSet {
            guard oldValue != unit else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var contextBasis: SentimentContextBasis = .visibleContext {
        didSet {
            guard oldValue != contextBasis else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var backend: SentimentBackendKind = .lexicon {
        didSet {
            guard oldValue != backend else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var selectedDomainPackID: SentimentDomainPackID = .mixed {
        didSet {
            guard oldValue != selectedDomainPackID else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var selectedRuleProfileID: String = SentimentRuleProfile.default.id {
        didSet {
            guard oldValue != selectedRuleProfileID else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var selectedCalibrationProfileID: String = SentimentCalibrationProfile.default.id {
        didSet {
            guard oldValue != selectedCalibrationProfileID else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var chartKind: SentimentChartKind = .distributionBar {
        didSet {
            guard oldValue != chartKind else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var thresholdPreset: SentimentThresholdPreset = .conservative {
        didSet {
            guard oldValue != thresholdPreset else { return }
            if thresholdPreset != .custom {
                applyThresholds(thresholdPreset.thresholds, rebuildScene: true)
            }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var decisionThreshold: Double = SentimentThresholds.default.decisionThreshold {
        didSet {
            guard oldValue != decisionThreshold else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var minimumEvidence: Double = SentimentThresholds.default.minimumEvidence {
        didSet {
            guard oldValue != minimumEvidence else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var neutralBias: Double = SentimentThresholds.default.neutralBias {
        didSet {
            guard oldValue != neutralBias else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var rowFilterQuery = "" {
        didSet {
            guard oldValue != rowFilterQuery else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var labelFilter: SentimentLabel? {
        didSet {
            guard oldValue != labelFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var reviewFilter: SentimentReviewFilter = .all {
        didSet {
            guard oldValue != reviewFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var reviewStatusFilter: SentimentReviewStatusFilter = .all {
        didSet {
            guard oldValue != reviewStatusFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var showOnlyHardCases = false {
        didSet {
            guard oldValue != showOnlyHardCases else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var workspaceCalibrationProfile: SentimentCalibrationProfile = .workspaceDefault {
        didSet {
            guard oldValue != workspaceCalibrationProfile else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var importedLexiconBundles: [SentimentUserLexiconBundle] = [] {
        didSet {
            guard oldValue != importedLexiconBundles else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var manualText = "" {
        didSet {
            guard oldValue != manualText else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var selectionItems: [SentimentSelectableCorpusSceneItem] = []
    @Published var referenceOptions: [SentimentReferenceOptionSceneItem] = []
    @Published var scene: SentimentSceneModel?
    @Published var selectedRowID: String?
    @Published var selectedReviewNoteDraft = ""
    @Published var backendNotice: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: SentimentSceneBuilder
    let availableBackendProvider: () -> [SentimentBackendKind]
    let packRecommendationService: SentimentPackRecommendationService
    var rawResult: SentimentRunResult?
    var presentationResult: SentimentPresentationResult?
    var reviewSamples: [SentimentReviewSample] = []
    var sortMode: SentimentSortMode = .original
    var pageSize: SentimentPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<SentimentColumnKey> = SentimentPageViewModel.defaultVisibleColumns
    var availableCorpora: [LibraryCorpusItem] = []
    var availableCorpusSets: [LibraryCorpusSetItem] = []
    var availableBackends: [SentimentBackendKind]
    var selectedCorpusIDs: Set<String> = []
    var selectedReferenceSelection: CompareReferenceSelection = .automatic
    var topicSegmentsFocusClusterID: String?
    var annotationState = WorkspaceAnnotationState.default

    package static func makeFeaturePage() -> SentimentPageViewModel {
        SentimentPageViewModel(sceneBuilder: SentimentSceneBuilder())
    }

    init(
        sceneBuilder: SentimentSceneBuilder = SentimentSceneBuilder(),
        availableBackendProvider: @escaping () -> [SentimentBackendKind] = {
            SentimentBackendCatalog.availableBackends()
        },
        packRecommendationService: SentimentPackRecommendationService = SentimentPackRecommendationService()
    ) {
        self.sceneBuilder = sceneBuilder
        self.availableBackendProvider = availableBackendProvider
        self.packRecommendationService = packRecommendationService
        self.availableBackends = availableBackendProvider()
    }

    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? presentationResult?.effectiveRows.count ?? rawResult?.rows.count
    }

    var availableDomainPacks: [SentimentDomainPackID] {
        SentimentDomainPackID.allCases
    }

    var availableCalibrationProfiles: [SentimentCalibrationProfileSceneItem] {
        [
            SentimentCalibrationProfileSceneItem(
                id: SentimentCalibrationProfile.default.id,
                title: wordZText("默认", "Default", mode: .system),
                subtitle: wordZText("使用内置的保守校准", "Use the built-in English-tuned calibration", mode: .system)
            ),
            SentimentCalibrationProfileSceneItem(
                id: SentimentCalibrationProfile.workspaceDefault.id,
                title: wordZText("工作区", "Workspace", mode: .system),
                subtitle: wordZText("保存当前工作区的本地校准与 pack bias", "Save local calibration and pack bias for this workspace", mode: .system)
            )
        ]
    }

    var supportedUnits: [SentimentAnalysisUnit] {
        switch source {
        case .kwicVisible:
            return [.concordanceLine]
        case .topicSegments:
            return [.sourceSentence]
        default:
            return [.document, .sentence]
        }
    }

    var thresholds: SentimentThresholds {
        SentimentThresholds(
            decisionThreshold: decisionThreshold,
            minimumEvidence: minimumEvidence,
            neutralBias: neutralBias
        )
    }

    var showsBackendPicker: Bool {
        availableBackends.count > 1
    }

    var manualTextCharacterCount: Int {
        manualText.count
    }

    var manualTextSentenceCountEstimate: Int {
        let count = manualText.filter { [".", "!", "?"].contains($0) }.count
        return max(count, manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    func canRun(hasOpenedCorpus: Bool, hasKWICRows: Bool, hasTopicRows: Bool) -> Bool {
        switch source {
        case .openedCorpus:
            return hasOpenedCorpus
        case .pastedText:
            return !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .kwicVisible:
            return hasKWICRows
        case .corpusCompare:
            return !selectedTargetCorpusItems().isEmpty
        case .topicSegments:
            return hasTopicRows
        }
    }
}
