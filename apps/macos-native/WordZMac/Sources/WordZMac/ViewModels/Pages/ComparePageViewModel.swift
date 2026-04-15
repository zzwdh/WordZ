import Foundation

@MainActor
final class ComparePageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling, AnalysisSelectedRowControlling {
    static let defaultVisibleColumns: Set<CompareColumnKey> = [.word, .keyness, .effect, .dominantCorpus]
    static let automaticReferenceOptionID = ""
    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

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
    @Published var selectionItems: [CompareSelectableCorpusSceneItem] = []
    @Published var referenceOptions: [CompareReferenceOptionSceneItem] = []
    @Published var scene: CompareSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?

    let sceneBuilder: CompareSceneBuilder
    var result: CompareResult?
    var sortMode: CompareSortMode = .keynessDescending
    var pageSize: ComparePageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<CompareColumnKey> = ComparePageViewModel.defaultVisibleColumns
    var availableCorpora: [LibraryCorpusItem] = []
    var availableCorpusSets: [LibraryCorpusSetItem] = []
    var selectedCorpusIDs: Set<String> = []
    var selectedReferenceSelection: CompareReferenceSelection = .automatic
    var sceneBuildRevision = 0
    var cachedFilteredRows: [CompareRow]?
    var cachedFilteredError = ""
    var cachedFilterQuery = ""
    var cachedFilterOptions = SearchOptionsState.default
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedDerivedRows: [DerivedCompareRow]?
    var cachedDerivedReferenceSelection: CompareReferenceSelection?
    var cachedDerivedReferenceCorpusSets: [LibraryCorpusSetItem] = []
    var cachedDerivedLanguageMode: AppLanguageMode?
    var cachedSortedRows: [DerivedCompareRow]?
    var cachedSortMode: CompareSortMode?

    init(sceneBuilder: CompareSceneBuilder = CompareSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var selectedCorpusCount: Int {
        selectedCorpusIDs.count
    }

    var selectedCorpusIDsSnapshot: [String] {
        let visibleSelection = selectionItems.filter(\.isSelected).map(\.id)
        if !visibleSelection.isEmpty {
            return visibleSelection
        }
        let orderedAvailableIDs = availableCorpora.map(\.id).filter { selectedCorpusIDs.contains($0) }
        if !orderedAvailableIDs.isEmpty {
            return orderedAvailableIDs
        }
        return Array(selectedCorpusIDs).sorted()
    }

    var selectedReferenceOptionID: String {
        selectedReferenceSelection.optionID
    }

    var selectedReferenceCorpusIDSnapshot: String {
        selectedReferenceSelection.snapshotValue
    }

    var selectedReferenceCorpusID: String? {
        selectedReferenceSelection.corpusID
    }

    var selectedReferenceCorpusSetID: String? {
        selectedReferenceSelection.corpusSetID
    }

    var selectedSceneRow: CompareSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    func isCorpusSelected(_ corpusID: String) -> Bool {
        selectedCorpusIDs.contains(corpusID)
    }

    func selectedCorpusItems() -> [LibraryCorpusItem] {
        availableCorpora.filter { selectedCorpusIDs.contains($0.id) }
    }

    func selectedReferenceCorpusSet() -> LibraryCorpusSetItem? {
        guard let selectedReferenceCorpusSetID else { return nil }
        return availableCorpusSets.first(where: { $0.id == selectedReferenceCorpusSetID })
    }

    func selectedTargetCorpusItems() -> [LibraryCorpusItem] {
        switch selectedReferenceSelection {
        case .automatic:
            return selectedCorpusItems()
        case .corpus(let corpusID):
            return selectedCorpusItems().filter { $0.id != corpusID }
        case .corpusSet:
            let referenceIDs = selectedReferenceCorpusSet().map { Set($0.corpusIDs) } ?? []
            return selectedCorpusItems().filter { !referenceIDs.contains($0.id) }
        }
    }
}
