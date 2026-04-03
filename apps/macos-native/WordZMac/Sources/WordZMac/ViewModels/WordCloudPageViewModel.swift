import Foundation

@MainActor
final class WordCloudPageViewModel: ObservableObject {
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
    @Published var limit = 80 {
        didSet {
            guard oldValue != limit else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var scene: WordCloudSceneModel?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: WordCloudSceneBuilder
    private var result: WordCloudResult?
    private static let defaultVisibleColumns = Set(WordCloudColumnKey.allCases)
    private var visibleColumns: Set<WordCloudColumnKey>

    init(sceneBuilder: WordCloudSceneBuilder = WordCloudSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
        self.visibleColumns = Self.defaultVisibleColumns
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
        limit = snapshot.wordCloudLimit
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
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        limit = 80
        isEditingStopwords = false
        visibleColumns = Self.defaultVisibleColumns
        result = nil
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
            limit: limit,
            visibleColumns: visibleColumns,
            languageMode: WordZLocalization.shared.effectiveMode
        )
    }
}
