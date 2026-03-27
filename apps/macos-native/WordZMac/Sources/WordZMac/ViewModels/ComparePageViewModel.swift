import Foundation

@MainActor
final class ComparePageViewModel: ObservableObject {
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
    @Published private(set) var selectionItems: [CompareSelectableCorpusSceneItem] = []
    @Published var scene: CompareSceneModel?

    var onInputChange: (() -> Void)?

    private let sceneBuilder: CompareSceneBuilder
    private var result: CompareResult?
    private var sortMode: CompareSortMode = .spreadDescending
    private var pageSize: ComparePageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<CompareColumnKey> = Set(CompareColumnKey.allCases)
    private var availableCorpora: [LibraryCorpusItem] = []
    private var selectedCorpusIDs: Set<String> = []

    init(sceneBuilder: CompareSceneBuilder = CompareSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var selectedCorpusCount: Int {
        selectedCorpusIDs.count
    }

    var selectedCorpusIDsSnapshot: [String] {
        selectionItems.filter(\.isSelected).map(\.id)
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        availableCorpora = snapshot.corpora
        let validIDs = Set(snapshot.corpora.map(\.id))
        let previousSelection = selectedCorpusIDs
        selectedCorpusIDs = selectedCorpusIDs.intersection(validIDs)

        if selectedCorpusIDs.count < 2 {
            for corpus in snapshot.corpora where !selectedCorpusIDs.contains(corpus.id) {
                selectedCorpusIDs.insert(corpus.id)
                if selectedCorpusIDs.count >= 2 { break }
            }
        }

        selectionItems = snapshot.corpora.map { corpus in
            CompareSelectableCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                isSelected: selectedCorpusIDs.contains(corpus.id)
            )
        }

        if previousSelection != selectedCorpusIDs {
            result = nil
            currentPage = 1
        }
        rebuildScene()
    }

    func handle(_ action: ComparePageAction) {
        switch action {
        case .run:
            return
        case .toggleCorpusSelection(let corpusID):
            toggleCorpusSelection(corpusID)
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

    func apply(_ result: CompareResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func reset() {
        result = nil
        currentPage = 1
        scene = nil
    }

    func isCorpusSelected(_ corpusID: String) -> Bool {
        selectedCorpusIDs.contains(corpusID)
    }

    func selectedCorpusItems() -> [LibraryCorpusItem] {
        availableCorpora.filter { selectedCorpusIDs.contains($0.id) }
    }

    private func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        scene = sceneBuilder.build(
            selection: selectionItems,
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

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggleCorpusSelection(_ corpusID: String) {
        if selectedCorpusIDs.contains(corpusID) {
            guard selectedCorpusIDs.count > 2 else { return }
            selectedCorpusIDs.remove(corpusID)
        } else {
            selectedCorpusIDs.insert(corpusID)
        }
        selectionItems = selectionItems.map {
            CompareSelectableCorpusSceneItem(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                isSelected: selectedCorpusIDs.contains($0.id)
            )
        }
        result = nil
        currentPage = 1
        scene = nil
        onInputChange?()
    }

    private func toggleColumn(_ column: CompareColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func sortByColumn(_ column: CompareColumnKey) {
        let nextSort: CompareSortMode?
        switch column {
        case .word:
            nextSort = .alphabeticalAscending
        case .spread:
            nextSort = .spreadDescending
        case .total:
            nextSort = .totalDescending
        case .range:
            nextSort = .rangeDescending
        case .dominantCorpus, .distribution:
            nextSort = nil
        }
        guard let nextSort, sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }
}
