import Foundation

@MainActor
final class WordPageViewModel: ObservableObject {
    @Published var query = "" {
        didSet {
            guard oldValue != query else { return }
            onInputChange?()
            rebuildScene()
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            onInputChange?()
            rebuildScene()
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
    @Published var scene: WordSceneModel?

    var onInputChange: (() -> Void)?

    private let sceneBuilder: WordSceneBuilder
    private var result: StatsResult?
    private var sortMode: WordSortMode = .frequencyDescending
    private var pageSize: WordPageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<WordColumnKey> = Set(WordColumnKey.allCases)

    init(sceneBuilder: WordSceneBuilder = WordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: StatsResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: WordPageAction) {
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
            if visibleColumns.contains(column) {
                guard visibleColumns.count > 1 else { return }
                visibleColumns.remove(column)
            } else {
                visibleColumns.insert(column)
            }
            rebuildScene()
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
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    private func sortByColumn(_ column: WordColumnKey) {
        let nextSort: WordSortMode
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .word:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }
}
