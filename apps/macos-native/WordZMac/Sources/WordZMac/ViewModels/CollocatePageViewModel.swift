import Foundation

private struct CollocateRunConfiguration: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let leftWindow: Int
    let rightWindow: Int
    let minFreq: Int
}

@MainActor
final class CollocatePageViewModel: ObservableObject {
    private static let defaultVisibleColumns: Set<CollocateColumnKey> = [.word, .total, .logDice, .rate]
    private var isApplyingState = false

    @Published var keyword = "" {
        didSet {
            guard oldValue != keyword else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var leftWindow = "5" {
        didSet {
            guard oldValue != leftWindow else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var rightWindow = "5" {
        didSet {
            guard oldValue != rightWindow else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var minFreq = "1" {
        didSet {
            guard oldValue != minFreq else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: CollocateSceneModel?
    @Published private(set) var selectedRowID: String?

    var onInputChange: (() -> Void)?
    private let sceneBuilder: CollocateSceneBuilder
    private var result: CollocateResult?
    private var sortMode: CollocateSortMode = .logDiceDescending
    private var pageSize: CollocatePageSize = .fifty
    private var currentPage = 1
    private var visibleColumns: Set<CollocateColumnKey> = CollocatePageViewModel.defaultVisibleColumns
    private var focusMetric: CollocateAssociationMetric = .logDice
    private var lastRunConfiguration: CollocateRunConfiguration?

    init(sceneBuilder: CollocateSceneBuilder = CollocateSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    var minFreqValue: Int {
        Int(minFreq) ?? 1
    }

    var focusMetricValue: CollocateAssociationMetric {
        focusMetric
    }

    var hasPendingRunChanges: Bool {
        guard let lastRunConfiguration else { return false }
        return lastRunConfiguration.query != normalizedKeyword
            || lastRunConfiguration.leftWindow != leftWindowValue
            || lastRunConfiguration.rightWindow != rightWindowValue
            || lastRunConfiguration.minFreq != minFreqValue
            || lastRunConfiguration.searchOptions != searchOptions
    }

    var selectedSceneRow: CollocateSceneRow? {
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
        keyword = snapshot.searchQuery
        leftWindow = snapshot.collocateLeftWindow
        rightWindow = snapshot.collocateRightWindow
        minFreq = snapshot.collocateMinFreq
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: CollocateResult) {
        self.result = result
        currentPage = 1
        rebuildScene()
    }

    func recordPendingRunConfiguration() {
        lastRunConfiguration = currentRunConfiguration
    }

    func handle(_ action: CollocatePageAction) {
        switch action {
        case .run:
            return
        case .applyPreset(let preset):
            applyPreset(preset)
        case .changeFocusMetric(let nextMetric):
            changeFocusMetric(nextMetric)
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
            selectedRowID = rowID
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
        keyword = ""
        leftWindow = "5"
        rightWindow = "5"
        minFreq = "1"
        searchOptions = .default
        stopwordFilter = .default
        isEditingStopwords = false
        result = nil
        sortMode = .logDiceDescending
        pageSize = .fifty
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        focusMetric = .logDice
        selectedRowID = nil
        lastRunConfiguration = nil
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
        let configuration = lastRunConfiguration ?? currentRunConfiguration
        scene = sceneBuilder.build(
            from: result,
            query: configuration.query,
            searchOptions: configuration.searchOptions,
            stopwordFilter: stopwordFilter,
            focusMetric: focusMetric,
            leftWindow: configuration.leftWindow,
            rightWindow: configuration.rightWindow,
            minFreq: configuration.minFreq,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns
        )
        currentPage = scene?.pagination.currentPage ?? 1
        syncSelectedRow()
    }

    private var currentRunConfiguration: CollocateRunConfiguration {
        CollocateRunConfiguration(
            query: normalizedKeyword,
            searchOptions: searchOptions,
            leftWindow: leftWindowValue,
            rightWindow: rightWindowValue,
            minFreq: minFreqValue
        )
    }

    private func sortByColumn(_ column: CollocateColumnKey) {
        let nextSort: CollocateSortMode?
        switch column {
        case .rank:
            nextSort = .frequencyDescending
        case .word:
            nextSort = .alphabeticalAscending
        case .total:
            nextSort = sortMode == .frequencyDescending ? .frequencyAscending : .frequencyDescending
        case .logDice:
            nextSort = .logDiceDescending
        case .mutualInformation:
            nextSort = .mutualInformationDescending
        case .tScore:
            nextSort = .tScoreDescending
        case .rate:
            nextSort = .rateDescending
        case .left, .right, .wordFreq, .keywordFreq:
            nextSort = nil
        }
        guard let nextSort, sortMode != nextSort else { return }
        sortMode = nextSort
        currentPage = 1
        rebuildScene()
    }

    private func toggleColumn(_ column: CollocateColumnKey) {
        if visibleColumns.contains(column) {
            guard visibleColumns.count > 1 else { return }
            visibleColumns.remove(column)
        } else {
            visibleColumns.insert(column)
        }
        rebuildScene()
    }

    private func changeFocusMetric(_ nextMetric: CollocateAssociationMetric) {
        guard focusMetric != nextMetric else { return }
        focusMetric = nextMetric
        switch nextMetric {
        case .logDice:
            sortMode = .logDiceDescending
            visibleColumns.insert(.logDice)
        case .mutualInformation:
            sortMode = .mutualInformationDescending
            visibleColumns.insert(.mutualInformation)
        case .tScore:
            sortMode = .tScoreDescending
            visibleColumns.insert(.tScore)
        case .rate:
            sortMode = .rateDescending
            visibleColumns.insert(.rate)
        case .frequency:
            sortMode = .frequencyDescending
            visibleColumns.insert(.total)
        }
        currentPage = 1
        rebuildScene()
    }

    private func applyPreset(_ preset: CollocatePreset) {
        let configuration = preset.configuration
        isApplyingState = true
        leftWindow = configuration.leftWindow
        rightWindow = configuration.rightWindow
        minFreq = configuration.minFreq
        isApplyingState = false
        onInputChange?()
        changeFocusMetric(configuration.metric)
    }

    private func syncSelectedRow() {
        guard let scene else {
            selectedRowID = nil
            return
        }
        if let selectedRowID,
           scene.rows.contains(where: { $0.id == selectedRowID }) {
            return
        }
        selectedRowID = scene.rows.first?.id
    }
}
