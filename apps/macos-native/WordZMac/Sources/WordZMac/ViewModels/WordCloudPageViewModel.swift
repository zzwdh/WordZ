import Foundation

@MainActor
final class WordCloudPageViewModel: ObservableObject {
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
    @Published var limit = 80 {
        didSet {
            guard oldValue != limit else { return }
            onInputChange?()
        }
    }
    @Published var scene: WordCloudSceneModel?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: WordCloudSceneBuilder
    private var result: WordCloudResult?
    private var visibleColumns: Set<WordCloudColumnKey> = Set(WordCloudColumnKey.allCases)

    init(sceneBuilder: WordCloudSceneBuilder = WordCloudSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: WordCloudResult) {
        self.result = result
        rebuildScene()
    }

    func handle(_ action: WordCloudPageAction) {
        switch action {
        case .run:
            return
        case .changeLimit(let nextLimit):
            let normalized = max(10, min(nextLimit, 200))
            guard limit != normalized else { return }
            limit = normalized
            rebuildScene()
        case .toggleColumn(let column):
            if visibleColumns.contains(column) {
                guard visibleColumns.count > 1 else { return }
                visibleColumns.remove(column)
            } else {
                visibleColumns.insert(column)
            }
            rebuildScene()
        }
    }

    func reset() {
        result = nil
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
            limit: limit,
            visibleColumns: visibleColumns
        )
    }
}
