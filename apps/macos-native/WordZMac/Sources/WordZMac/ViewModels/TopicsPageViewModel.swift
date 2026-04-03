import Foundation

@MainActor
final class TopicsPageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<TopicsColumnKey> = Set(TopicsColumnKey.allCases)
    private var isApplyingSnapshot = false

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
    private let sceneBuilder: TopicsSceneBuilder
    private var result: TopicAnalysisResult?
    private var selectedClusterID: String?
    private var sortMode: TopicSegmentSortMode = .relevanceDescending
    private var pageSize: TopicsPageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<TopicsColumnKey> = TopicsPageViewModel.defaultVisibleColumns

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

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingSnapshot = true
        defer {
            isApplyingSnapshot = false
            rebuildScene()
        }

        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
        minTopicSize = snapshot.topicsMinTopicSize
        includeOutliers = snapshot.topicsIncludeOutliers
        if let matchedPageSize = TopicsPageSize.allCases.first(where: { "\($0.rawValue)" == snapshot.topicsPageSize || $0.title(in: .system) == snapshot.topicsPageSize }) {
            pageSize = matchedPageSize
        }
        selectedClusterID = snapshot.topicsActiveTopicID.isEmpty ? nil : snapshot.topicsActiveTopicID
    }

    func apply(_ result: TopicAnalysisResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: TopicsPageAction) {
        switch action {
        case .run, .exportSummary, .exportSegments:
            return
        case .selectCluster(let clusterID):
            selectedClusterID = clusterID
            currentPage = 1
            rebuildScene()
        case .changeSort(let nextSort):
            guard sortMode != nextSort else { return }
            sortMode = nextSort
            currentPage = 1
            rebuildScene()
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            guard pageSize != nextPageSize else { return }
            pageSize = nextPageSize
            currentPage = 1
            rebuildScene()
        case .toggleColumn(let column):
            toggleColumn(column)
        case .previousPage:
            guard let scene, scene.pagination.canGoBackward else { return }
            currentPage = max(1, currentPage - 1)
            rebuildScene()
        case .nextPage:
            guard let scene, scene.pagination.canGoForward else { return }
            currentPage += 1
            rebuildScene()
        }
    }

    func reset() {
        isApplyingSnapshot = true
        defer { isApplyingSnapshot = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        minTopicSize = "2"
        includeOutliers = true
        isEditingStopwords = false
        result = nil
        selectedClusterID = nil
        sortMode = .relevanceDescending
        pageSize = .fifty
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        scene = nil
    }

    private func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        guard !isApplyingSnapshot else { return }
        onInputChange?()
        if shouldRebuildScene {
            rebuildScene()
        }
    }

    private func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        scene = sceneBuilder.build(
            from: result,
            query: normalizedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            minTopicSize: minTopicSizeValue,
            includeOutliers: includeOutliers,
            selectedClusterID: selectedClusterID,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
        selectedClusterID = scene?.selectedClusterID
    }

    private func toggleColumn(_ column: TopicsColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func sortByColumn(_ column: TopicsColumnKey) {
        let nextSort: TopicSegmentSortMode
        switch column {
        case .paragraph:
            nextSort = sortMode == .paragraphAscending ? .paragraphDescending : .paragraphAscending
        case .score:
            nextSort = sortMode == .relevanceDescending ? .relevanceAscending : .relevanceDescending
        case .excerpt:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }
}
