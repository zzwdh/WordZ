import Foundation

@MainActor
final class LibrarySidebarViewModel: ObservableObject {
    @Published var librarySnapshot = LibrarySnapshot.empty {
        didSet {
            if let selectedCorpusSetID, !librarySnapshot.corpusSets.contains(where: { $0.id == selectedCorpusSetID }) {
                self.selectedCorpusSetID = nil
            }
            _ = normalizeSelectionForCurrentFilters()
            syncScene()
        }
    }
    @Published var selectedCorpusSetID: String? {
        didSet { syncScene() }
    }
    @Published var selectedCorpusID: String? {
        didSet {
            guard oldValue != selectedCorpusID else { return }
            syncScene()
            if !isApplyingMetadataFilterSelection && suppressedSelectionChangeDepth == 0 {
                onSelectionChange?()
            }
        }
    }
    @Published var metadataSourceQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataSourceQuery) }
    }
    @Published var metadataYearQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataYearQuery) }
    }
    @Published var metadataGenreQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataGenreQuery) }
    }
    @Published var metadataTagsQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataTagsQuery) }
    }
    @Published var engineStatus = wordZText("正在连接本地引擎...", "Connecting to local engine…", mode: .system)
    @Published var lastErrorMessage = ""
    @Published var scene = WorkspaceSidebarSceneModel.empty

    var onSelectionChange: (() -> Void)?
    var onMetadataFilterChange: ((Bool) -> Void)?

    var context = WorkspaceSceneContext.empty
    var isBusy = false
    var isApplyingMetadataFilterSelection = false
    var isApplyingMetadataFilterState = false
    var engineState: WorkspaceSidebarEngineState = .connecting
    var activeAnalysisTab: WorkspaceDetailTab = .stats
    var workflowTargetCorpusID: String?
    var workflowReferenceCorpusID: String?
    var resultsSummary: WorkspaceSidebarResultsSceneModel?
    private var suppressedSelectionChangeDepth = 0

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    var selectedCorpusSet: LibraryCorpusSetItem? {
        guard let selectedCorpusSetID else { return nil }
        return librarySnapshot.corpusSets.first(where: { $0.id == selectedCorpusSetID })
    }

    func setSelectedCorpusID(
        _ corpusID: String?,
        notifySelectionChange: Bool
    ) {
        guard !notifySelectionChange else {
            selectedCorpusID = corpusID
            return
        }
        suppressedSelectionChangeDepth += 1
        defer { suppressedSelectionChangeDepth -= 1 }
        selectedCorpusID = corpusID
    }
}
