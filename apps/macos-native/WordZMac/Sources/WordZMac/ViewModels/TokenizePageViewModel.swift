import Foundation

@MainActor
final class TokenizePageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<TokenizeColumnKey> = [.sentence, .original, .normalized]
    private var isApplyingState = false

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
    @Published var isEditingStopwords = false
    @Published var scene: TokenizeSceneModel?
    @Published private(set) var selectedRowID: String?

    var onInputChange: (() -> Void)?

    private let sceneBuilder: TokenizeSceneBuilder
    private var result: TokenizeResult?
    private var sortMode: TokenizeSortMode = .sequenceAscending
    private var pageSize: TokenizePageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<TokenizeColumnKey> = TokenizePageViewModel.defaultVisibleColumns

    init(sceneBuilder: TokenizeSceneBuilder = TokenizeSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var exportDocument: PlainTextExportDocument? {
        scene?.exportDocument
    }

    var selectedSceneRow: TokenizeSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: TokenizeResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: TokenizePageAction) {
        switch action {
        case .run, .exportText:
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
        case .selectRow(let rowID):
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
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        isEditingStopwords = false
        result = nil
        sortMode = .sequenceAscending
        pageSize = .oneHundred
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        selectedRowID = nil
        scene = nil
    }

    private func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        guard !isApplyingState else { return }
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
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
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

    private func sortByColumn(_ column: TokenizeColumnKey) {
        let nextSort: TokenizeSortMode
        switch column {
        case .sentence, .position:
            nextSort = sortMode == .sequenceAscending ? .sequenceDescending : .sequenceAscending
        case .original:
            nextSort = sortMode == .originalAscending ? .originalDescending : .originalAscending
        case .normalized:
            nextSort = sortMode == .normalizedAscending ? .normalizedDescending : .normalizedAscending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
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
