import Foundation

extension EngineClient {
    func fetchAppInfo() async throws -> AppInfoSummary {
        let result = try await invokeResult(method: EngineContracts.Method.appGetInfo)
        return AppInfoSummary(json: JSONFieldReader.dictionary(result, key: "appInfo"))
    }

    func listLibrary(folderId: String = "all") async throws -> LibrarySnapshot {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryList,
            params: ["folderId": folderId]
        )
        return LibrarySnapshot(json: result)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryImportPaths,
            params: [
                "paths": paths,
                "folderId": folderId,
                "preserveHierarchy": preserveHierarchy
            ]
        )
        return LibraryImportResult(json: result)
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryOpenSaved,
            params: ["corpusId": corpusId]
        )
        return OpenedCorpus(json: result)
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRenameCorpus,
            params: [
                "corpusId": corpusId,
                "newName": newName
            ]
        )
        return LibraryCorpusItem(json: JSONFieldReader.dictionary(result, key: "item"))
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryMoveCorpus,
            params: [
                "corpusId": corpusId,
                "targetFolderId": targetFolderId
            ]
        )
        return LibraryCorpusItem(json: JSONFieldReader.dictionary(result, key: "item"))
    }

    func deleteCorpus(corpusId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryDeleteCorpus,
            params: ["corpusId": corpusId]
        )
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryCreateFolder,
            params: ["folderName": name]
        )
        return LibraryFolderItem(json: JSONFieldReader.dictionary(result, key: "folder"))
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRenameFolder,
            params: [
                "folderId": folderId,
                "newName": newName
            ]
        )
        return LibraryFolderItem(json: JSONFieldReader.dictionary(result, key: "folder"))
    }

    func deleteFolder(folderId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryDeleteFolder,
            params: ["folderId": folderId]
        )
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        let result = try await invokeResult(method: EngineContracts.Method.libraryListRecycleBin)
        return RecycleBinSnapshot(json: result)
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryRestoreRecycleEntry,
            params: ["recycleEntryId": recycleEntryId]
        )
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryPurgeRecycleEntry,
            params: ["recycleEntryId": recycleEntryId]
        )
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryBackup,
            params: ["destinationPath": destinationPath]
        )
        return LibraryBackupSummary(json: result)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRestore,
            params: ["sourcePath": sourcePath]
        )
        return LibraryRestoreSummary(json: result)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        let result = try await invokeResult(method: EngineContracts.Method.libraryRepair)
        return LibraryRepairSummary(json: result)
    }
}
