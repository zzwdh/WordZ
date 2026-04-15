import Foundation

enum LibraryCorpusCleaningStatus: String, Codable, Equatable, Sendable {
    case pending
    case cleaned
    case cleanedWithChanges

    init(rawValue: String) {
        switch rawValue {
        case Self.cleaned.rawValue:
            self = .cleaned
        case Self.cleanedWithChanges.rawValue:
            self = .cleanedWithChanges
        default:
            self = .pending
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .pending:
            return wordZText("待清洗", "Pending Cleaning", mode: mode)
        case .cleaned:
            return wordZText("已清洗", "Cleaned", mode: mode)
        case .cleanedWithChanges:
            return wordZText("清洗有变更", "Cleaned With Changes", mode: mode)
        }
    }
}

struct LibraryCorpusCleaningRuleHit: Codable, Equatable, Hashable, Sendable {
    let id: String
    let count: Int

    init(id: String, count: Int) {
        self.id = id
        self.count = count
    }

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.count = JSONFieldReader.int(json, key: "count")
    }

    var jsonObject: JSONObject {
        [
            "id": id,
            "count": count
        ]
    }

    func title(in mode: AppLanguageMode) -> String {
        switch id {
        case "compatibility-mapping":
            return wordZText("兼容字符归一", "Compatibility Mapping", mode: mode)
        case "line-ending-normalization":
            return wordZText("换行统一", "Line Endings", mode: mode)
        case "space-normalization":
            return wordZText("空白字符统一", "Space Normalization", mode: mode)
        case "bom-removal":
            return wordZText("BOM 清理", "BOM Removal", mode: mode)
        case "zero-width-removal":
            return wordZText("零宽字符清理", "Zero-Width Removal", mode: mode)
        case "null-removal":
            return wordZText("NUL 清理", "NUL Removal", mode: mode)
        case "control-character-removal":
            return wordZText("控制字符清理", "Control Character Removal", mode: mode)
        case "trailing-whitespace-trim":
            return wordZText("行尾空白修整", "Trailing Whitespace Trim", mode: mode)
        case "outer-blank-line-trim":
            return wordZText("首尾空段修整", "Outer Blank Lines", mode: mode)
        case "blank-line-collapse":
            return wordZText("连续空段压缩", "Blank Line Collapse", mode: mode)
        default:
            return id
        }
    }
}

struct LibraryCorpusCleaningReportSummary: Codable, Equatable, Hashable, Sendable {
    let status: LibraryCorpusCleaningStatus
    let cleanedAt: String
    let profileVersion: String
    let originalCharacterCount: Int
    let cleanedCharacterCount: Int
    let ruleHits: [LibraryCorpusCleaningRuleHit]

    static let pending = LibraryCorpusCleaningReportSummary(
        status: .pending,
        cleanedAt: "",
        profileVersion: "",
        originalCharacterCount: 0,
        cleanedCharacterCount: 0,
        ruleHits: []
    )

    init(
        status: LibraryCorpusCleaningStatus,
        cleanedAt: String,
        profileVersion: String,
        originalCharacterCount: Int,
        cleanedCharacterCount: Int,
        ruleHits: [LibraryCorpusCleaningRuleHit]
    ) {
        self.status = status
        self.cleanedAt = cleanedAt
        self.profileVersion = profileVersion
        self.originalCharacterCount = originalCharacterCount
        self.cleanedCharacterCount = cleanedCharacterCount
        self.ruleHits = ruleHits
    }

    init(json: JSONObject) {
        let statusValue = JSONFieldReader.string(json, key: "status")
        let profileVersion = JSONFieldReader.string(json, key: "profileVersion")
        let originalCharacterCount = JSONFieldReader.int(json, key: "originalCharacterCount")
        let cleanedCharacterCount = JSONFieldReader.int(json, key: "cleanedCharacterCount")
        let ruleHits = JSONFieldReader.array(json, key: "ruleHits")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusCleaningRuleHit.init)
        let resolvedStatus: LibraryCorpusCleaningStatus
        if !statusValue.isEmpty {
            resolvedStatus = LibraryCorpusCleaningStatus(rawValue: statusValue)
        } else if profileVersion.isEmpty {
            resolvedStatus = .pending
        } else {
            resolvedStatus = ruleHits.isEmpty ? .cleaned : .cleanedWithChanges
        }
        self.init(
            status: resolvedStatus,
            cleanedAt: JSONFieldReader.string(json, key: "cleanedAt"),
            profileVersion: profileVersion,
            originalCharacterCount: originalCharacterCount,
            cleanedCharacterCount: cleanedCharacterCount,
            ruleHits: ruleHits
        )
    }

    var hasChanges: Bool {
        status == .cleanedWithChanges
    }

    var isPending: Bool {
        status == .pending || profileVersion.isEmpty
    }

    var jsonObject: JSONObject {
        [
            "status": status.rawValue,
            "cleanedAt": cleanedAt,
            "profileVersion": profileVersion,
            "originalCharacterCount": originalCharacterCount,
            "cleanedCharacterCount": cleanedCharacterCount,
            "ruleHits": ruleHits.map(\.jsonObject)
        ]
    }

    func ruleHitsSummary(in mode: AppLanguageMode, limit: Int = 3) -> String {
        guard !ruleHits.isEmpty else {
            return wordZText("未发现可修正项", "No cleaning changes", mode: mode)
        }
        return ruleHits.prefix(max(1, limit))
            .map { "\($0.title(in: mode)) \($0.count)" }
            .joined(separator: " · ")
    }
}

struct LibraryImportCleaningSummary: Equatable, Sendable {
    let cleanedCount: Int
    let changedCount: Int
    let ruleHits: [LibraryCorpusCleaningRuleHit]

    static let empty = LibraryImportCleaningSummary(cleanedCount: 0, changedCount: 0, ruleHits: [])

    init(cleanedCount: Int, changedCount: Int, ruleHits: [LibraryCorpusCleaningRuleHit]) {
        self.cleanedCount = cleanedCount
        self.changedCount = changedCount
        self.ruleHits = ruleHits
    }

    init(json: JSONObject) {
        self.cleanedCount = JSONFieldReader.int(json, key: "cleanedCount")
        self.changedCount = JSONFieldReader.int(json, key: "changedCount")
        self.ruleHits = JSONFieldReader.array(json, key: "ruleHits")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusCleaningRuleHit.init)
    }

    var jsonObject: JSONObject {
        [
            "cleanedCount": cleanedCount,
            "changedCount": changedCount,
            "ruleHits": ruleHits.map(\.jsonObject)
        ]
    }
}

struct LibraryCorpusCleaningFailureItem: Equatable, Sendable {
    let corpusId: String
    let corpusName: String
    let reason: String

    init(corpusId: String, corpusName: String, reason: String) {
        self.corpusId = corpusId
        self.corpusName = corpusName
        self.reason = reason
    }

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.corpusName = JSONFieldReader.string(json, key: "corpusName")
        self.reason = JSONFieldReader.string(json, key: "reason")
    }

    var jsonObject: JSONObject {
        [
            "corpusId": corpusId,
            "corpusName": corpusName,
            "reason": reason
        ]
    }
}

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
    let cleaningSummary: LibraryImportCleaningSummary
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
        self.cleaningSummary = LibraryImportCleaningSummary(
            json: JSONFieldReader.dictionary(json, key: "cleaningSummary")
        )
        self.cancelled = JSONFieldReader.bool(json, key: "cancelled")
    }
}

enum LibraryCorpusCleaningProgressPhase: String, Equatable, Sendable {
    case preparing
    case cleaning
    case committing
    case completed
}

struct LibraryCorpusCleaningProgressSnapshot: Equatable, Sendable {
    let phase: LibraryCorpusCleaningProgressPhase
    let totalCount: Int
    let completedCount: Int
    let changedCount: Int
    let currentCorpusID: String
    let currentCorpusName: String

    var progress: Double {
        guard totalCount > 0 else {
            return phase == .completed ? 1 : 0
        }
        return min(max(Double(completedCount) / Double(totalCount), 0), 1)
    }
}

struct LibraryCorpusCleaningBatchResult: Equatable, Sendable {
    let requestedCount: Int
    let cleanedCount: Int
    let changedCount: Int
    let cleanedItems: [LibraryCorpusItem]
    let failureItems: [LibraryCorpusCleaningFailureItem]
    let ruleHits: [LibraryCorpusCleaningRuleHit]
    let cancelled: Bool

    init(json: JSONObject) {
        self.requestedCount = JSONFieldReader.int(json, key: "requestedCount")
        self.cleanedCount = JSONFieldReader.int(json, key: "cleanedCount")
        self.changedCount = JSONFieldReader.int(json, key: "changedCount")
        self.cleanedItems = JSONFieldReader.array(json, key: "cleanedItems")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusItem.init)
        self.failureItems = JSONFieldReader.array(json, key: "failureItems")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusCleaningFailureItem.init)
        self.ruleHits = JSONFieldReader.array(json, key: "ruleHits")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusCleaningRuleHit.init)
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
