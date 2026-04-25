import Foundation

typealias LibraryImportProgressHandler = @Sendable (LibraryImportProgressSnapshot) -> Void
typealias LibraryImportCancellationHandler = @Sendable () -> Bool
typealias LibraryCorpusCleaningProgressHandler = @Sendable (LibraryCorpusCleaningProgressSnapshot) -> Void
typealias LibraryCorpusCleaningCancellationHandler = @Sendable () -> Bool

protocol LibraryStore: AnyObject {
    func ensureInitialized() throws
    func listLibrary(folderId: String) throws -> LibrarySnapshot
    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) throws -> LibraryImportResult
    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus
    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary
    func cleanCorpora(corpusIds: [String]) throws -> LibraryCorpusCleaningBatchResult
    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) throws -> LibraryCorpusItem
    func renameCorpus(corpusId: String, newName: String) throws -> LibraryCorpusItem
    func moveCorpus(corpusId: String, targetFolderId: String) throws -> LibraryCorpusItem
    func deleteCorpus(corpusId: String) throws
    func createFolder(name: String) throws -> LibraryFolderItem
    func renameFolder(folderId: String, newName: String) throws -> LibraryFolderItem
    func deleteFolder(folderId: String) throws
    func listRecycleBin() throws -> RecycleBinSnapshot
    func restoreRecycleEntry(recycleEntryId: String) throws
    func purgeRecycleEntry(recycleEntryId: String) throws
    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary
    func restoreLibrary(sourcePath: String) throws -> LibraryRestoreSummary
    func repairLibrary() throws -> LibraryRepairSummary
}

protocol ProgressReportingLibraryStore: LibraryStore {
    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        progress: LibraryImportProgressHandler?,
        isCancelled: LibraryImportCancellationHandler?
    ) throws -> LibraryImportResult
}

protocol CorpusCleaningProgressReportingLibraryStore: LibraryStore {
    func cleanCorpora(
        corpusIds: [String],
        progress: LibraryCorpusCleaningProgressHandler?,
        isCancelled: LibraryCorpusCleaningCancellationHandler?
    ) throws -> LibraryCorpusCleaningBatchResult
}

protocol StoredFrequencyArtifactProvidingLibraryStore: LibraryStore {
    func loadStoredFrequencyArtifact(corpusId: String) throws -> StoredFrequencyArtifact?
}

protocol StoredTokenizedArtifactProvidingLibraryStore: LibraryStore {
    func loadStoredTokenizedArtifact(corpusId: String) throws -> StoredTokenizedArtifact?
}

protocol StoredTokenPositionIndexProvidingLibraryStore: LibraryStore {
    func loadStoredTokenPositionIndex(corpusId: String) throws -> StoredTokenPositionIndexArtifact?
}

protocol StoredSentenceSearchProvidingLibraryStore: LibraryStore {
    func loadCandidateSentenceIDs(corpusId: String, phraseTokens: [String]) throws -> [Int]
}

protocol StoredLocatorProvidingLibraryStore: LibraryStore {
    func loadStoredLocatorResult(
        corpusId: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) throws -> LocatorResult?
}

protocol CorpusSetManagingLibraryStore: LibraryStore {
    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) throws -> LibraryCorpusSetItem
    func deleteCorpusSet(corpusSetID: String) throws
}

protocol MetadataFilteringLibraryStore: LibraryStore {
    func listLibrary(
        folderId: String,
        metadataFilterState: CorpusMetadataFilterState
    ) throws -> LibrarySnapshot
}

protocol FullTextSearchingLibraryStore: MetadataFilteringLibraryStore {
    func listLibrary(
        folderId: String,
        metadataFilterState: CorpusMetadataFilterState,
        searchQuery: String
    ) throws -> LibrarySnapshot
}
