import Foundation

@MainActor
final class KWICPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSelectedRowControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<KWICColumnKey> = [.leftContext, .keyword, .rightContext]
    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

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
    @Published var scene: KWICSceneModel?
    @Published var selectedRowID: String?
    @Published var savedSets: [ConcordanceSavedSet] = []
    @Published var selectedSavedSetID: String? {
        didSet {
            guard oldValue != selectedSavedSetID else { return }
            syncSavedSetEditorState(resetFilter: true)
        }
    }
    @Published var savedSetFilterQuery = ""
    @Published var savedSetNotesDraft = ""
    var loadedSavedSetID: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: KWICSceneBuilder
    var result: KWICResult?
    var sortMode: KWICSortMode = .original
    var pageSize: KWICPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<KWICColumnKey> = KWICPageViewModel.defaultVisibleColumns
    var annotationState = WorkspaceAnnotationState.default
    var sceneBuildRevision = 0
    var cachedFilteredRows: [KWICRow]?
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedSortedRows: [KWICRow]?
    var cachedSortMode: KWICSortMode?

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

    var selectedSavedSet: ConcordanceSavedSet? {
        guard let selectedSavedSetID else { return savedSets.first }
        return savedSets.first(where: { $0.id == selectedSavedSetID }) ?? savedSets.first
    }

    var loadedSavedSet: ConcordanceSavedSet? {
        guard let loadedSavedSetID else { return nil }
        return savedSets.first(where: { $0.id == loadedSavedSetID })
    }

    var trimmedSavedSetFilterQuery: String {
        savedSetFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSavedSetFilter: Bool {
        !trimmedSavedSetFilterQuery.isEmpty
    }

    var filteredSelectedSavedSetRows: [ConcordanceSavedSetRow] {
        selectedSavedSet?.filteredRows(matching: savedSetFilterQuery) ?? []
    }

    var hasUnsavedSavedSetNotesChanges: Bool {
        normalizedSavedSetNotes(savedSetNotesDraft) != normalizedSavedSetNotes(selectedSavedSet?.notes)
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    func applyWorkspaceAnnotationState(_ state: WorkspaceAnnotationState) {
        guard annotationState != state else { return }
        annotationState = state
        rebuildScene()
    }

    func syncSavedSetEditorState(resetFilter: Bool) {
        if resetFilter {
            savedSetFilterQuery = ""
        }
        savedSetNotesDraft = selectedSavedSet?.notes ?? ""
    }

    func normalizedSavedSetNotes(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
