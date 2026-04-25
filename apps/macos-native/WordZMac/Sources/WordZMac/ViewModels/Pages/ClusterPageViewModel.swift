import Foundation

struct ClusterReferenceCorpusOption: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

@MainActor
final class ClusterPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisSelectedRowControlling {
    typealias AnalysisPageSize = ClusterPageSize
    typealias AnalysisSortMode = ClusterSortMode

    static let defaultVisibleColumns: Set<ClusterColumnKey> = [
        .phrase, .n, .frequency, .normalizedFrequency, .range, .rangePercentage, .logRatio
    ]

    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }

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
    @Published var selectedN = "3" {
        didSet {
            guard oldValue != selectedN else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var minimumFrequency = "3" {
        didSet {
            guard oldValue != minimumFrequency else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var mode: ClusterMode = .targetOnly {
        didSet {
            guard oldValue != mode else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var referenceCorpusID = "" {
        didSet {
            guard oldValue != referenceCorpusID else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var caseSensitive = false {
        didSet {
            guard oldValue != caseSensitive else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var punctuationMode: ClusterPunctuationMode = .boundary {
        didSet {
            guard oldValue != punctuationMode else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: ClusterSceneModel?
    @Published var selectedRowID: String?
    @Published private(set) var referenceCorpusOptions: [ClusterReferenceCorpusOption] = []

    var onInputChange: (() -> Void)?
    let sceneBuilder: ClusterSceneBuilder
    var result: ClusterResult?
    var sortMode: ClusterSortMode = .frequencyDescending
    var pageSize: ClusterPageSize = .oneHundred
    var currentPage = 1
    var visibleColumns: Set<ClusterColumnKey> = ClusterPageViewModel.defaultVisibleColumns
    var annotationState = WorkspaceAnnotationState.default

    init(sceneBuilder: ClusterSceneBuilder = ClusterSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    var selectedNValue: Int {
        max(2, min(5, Int(selectedN) ?? 3))
    }

    var minimumFrequencyValue: Int {
        max(1, Int(minimumFrequency) ?? 3)
    }

    var normalizedQuery: String {
        AnalysisViewModelSupport.normalizedQuery(query)
    }

    var selectedSceneRow: ClusterSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var pageSizeSnapshotValue: String {
        pageSize.title(in: .system)
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        let corpora = snapshot.corpora
        referenceCorpusOptions = corpora.map {
            ClusterReferenceCorpusOption(id: $0.id, title: $0.name, subtitle: $0.folderName)
        }
        if !referenceCorpusID.isEmpty,
           !referenceCorpusOptions.contains(where: { $0.id == referenceCorpusID }) {
            referenceCorpusID = ""
        }
    }

    func handle(_ action: ClusterPageAction) {
        switch action {
        case .run, .openKWIC:
            return
        case .changeMode(let nextMode):
            mode = nextMode
        case .changeReferenceCorpus(let corpusID):
            referenceCorpusID = corpusID ?? ""
        case .changeSelectedN(let nextN):
            selectedN = "\(max(2, min(5, nextN)))"
        case .changeMinFrequency(let value):
            minimumFrequency = value
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .changeCaseSensitive(let nextValue):
            caseSensitive = nextValue
        case .changePunctuationMode(let nextMode):
            punctuationMode = nextMode
        case .toggleColumn(let column):
            toggleVisibleColumnAndRebuild(column)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        case .selectRow(let rowID):
            selectedRowID = rowID
            rebuildScene()
        case .activateRow(let rowID):
            selectedRowID = rowID
            rebuildScene()
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let allRows = result.rows.filter { $0.n == selectedNValue }
        syncSelectedRow(within: allRows)
        scene = sceneBuilder.build(
            from: result,
            query: normalizedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationState: annotationState,
            selectedN: selectedNValue,
            minimumFrequency: minimumFrequencyValue,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            selectedRowID: selectedRowID,
            caseSensitive: caseSensitive,
            punctuationMode: punctuationMode,
            languageMode: WordZLocalization.shared.effectiveMode
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        selectedN = snapshot.clusterSelectedN
        minimumFrequency = snapshot.clusterMinFrequency
        sortMode = snapshot.clusterSortMode
        caseSensitive = snapshot.clusterCaseSensitive
        stopwordFilter = snapshot.clusterStopwordFilter
        punctuationMode = snapshot.clusterPunctuationMode
        referenceCorpusID = snapshot.clusterReferenceCorpusID
        mode = referenceCorpusID.isEmpty ? .targetOnly : .targetReference
        selectedRowID = snapshot.clusterSelectedPhrase.isEmpty ? nil : snapshot.clusterSelectedPhrase
        if let resolvedPageSize = ClusterPageSize.allCases.first(where: { $0.title(in: .system) == snapshot.clusterPageSize }) {
            pageSize = resolvedPageSize
        }
    }

    func apply(_ result: ClusterResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        self.result = result
        mode = result.mode
        currentPage = 1
        selectedRowID = result.rows.first(where: { $0.n == selectedNValue })?.id
    }

    func reset() {
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        selectedN = "3"
        minimumFrequency = "3"
        mode = .targetOnly
        referenceCorpusID = ""
        caseSensitive = false
        punctuationMode = .boundary
        isEditingStopwords = false
        result = nil
        sortMode = .frequencyDescending
        pageSize = .oneHundred
        currentPage = 1
        selectedRowID = nil
        visibleColumns = Self.defaultVisibleColumns
        scene = nil
    }

    func applyWorkspaceAnnotationState(_ state: WorkspaceAnnotationState) {
        guard annotationState != state else { return }
        annotationState = state
        rebuildScene()
    }

    private func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            self.currentPage = 1
            self.rebuildScene()
        }
    }

    private func sortByColumn(_ column: ClusterColumnKey) {
        let nextSort: ClusterSortMode
        switch column {
        case .phrase:
            nextSort = .alphabeticalAscending
        default:
            nextSort = .frequencyDescending
        }
        applySortModeChange(nextSort)
    }
}
