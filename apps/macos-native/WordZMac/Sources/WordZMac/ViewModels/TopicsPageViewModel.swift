import Foundation

@MainActor
final class TopicsPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling {
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
    @Published var includeOutliers = true {
        didSet {
            guard oldValue != includeOutliers else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: TopicsSceneModel?

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
    var cachedClusterLanguageMode: AppLanguageMode?
    var cachedSortedSegments: [TopicSegmentRow]?
    var cachedSortedClusterID: String?
    var cachedSortMode: TopicSegmentSortMode?

    init(sceneBuilder: TopicsSceneBuilder = TopicsSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var minTopicSizeValue: Int {
        max(2, Int(minTopicSize) ?? 2)
    }

    var exportSummarySnapshot: NativeTableExportSnapshot? {
        scene?.summaryExportSnapshot
    }

    var exportSegmentsSnapshot: NativeTableExportSnapshot? {
        scene?.segmentsExportSnapshot
    }
}
