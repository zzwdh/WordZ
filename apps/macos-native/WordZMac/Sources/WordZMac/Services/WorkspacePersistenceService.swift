import Foundation

struct WorkspacePersistenceService {
    func buildDraft(
        selectedTab: WorkspaceDetailTab,
        selectedFolderID: String = "all",
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?,
        searchQuery: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        ngramSize: String,
        ngramPageSize: String,
        kwicLeftWindow: String,
        kwicRightWindow: String,
        collocateLeftWindow: String,
        collocateRightWindow: String,
        collocateMinFreq: String
    ) -> WorkspaceStateDraft {
        let corpusName = openedCorpus?.displayName ?? selectedCorpus?.name ?? ""
        let corpusID = selectedCorpus?.id ?? ""

        return WorkspaceStateDraft(
            currentTab: selectedTab.snapshotValue,
            currentLibraryFolderId: selectedFolderID,
            corpusIds: corpusID.isEmpty ? [] : [corpusID],
            corpusNames: corpusName.isEmpty ? [] : [corpusName],
            searchQuery: searchQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            ngramSize: ngramSize,
            ngramPageSize: ngramPageSize,
            kwicLeftWindow: kwicLeftWindow,
            kwicRightWindow: kwicRightWindow,
            collocateLeftWindow: collocateLeftWindow,
            collocateRightWindow: collocateRightWindow,
            collocateMinFreq: collocateMinFreq
        )
    }
}
