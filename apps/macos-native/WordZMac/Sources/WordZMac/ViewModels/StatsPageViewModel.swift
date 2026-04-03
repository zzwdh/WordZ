import Foundation

@MainActor
final class StatsPageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<StatsColumnKey> = [.word, .count, .normFrequency, .range]

    @Published var scene: StatsSceneModel?

    var metricDefinition: FrequencyMetricDefinition { definition }

    private let sceneBuilder: StatsSceneBuilder
    private var result: StatsResult?
    private var sortMode: StatsSortMode = .frequencyDescending
    private var pageSize: StatsPageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<StatsColumnKey> = StatsPageViewModel.defaultVisibleColumns
    private var definition = FrequencyMetricDefinition.default
    private var cachedSortedRows: [FrequencyRow]?
    private var cachedSortMode: StatsSortMode?
    private var cachedDefinition: FrequencyMetricDefinition?
    private var sceneBuildRevision = 0

    init(sceneBuilder: StatsSceneBuilder = StatsSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyFrequencyMetricDefinition(
            FrequencyMetricDefinition(
                normalizationUnit: snapshot.frequencyNormalizationUnit,
                rangeMode: snapshot.frequencyRangeMode
            )
        )
    }

    func apply(_ result: StatsResult) {
        self.result = result
        currentPage = 1
        invalidateSortedRowsCache()
        rebuildScene()
    }

    func applyFrequencyMetricDefinition(_ definition: FrequencyMetricDefinition) {
        guard self.definition != definition else { return }
        self.definition = definition
        currentPage = 1
        invalidateSortedRowsCache()
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
        case .changeNormalizationUnit(let unit):
            applyFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: definition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            applyFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: definition.normalizationUnit,
                    rangeMode: mode
                )
            )
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
        sceneBuildRevision += 1
        result = nil
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        definition = .default
        invalidateSortedRowsCache()
        scene = nil
    }

    private func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        sceneBuildRevision += 1
        let revision = sceneBuildRevision
        let resultSnapshot = result
        let definitionSnapshot = definition
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode

        guard result.frequencyRows.count >= LargeResultSceneBuildSupport.asyncThreshold else {
            let sortedRows = resolvedSortedRows(for: result)
            scene = sceneBuilder.build(
                from: result,
                definition: definition,
                sortMode: sortMode,
                pageSize: pageSize,
                currentPage: currentPage,
                visibleColumns: visibleColumns,
                languageMode: languageModeSnapshot,
                sortedRows: sortedRows
            )
            currentPage = scene?.pagination.currentPage ?? 1
            return
        }

        LargeResultSceneBuildSupport.queue.async { [sceneBuilder] in
            let sortedRows = sceneBuilder.sortedRows(
                from: resultSnapshot.frequencyRows,
                mode: sortSnapshot,
                definition: definitionSnapshot
            )
            let nextScene = sceneBuilder.build(
                from: resultSnapshot,
                definition: definitionSnapshot,
                sortMode: sortSnapshot,
                pageSize: pageSizeSnapshot,
                currentPage: currentPageSnapshot,
                visibleColumns: visibleColumnsSnapshot,
                languageMode: languageModeSnapshot,
                sortedRows: sortedRows
            )
            DispatchQueue.main.async {
                guard revision == self.sceneBuildRevision else { return }
                self.cachedSortedRows = sortedRows
                self.cachedSortMode = sortSnapshot
                self.cachedDefinition = definitionSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
            }
        }
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
        case .rank:
            nextSort = sortMode == .rankAscending ? .rankDescending : .rankAscending
        case .word:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        case .count, .normFrequency:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .range, .normRange:
            nextSort = sortMode == .rangeDescending ? .rangeAscending : .rangeDescending
        }
        guard sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        invalidateSortedRowsCache()
        rebuildScene()
    }

    private func resolvedSortedRows(for result: StatsResult) -> [FrequencyRow] {
        if let cachedSortedRows,
           cachedSortMode == sortMode,
           cachedDefinition == definition {
            return cachedSortedRows
        }
        let sortedRows = sceneBuilder.sortedRows(
            from: result.frequencyRows,
            mode: sortMode,
            definition: definition
        )
        cachedSortedRows = sortedRows
        cachedSortMode = sortMode
        cachedDefinition = definition
        return sortedRows
    }

    private func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
        cachedDefinition = nil
    }
}
