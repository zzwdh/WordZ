import Foundation

@MainActor
final class WordPageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<WordColumnKey> = [.word, .count, .normFrequency, .range]
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
    @Published var scene: WordSceneModel?

    var onInputChange: (() -> Void)?
    var metricDefinition: FrequencyMetricDefinition { definition }

    private let sceneBuilder: WordSceneBuilder
    private var result: StatsResult?
    private var sortMode: WordSortMode = .frequencyDescending
    private var pageSize: WordPageSize = .oneHundred
    private var currentPage = 1
    private var visibleColumns: Set<WordColumnKey> = WordPageViewModel.defaultVisibleColumns
    private var definition = FrequencyMetricDefinition.default
    private var cachedDisplayableRows: [FrequencyRow]?
    private var cachedFilteredRows: [FrequencyRow]?
    private var cachedFilteredError = ""
    private var cachedFilterQuery = ""
    private var cachedFilterOptions = SearchOptionsState.default
    private var cachedStopwordFilter = StopwordFilterState.default
    private var cachedSortedRows: [FrequencyRow]?
    private var cachedSortMode: WordSortMode?
    private var cachedDefinition: FrequencyMetricDefinition?
    private var sceneBuildRevision = 0

    init(sceneBuilder: WordSceneBuilder = WordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
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
        applyFrequencyMetricDefinition(
            FrequencyMetricDefinition(
                normalizationUnit: snapshot.frequencyNormalizationUnit,
                rangeMode: snapshot.frequencyRangeMode
            ),
            rebuildSceneAfterChange: false
        )
    }

    func apply(_ result: StatsResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        self.result = result
        currentPage = 1
        invalidateCaches()
    }

    func applyFrequencyMetricDefinition(
        _ definition: FrequencyMetricDefinition,
        rebuildSceneAfterChange: Bool = true
    ) {
        guard self.definition != definition else { return }
        self.definition = definition
        currentPage = 1
        invalidateSortedRowsCache()
        if rebuildSceneAfterChange {
            rebuildScene()
        }
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
        sceneBuildRevision += 1
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        isEditingStopwords = false
        result = nil
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        definition = .default
        invalidateCaches()
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

        sceneBuildRevision += 1
        let revision = sceneBuildRevision
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode

        guard result.frequencyRows.count >= LargeResultSceneBuildSupport.asyncThreshold else {
            let displayableRows = resolvedDisplayableRows(for: result)
            let filtered = resolvedFilteredRows(for: result)
            let sortedRows = resolvedSortedRows(filtered.rows)
            scene = sceneBuilder.build(
                from: result,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                searchOptions: searchOptions,
                stopwordFilter: stopwordFilter,
                definition: definition,
                sortMode: sortMode,
                pageSize: pageSize,
                currentPage: currentPage,
                visibleColumns: visibleColumns,
                languageMode: languageModeSnapshot,
                prefilteredDisplayableRows: displayableRows,
                filteredRows: filtered.rows,
                filteredError: filtered.error,
                sortedRows: sortedRows
            )
            currentPage = scene?.pagination.currentPage ?? 1
            return
        }

        let resultSnapshot = result
        let querySnapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let definitionSnapshot = definition
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns

        LargeResultSceneBuildSupport.queue.async { [sceneBuilder] in
            let displayableRows = sceneBuilder.displayableRows(from: resultSnapshot)
            let filtered = sceneBuilder.filterRows(
                from: displayableRows,
                query: querySnapshot,
                searchOptions: optionsSnapshot,
                stopwordFilter: stopwordSnapshot
            )
            let sortedRows = sceneBuilder.sortRows(
                filtered.rows,
                mode: sortSnapshot,
                definition: definitionSnapshot
            )
            let nextScene = sceneBuilder.build(
                from: resultSnapshot,
                query: querySnapshot,
                searchOptions: optionsSnapshot,
                stopwordFilter: stopwordSnapshot,
                definition: definitionSnapshot,
                sortMode: sortSnapshot,
                pageSize: pageSizeSnapshot,
                currentPage: currentPageSnapshot,
                visibleColumns: visibleColumnsSnapshot,
                languageMode: languageModeSnapshot,
                prefilteredDisplayableRows: displayableRows,
                filteredRows: filtered.rows,
                filteredError: filtered.error,
                sortedRows: sortedRows
            )
            DispatchQueue.main.async {
                guard revision == self.sceneBuildRevision else { return }
                self.cachedDisplayableRows = displayableRows
                self.cachedFilteredRows = filtered.rows
                self.cachedFilteredError = filtered.error
                self.cachedFilterQuery = querySnapshot
                self.cachedFilterOptions = optionsSnapshot
                self.cachedStopwordFilter = stopwordSnapshot
                self.cachedSortedRows = sortedRows
                self.cachedSortMode = sortSnapshot
                self.cachedDefinition = definitionSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
            }
        }
    }

    private func sortByColumn(_ column: WordColumnKey) {
        let nextSort: WordSortMode
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

    private func resolvedFilteredRows(for result: StatsResult) -> (rows: [FrequencyRow], error: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cachedFilteredRows,
           cachedFilterQuery == trimmedQuery,
           cachedFilterOptions == searchOptions,
           cachedStopwordFilter == stopwordFilter {
            return (cachedFilteredRows, cachedFilteredError)
        }
        let filtered = sceneBuilder.filterRows(
            from: result,
            query: trimmedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter
        )
        cachedFilteredRows = filtered.rows
        cachedFilteredError = filtered.error
        cachedFilterQuery = trimmedQuery
        cachedFilterOptions = searchOptions
        cachedStopwordFilter = stopwordFilter
        invalidateSortedRowsCache()
        return filtered
    }

    private func resolvedDisplayableRows(for result: StatsResult) -> [FrequencyRow] {
        if let cachedDisplayableRows {
            return cachedDisplayableRows
        }
        let rows = sceneBuilder.displayableRows(from: result)
        cachedDisplayableRows = rows
        return rows
    }

    private func resolvedSortedRows(_ rows: [FrequencyRow]) -> [FrequencyRow] {
        if let cachedSortedRows,
           cachedSortMode == sortMode,
           cachedDefinition == definition {
            return cachedSortedRows
        }
        let sortedRows = sceneBuilder.sortRows(rows, mode: sortMode, definition: definition)
        cachedSortedRows = sortedRows
        cachedSortMode = sortMode
        cachedDefinition = definition
        return sortedRows
    }

    private func invalidateCaches() {
        cachedDisplayableRows = nil
        cachedFilteredRows = nil
        cachedFilteredError = ""
        cachedFilterQuery = ""
        cachedFilterOptions = .default
        cachedStopwordFilter = .default
        invalidateSortedRowsCache()
    }

    private func invalidateSortedRowsCache() {
        cachedSortedRows = nil
        cachedSortMode = nil
        cachedDefinition = nil
    }
}
