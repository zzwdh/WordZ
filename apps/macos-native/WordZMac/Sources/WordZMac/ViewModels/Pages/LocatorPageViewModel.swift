import Foundation

@MainActor
final class LocatorPageViewModel: ObservableObject, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<LocatorColumnKey> = [.sentenceId, .status, .text]
    @Published var leftWindow = "5"
    @Published var rightWindow = "5"
    @Published var source: LocatorSource?
    @Published var scene: LocatorSceneModel?
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

    let sceneBuilder: LocatorSceneBuilder
    var result: LocatorResult?
    var pageSize: LocatorPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<LocatorColumnKey> = LocatorPageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0

    init(sceneBuilder: LocatorSceneBuilder = LocatorSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    var hasSource: Bool {
        currentSource != nil
    }

    var currentSource: LocatorSource? {
        source
    }

    var selectedSceneRow: LocatorSceneRow? {
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
