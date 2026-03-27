import Foundation

@MainActor
final class CollocatePageViewModel: ObservableObject {
    @Published var keyword = "" {
        didSet {
            guard oldValue != keyword else { return }
            onInputChange?()
        }
    }
    @Published var leftWindow = "5" {
        didSet {
            guard oldValue != leftWindow else { return }
            onInputChange?()
        }
    }
    @Published var rightWindow = "5" {
        didSet {
            guard oldValue != rightWindow else { return }
            onInputChange?()
        }
    }
    @Published var minFreq = "1" {
        didSet {
            guard oldValue != minFreq else { return }
            onInputChange?()
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            onInputChange?()
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            onInputChange?()
            rebuildScene()
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: CollocateSceneModel?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: CollocateSceneBuilder
    private var result: CollocateResult?
    private var sortMode: CollocateSortMode = .frequencyDescending
    private var pageSize: CollocatePageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<CollocateColumnKey> = Set(CollocateColumnKey.allCases)

    init(sceneBuilder: CollocateSceneBuilder = CollocateSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    var minFreqValue: Int {
        Int(minFreq) ?? 1
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        keyword = snapshot.searchQuery
        leftWindow = snapshot.collocateLeftWindow
        rightWindow = snapshot.collocateRightWindow
        minFreq = snapshot.collocateMinFreq
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: CollocateResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: CollocatePageAction) {
        switch action {
        case .run:
            return
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
        result = nil
        currentPage = 1
        scene = nil
    }

    private func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        scene = sceneBuilder.build(
            from: result,
            query: normalizedKeyword,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            leftWindow: leftWindowValue,
            rightWindow: rightWindowValue,
            minFreq: minFreqValue,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    private func sortByColumn(_ column: CollocateColumnKey) {
        let nextSort: CollocateSortMode?
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .word:
            nextSort = .alphabeticalAscending
        case .total:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .rate:
            nextSort = .rateDescending
        case .left, .right, .wordFreq, .keywordFreq:
            nextSort = nil
        }
        guard let nextSort, sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }

    private func toggleColumn(_ column: CollocateColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }
}
