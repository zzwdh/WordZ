import Foundation

@MainActor
final class KWICPageViewModel: ObservableObject {
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
    @Published var scene: KWICSceneModel?
    @Published private(set) var selectedRowID: String?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: KWICSceneBuilder
    private var result: KWICResult?
    private var sortMode: KWICSortMode = .original
    private var pageSize: KWICPageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<KWICColumnKey> = Set(KWICColumnKey.allCases)

    init(sceneBuilder: KWICSceneBuilder = KWICSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var primaryLocatorSource: LocatorSource? {
        guard let row = selectedSceneRow ?? scene?.rows.first else { return nil }
        return LocatorSource(
            keyword: row.keyword.isEmpty ? normalizedKeyword : row.keyword,
            sentenceId: row.sentenceId,
            nodeIndex: row.sentenceTokenIndex
        )
    }

    var selectedSceneRow: KWICSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        keyword = snapshot.searchQuery
        leftWindow = snapshot.kwicLeftWindow
        rightWindow = snapshot.kwicRightWindow
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: KWICResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: KWICPageAction) {
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
        case .selectRow(let rowID):
            selectRow(rowID)
        case .activateRow(let rowID):
            selectRow(rowID)
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
        selectedRowID = nil
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
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
        if let scene {
            if let selectedRowID, scene.rows.contains(where: { $0.id == selectedRowID }) {
                self.selectedRowID = selectedRowID
            } else {
                self.selectedRowID = scene.rows.first?.id
            }
        } else {
            selectedRowID = nil
        }
    }

    private func sortByColumn(_ column: KWICColumnKey) {
        let nextSort: KWICSortMode
        switch column {
        case .sentenceIndex:
            nextSort = sortMode == .sentenceAscending ? .original : .sentenceAscending
        case .leftContext:
            nextSort = sortMode == .leftContextAscending ? .original : .leftContextAscending
        case .keyword:
            nextSort = sortMode == .keywordAscending ? .original : .keywordAscending
        case .rightContext:
            nextSort = sortMode == .rightContextAscending ? .original : .rightContextAscending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }

    private func toggleColumn(_ column: KWICColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func selectRow(_ rowID: String?) {
        guard let scene else {
            selectedRowID = nil
            return
        }
        guard let rowID else {
            selectedRowID = scene.rows.first?.id
            return
        }
        if scene.rows.contains(where: { $0.id == rowID }) {
            selectedRowID = rowID
        }
    }
}
