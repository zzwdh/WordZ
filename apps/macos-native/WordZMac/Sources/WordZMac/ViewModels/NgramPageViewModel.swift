import Foundation

@MainActor
final class NgramPageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<NgramColumnKey> = [.phrase, .count]
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
    @Published var ngramSize = "2" {
        didSet {
            guard oldValue != ngramSize else { return }
            handleInputChange(rebuildScene: false)
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
    private var visibleColumns: Set<NgramColumnKey> = NgramPageViewModel.defaultVisibleColumns
    private var sceneBuildRevision = 0

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
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
        ngramSize = snapshot.ngramSize
        if let matchedPageSize = NgramPageSize.allCases.first(where: { $0.title == snapshot.ngramPageSize }) {
            pageSize = matchedPageSize
        }
    }

    func apply(_ result: NgramResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        self.result = result
        ngramSize = "\(result.n)"
        currentPage = 1
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
        sceneBuildRevision += 1
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        ngramSize = "2"
        isEditingStopwords = false
        result = nil
        sortMode = .frequencyDescending
        pageSize = .oneHundred
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        scene = nil
    }

    var pageSizeSnapshotValue: String {
        pageSize.title
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
        sceneBuildRevision += 1
        let revision = sceneBuildRevision
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode

        guard result.rows.count >= LargeResultSceneBuildSupport.asyncThreshold else {
            scene = sceneBuilder.build(
                from: result,
                query: normalizedQuery,
                searchOptions: searchOptions,
                stopwordFilter: stopwordFilter,
                sortMode: sortMode,
                pageSize: pageSize,
                currentPage: currentPage,
                visibleColumns: visibleColumns,
                languageMode: languageModeSnapshot
            )
            currentPage = scene?.pagination.currentPage ?? 1
            return
        }

        let resultSnapshot = result
        let querySnapshot = normalizedQuery
        let optionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns

        LargeResultSceneBuildSupport.queue.async { [sceneBuilder] in
            let nextScene = sceneBuilder.build(
                from: resultSnapshot,
                query: querySnapshot,
                searchOptions: optionsSnapshot,
                stopwordFilter: stopwordSnapshot,
                sortMode: sortSnapshot,
                pageSize: pageSizeSnapshot,
                currentPage: currentPageSnapshot,
                visibleColumns: visibleColumnsSnapshot,
                languageMode: languageModeSnapshot
            )
            DispatchQueue.main.async {
                guard revision == self.sceneBuildRevision else { return }
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
            }
        }
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
