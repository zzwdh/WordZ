import Foundation

typealias LibraryImportProgressHandler = @Sendable (LibraryImportProgressSnapshot) -> Void
typealias LibraryImportCancellationHandler = @Sendable () -> Bool

protocol LibraryStore: AnyObject {
    func ensureInitialized() throws
    func listLibrary(folderId: String) throws -> LibrarySnapshot
    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) throws -> LibraryImportResult
    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus
    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary
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

protocol CorpusSetManagingLibraryStore: LibraryStore {
    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) throws -> LibraryCorpusSetItem
    func deleteCorpusSet(corpusSetID: String) throws
}
