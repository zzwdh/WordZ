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
    @Published var metadataFilterState = CorpusMetadataFilterState.empty {
        didSet { syncScene() }
    }
    @Published var importProgressSnapshot: LibraryImportProgressSnapshot? {
        didSet { syncScene() }
    }
    @Published var corpusInfoSheet: LibraryCorpusInfoSceneModel?
    @Published var metadataEditorSheet: LibraryCorpusMetadataEditorSceneModel?
    @Published var librarySnapshot = LibrarySnapshot.empty
    @Published var recycleSnapshot = RecycleBinSnapshot.empty
    @Published var scene = LibraryManagementSceneModel.empty

    var context = WorkspaceSceneContext.empty
    var statusMessage = ""
    var isBusy = false
    var isSyncingCorpusSelection = false

    var selectedFolder: LibraryFolderItem? {
        guard let selectedFolderID else { return nil }
        return librarySnapshot.folders.first(where: { $0.id == selectedFolderID })
    }

    var selectedCorpusSet: LibraryCorpusSetItem? {
        guard let selectedCorpusSetID else { return nil }
        return librarySnapshot.corpusSets.first(where: { $0.id == selectedCorpusSetID })
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
            return corpusSetMatches && folderMatches && metadataMatches
        }
    }

    var saveableCorpusSetMembers: [LibraryCorpusItem] {
        let preferredMembers = selectedCorpora
        if !preferredMembers.isEmpty {
            return preferredMembers
        }
        return filteredCorpora
    }
}
