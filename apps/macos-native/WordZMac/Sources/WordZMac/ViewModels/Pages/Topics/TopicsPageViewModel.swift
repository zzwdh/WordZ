import Foundation

@MainActor
package final class TopicsPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSelectedRowControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<TopicsColumnKey> = Set(TopicsColumnKey.allCases)
    var isApplyingSnapshot = false
    var isApplyingInputState: Bool { isApplyingSnapshot }
    var isApplyingStateFlag: Bool {
        get { isApplyingSnapshot }
        set { isApplyingSnapshot = newValue }
    }

    @Published var query = "" {
        didSet {
            guard oldValue != query else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var minTopicSize = "2" {
        didSet {
            guard oldValue != minTopicSize else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var keywordDisplayCount = "5" {
        didSet {
            guard oldValue != keywordDisplayCount else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var includeOutliers = true {
        didSet {
            guard oldValue != includeOutliers else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: TopicsSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: TopicsSceneBuilder
    var result: TopicAnalysisResult?
    var selectedClusterID: String?
    var sortMode: TopicSegmentSortMode = .relevanceDescending
    var pageSize: TopicsPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<TopicsColumnKey> = TopicsPageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0
    var cachedClusterComputation: TopicsClusterComputation?
    var cachedClusterQuery = ""
    var cachedClusterOptions = SearchOptionsState.default
    var cachedClusterStopwordFilter = StopwordFilterState.default
    var cachedIncludeOutliers = true
    var cachedKeywordDisplayCount = 5
    var cachedClusterLanguageMode: AppLanguageMode?
    var cachedCompareDrilldownContext: TopicsCompareDrilldownContext?
    var cachedSortedSegments: [TopicSegmentRow]?
    var cachedSortedClusterID: String?
    var cachedSortMode: TopicSegmentSortMode?
    var compareDrilldownContext: TopicsCompareDrilldownContext?
    var sentimentExplainer: TopicsSentimentExplainer?
    var annotationState = WorkspaceAnnotationState.default

    package static func makeFeaturePage() -> TopicsPageViewModel {
        TopicsPageViewModel(sceneBuilder: TopicsSceneBuilder())
    }

    init(sceneBuilder: TopicsSceneBuilder = TopicsSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var minTopicSizeValue: Int {
        max(2, Int(minTopicSize) ?? 2)
    }

    var keywordDisplayCountValue: Int {
        min(12, max(1, Int(keywordDisplayCount) ?? 5))
    }

    var exportSummarySnapshot: NativeTableExportSnapshot? {
        scene?.summaryExportSnapshot
    }

    var exportSegmentsSnapshot: NativeTableExportSnapshot? {
        scene?.segmentsExportSnapshot
    }

    var selectedSceneRow: TopicSegmentRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.segmentRows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.segmentRows.first
    }

    func applyWorkspaceAnnotationState(_ state: WorkspaceAnnotationState) {
        guard annotationState != state else { return }
        annotationState = state
        rebuildScene()
    }

    func applySentimentPresentationResult(
        _ result: SentimentPresentationResult,
        languageMode: AppLanguageMode
    ) {
        let nextExplainer = SentimentCrossAnalysisSupport.buildTopicsExplainer(
            presentationResult: result,
            focusedClusterID: selectedClusterID,
            languageMode: languageMode
        )
        guard sentimentExplainer != nextExplainer else { return }
        sentimentExplainer = nextExplainer
        rebuildScene()
    }
}
