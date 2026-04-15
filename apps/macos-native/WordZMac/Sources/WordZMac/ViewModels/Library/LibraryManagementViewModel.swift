import Foundation

@MainActor
final class LibraryManagementViewModel: ObservableObject {
    @Published var selectedCorpusSetID: String? {
        didSet { syncScene() }
    }
    @Published var selectedFolderID: String? {
        didSet { syncScene() }
    }
    @Published var selectedCorpusID: String? {
        didSet {
            if corpusInfoSheet?.id != selectedCorpusID {
                corpusInfoSheet = nil
            }
            if metadataEditorSheet?.isBatchEdit == true {
                if selectedCorpusIDs.count < 2 {
                    metadataEditorSheet = nil
                }
            } else if metadataEditorSheet?.id != selectedCorpusID {
                metadataEditorSheet = nil
            }
            syncScene()
        }
    }
    @Published var selectedCorpusIDs: Set<String> = [] {
        didSet {
            if metadataEditorSheet?.isBatchEdit == true, selectedCorpusIDs.count < 2 {
                metadataEditorSheet = nil
            }
            syncScene()
        }
    }
    @Published var selectedRecycleEntryID: String? {
        didSet { syncScene() }
    }
    @Published var preserveHierarchy = true {
        didSet { syncScene() }
    }
    @Published var searchQuery = "" {
        didSet {
            guard oldValue != searchQuery else { return }
            normalizeCorpusSelectionForCurrentState()
            syncScene()
        }
    }
    @Published var metadataFilterState = CorpusMetadataFilterState.empty {
        didSet { syncScene() }
    }
    @Published var importProgressSnapshot: LibraryImportProgressSnapshot? {
        didSet { syncScene() }
    }
    @Published var corpusInfoSheet: LibraryCorpusInfoSceneModel?
    @Published var importSummarySheet: LibraryImportSummarySceneModel?
    @Published var metadataEditorSheet: LibraryCorpusMetadataEditorSceneModel?
    @Published var librarySnapshot = LibrarySnapshot.empty
    @Published var recycleSnapshot = RecycleBinSnapshot.empty
    @Published var scene = LibraryManagementSceneModel.empty

    var context = WorkspaceSceneContext.empty
    var statusMessage = ""
    var isBusy = false
    var isSyncingCorpusSelection = false
    var showsRecycleBin = false {
        didSet { syncScene() }
    }
    var recentCorpusSetIDs: [String] = [] {
        didSet { syncScene() }
    }

    var selectedFolder: LibraryFolderItem? {
        guard let selectedFolderID else { return nil }
        return librarySnapshot.folders.first(where: { $0.id == selectedFolderID })
    }

    var selectedCorpusSet: LibraryCorpusSetItem? {
        guard let selectedCorpusSetID else { return nil }
        return librarySnapshot.corpusSets.first(where: { $0.id == selectedCorpusSetID })
    }

    var recentCorpusSets: [LibraryCorpusSetItem] {
        CorpusSetRecentsSupport.recentCorpusSets(
            from: librarySnapshot.corpusSets,
            recentIDs: recentCorpusSetIDs
        )
    }

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    var selectedRecycleEntry: RecycleBinEntry? {
        guard let selectedRecycleEntryID else { return nil }
        return recycleSnapshot.entries.first(where: { $0.id == selectedRecycleEntryID })
    }

    var selectedCorpora: [LibraryCorpusItem] {
        librarySnapshot.corpora.filter { selectedCorpusIDs.contains($0.id) }
    }

    var filteredCorpora: [LibraryCorpusItem] {
        librarySnapshot.corpora.filter { corpus in
            let corpusSetMatches = selectedCorpusSet == nil || selectedCorpusSet?.corpusIDs.contains(corpus.id) == true
            let folderMatches = selectedFolderID == nil || corpus.folderId == selectedFolderID
            let metadataMatches = metadataFilterState.isEmpty || metadataFilterState.matches(corpus.metadata)
            let searchMatches = matchesSearchQuery(corpus)
            return corpusSetMatches && folderMatches && metadataMatches && searchMatches
        }
    }

    var saveableCorpusSetMembers: [LibraryCorpusItem] {
        let preferredMembers = selectedCorpora
        if !preferredMembers.isEmpty {
            return preferredMembers
        }
        return filteredCorpora
    }

    var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSearchQuery: Bool {
        !normalizedSearchQuery.isEmpty
    }

    func matchesSearchQuery(_ corpus: LibraryCorpusItem) -> Bool {
        guard hasSearchQuery else { return true }
        let searchableFields = [
            corpus.name,
            corpus.folderName,
            corpus.sourceType,
            corpus.metadata.sourceLabel,
            corpus.metadata.yearLabel,
            corpus.metadata.genreLabel,
            corpus.metadata.tagsText
        ]
        return searchableFields.contains {
            $0.localizedCaseInsensitiveContains(normalizedSearchQuery)
        }
    }

    func matchesSearchQuery(_ folder: LibraryFolderItem) -> Bool {
        guard hasSearchQuery else { return true }
        return folder.name.localizedCaseInsensitiveContains(normalizedSearchQuery)
    }

    func matchesSearchQuery(
        _ corpusSet: LibraryCorpusSetItem,
        corporaByID: [String: LibraryCorpusItem]
    ) -> Bool {
        guard hasSearchQuery else { return true }
        if corpusSet.name.localizedCaseInsensitiveContains(normalizedSearchQuery) {
            return true
        }
        if corpusSet.metadataFilterState.summaryText(in: WordZLocalization.shared.effectiveMode)?
            .localizedCaseInsensitiveContains(normalizedSearchQuery) == true {
            return true
        }
        return corpusSet.corpusIDs.contains { corpusID in
            guard let corpus = corporaByID[corpusID] else { return false }
            return corpus.name.localizedCaseInsensitiveContains(normalizedSearchQuery)
        }
    }

    func matchesSearchQuery(_ recycleEntry: RecycleBinEntry) -> Bool {
        guard hasSearchQuery else { return true }
        let searchableFields = [
            recycleEntry.name,
            recycleEntry.type,
            recycleEntry.originalFolderName,
            recycleEntry.deletedAt
        ]
        return searchableFields.contains {
            $0.localizedCaseInsensitiveContains(normalizedSearchQuery)
        }
    }
}
