import Foundation

@MainActor
final class StatsPageViewModel: ObservableObject {
    @Published var scene: StatsSceneModel?

    private let sceneBuilder: StatsSceneBuilder
    private var result: StatsResult?
    private var sortMode: StatsSortMode = .frequencyDescending
    private var pageSize: StatsPageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<StatsColumnKey> = Set(StatsColumnKey.allCases)

    init(sceneBuilder: StatsSceneBuilder = StatsSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    func apply(_ result: StatsResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func handle(_ action: StatsPageAction) {
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
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    private func toggleColumn(_ column: StatsColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func sortByColumn(_ column: StatsColumnKey) {
        let nextSort: StatsSortMode
        switch column {
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
