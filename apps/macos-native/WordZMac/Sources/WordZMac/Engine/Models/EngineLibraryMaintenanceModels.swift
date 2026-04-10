import Foundation

struct RecycleBinEntry: Identifiable, Equatable, Sendable {
    let recycleEntryId: String
    let type: String
    let deletedAt: String
    let name: String
    let originalFolderName: String
    let sourceType: String
    let itemCount: Int

    var id: String { recycleEntryId }

    init(json: JSONObject) {
        self.recycleEntryId = JSONFieldReader.string(json, key: "recycleEntryId")
        self.type = JSONFieldReader.string(json, key: "type", fallback: "corpus")
        self.deletedAt = JSONFieldReader.string(json, key: "deletedAt")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未命名项目")
        self.originalFolderName = JSONFieldReader.string(json, key: "originalFolderName", fallback: "未分类")
        self.sourceType = JSONFieldReader.string(json, key: "sourceType", fallback: "txt")
        self.itemCount = JSONFieldReader.int(json, key: "itemCount")
    }
}

struct RecycleBinSnapshot: Equatable, Sendable {
    let entries: [RecycleBinEntry]
    let folderCount: Int
    let corpusCount: Int
    let totalCount: Int

    static let empty = RecycleBinSnapshot(entries: [], folderCount: 0, corpusCount: 0, totalCount: 0)

    init(entries: [RecycleBinEntry], folderCount: Int, corpusCount: Int, totalCount: Int) {
        self.entries = entries
        self.folderCount = folderCount
        self.corpusCount = corpusCount
        self.totalCount = totalCount
    }

    init(json: JSONObject) {
        self.entries = JSONFieldReader.array(json, key: "entries")
            .compactMap { $0 as? JSONObject }
            .map(RecycleBinEntry.init)
        self.folderCount = JSONFieldReader.int(json, key: "folderCount")
        self.corpusCount = JSONFieldReader.int(json, key: "corpusCount")
        self.totalCount = JSONFieldReader.int(json, key: "totalCount")
    }
}

struct LibraryImportFailureItem: Equatable, Sendable {
    let path: String
    let fileName: String
    let reason: String

    init(path: String, fileName: String, reason: String) {
        self.path = path
        self.fileName = fileName
        self.reason = reason
    }

    init(json: JSONObject) {
        self.path = JSONFieldReader.string(json, key: "path")
        self.fileName = JSONFieldReader.string(json, key: "fileName")
        self.reason = JSONFieldReader.string(json, key: "reason")
    }

    var jsonObject: JSONObject {
        [
            "path": path,
            "fileName": fileName,
            "reason": reason
        ]
    }
}

enum LibraryImportProgressPhase: String, Equatable, Sendable {
    case preparing
    case importing
    case committing
    case completed
}

struct LibraryImportProgressSnapshot: Equatable, Sendable {
    let phase: LibraryImportProgressPhase
    let totalCount: Int
    let completedCount: Int
    let importedCount: Int
    let skippedCount: Int
    let currentPath: String
    let currentName: String

    var progress: Double {
        guard totalCount > 0 else {
            return phase == .completed ? 1 : 0
        }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }
}

struct LibraryImportResult: Equatable, Sendable {
    let importedCount: Int
    let skippedCount: Int
    let importedItems: [LibraryCorpusItem]
    let failureItems: [LibraryImportFailureItem]
    let cancelled: Bool

    init(json: JSONObject) {
        self.importedCount = JSONFieldReader.int(json, key: "importedCount")
        self.skippedCount = JSONFieldReader.int(json, key: "skippedCount")
        self.importedItems = JSONFieldReader.array(json, key: "importedItems")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusItem.init)
        self.failureItems = JSONFieldReader.array(json, key: "failureItems")
            .compactMap { $0 as? JSONObject }
            .map(LibraryImportFailureItem.init)
        self.cancelled = JSONFieldReader.bool(json, key: "cancelled")
    }
}

struct LibraryBackupSummary: Equatable, Sendable {
    let backupDir: String
    let folderCount: Int
    let corpusCount: Int

    init(json: JSONObject) {
        self.backupDir = JSONFieldReader.string(json, key: "backupDir")
        self.folderCount = JSONFieldReader.int(json, key: "folderCount")
        self.corpusCount = JSONFieldReader.int(json, key: "corpusCount")
    }
}

struct LibraryRestoreSummary: Equatable, Sendable {
    let restoredFromDir: String
    let previousLibraryBackupDir: String
    let folderCount: Int
    let corpusCount: Int

    init(json: JSONObject) {
        self.restoredFromDir = JSONFieldReader.string(json, key: "restoredFromDir")
        self.previousLibraryBackupDir = JSONFieldReader.string(json, key: "previousLibraryBackupDir")
        self.folderCount = JSONFieldReader.int(json, key: "folderCount")
        self.corpusCount = JSONFieldReader.int(json, key: "corpusCount")
    }
}

struct LibraryRepairSummary: Equatable, Sendable {
    let repairedManifest: Bool
    let repairedFolders: Int
    let repairedCorpora: Int
    let recoveredCorpusMeta: Int
    let quarantinedFolders: Int
    let quarantinedCorpora: Int
    let checkedFolders: Int
    let checkedCorpora: Int
    let quarantineDir: String

    init(json: JSONObject) {
        let summary = JSONFieldReader.dictionary(json, key: "summary")
        self.repairedManifest = JSONFieldReader.bool(summary, key: "repairedManifest")
        self.repairedFolders = JSONFieldReader.int(summary, key: "repairedFolders")
        self.repairedCorpora = JSONFieldReader.int(summary, key: "repairedCorpora")
        self.recoveredCorpusMeta = JSONFieldReader.int(summary, key: "recoveredCorpusMeta")
        self.quarantinedFolders = JSONFieldReader.int(summary, key: "quarantinedFolders")
        self.quarantinedCorpora = JSONFieldReader.int(summary, key: "quarantinedCorpora")
        self.checkedFolders = JSONFieldReader.int(summary, key: "checkedFolders")
        self.checkedCorpora = JSONFieldReader.int(summary, key: "checkedCorpora")
        self.quarantineDir = JSONFieldReader.string(json, key: "quarantineDir")
    }
}
