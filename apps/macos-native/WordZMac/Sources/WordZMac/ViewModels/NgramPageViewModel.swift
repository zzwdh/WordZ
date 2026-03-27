import Foundation

@MainActor
final class NgramPageViewModel: ObservableObject {
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
    @Published var ngramSize = "2" {
        didSet {
            guard oldValue != ngramSize else { return }
            onInputChange?()
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: NgramSceneModel?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: NgramSceneBuilder
    private var result: NgramResult?
    private var sortMode: NgramSortMode = .frequencyDescending
    private var pageSize: NgramPageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<NgramColumnKey> = Set(NgramColumnKey.allCases)

    init(sceneBuilder: NgramSceneBuilder = NgramSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var ngramSizeValue: Int {
        max(2, Int(ngramSize) ?? 2)
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
        ngramSize = snapshot.ngramSize
        if let matchedPageSize = NgramPageSize.allCases.first(where: { $0.title == snapshot.ngramPageSize }) {
            pageSize = matchedPageSize
        }
    }

    func apply(_ result: NgramResult) {
        self.result = result
        ngramSize = "\(result.n)"
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: NgramPageAction) {
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
        case .changeSize(let nextSize):
            let normalizedSize = max(2, nextSize)
            guard ngramSizeValue != normalizedSize else { return }
            ngramSize = "\(normalizedSize)"
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

    var pageSizeSnapshotValue: String {
        pageSize.title
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
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    private func toggleColumn(_ column: NgramColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func sortByColumn(_ column: NgramColumnKey) {
        let nextSort: NgramSortMode
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .phrase:
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
