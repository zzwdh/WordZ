import Foundation

typealias JSONObject = [String: Any]

enum EngineModelError: LocalizedError {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "缺少字段：\(field)"
        case .invalidField(let field):
            return "字段格式无效：\(field)"
        }
    }
}

enum JSONFieldReader {
    static func string(_ object: JSONObject, key: String, fallback: String = "") -> String {
        String(object[key] as? String ?? fallback)
    }

    static func bool(_ object: JSONObject, key: String, fallback: Bool = false) -> Bool {
        object[key] as? Bool ?? fallback
    }

    static func int(_ object: JSONObject, key: String, fallback: Int = 0) -> Int {
        if let value = object[key] as? Int {
            return value
        }
        if let value = object[key] as? Double {
            return Int(value)
        }
        return fallback
    }

    static func double(_ object: JSONObject, key: String, fallback: Double = 0) -> Double {
        if let value = object[key] as? Double {
            return value
        }
        if let value = object[key] as? Int {
            return Double(value)
        }
        return fallback
    }

    static func dictionary(_ object: JSONObject, key: String) -> JSONObject {
        object[key] as? JSONObject ?? [:]
    }

    static func array(_ object: JSONObject, key: String) -> [Any] {
        object[key] as? [Any] ?? []
    }
}

struct AppInfoSummary: Equatable {
    let name: String
    let version: String
    let help: [String]
    let releaseNotes: [String]
    let userDataDir: String

    init(json: JSONObject) {
        self.name = JSONFieldReader.string(json, key: "name", fallback: "WordZ")
        self.version = JSONFieldReader.string(json, key: "version")
        self.help = (json["help"] as? [String]) ?? []
        self.releaseNotes = (json["releaseNotes"] as? [String]) ?? []
        self.userDataDir = JSONFieldReader.string(json, key: "userDataDir")
    }
}

struct LibraryFolderItem: Identifiable, Hashable {
    let id: String
    let name: String

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未分类")
    }
}

struct LibraryCorpusItem: Identifiable, Hashable {
    let id: String
    let name: String
    let folderId: String
    let folderName: String
    let sourceType: String

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未命名语料")
        self.folderId = JSONFieldReader.string(json, key: "folderId")
        self.folderName = JSONFieldReader.string(json, key: "folderName", fallback: "未分类")
        self.sourceType = JSONFieldReader.string(json, key: "sourceType", fallback: "txt")
    }
}

struct LibrarySnapshot: Equatable {
    let folders: [LibraryFolderItem]
    let corpora: [LibraryCorpusItem]

    init(json: JSONObject) {
        self.folders = JSONFieldReader.array(json, key: "folders")
            .compactMap { $0 as? JSONObject }
            .map(LibraryFolderItem.init)
        self.corpora = JSONFieldReader.array(json, key: "corpora")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusItem.init)
    }
}

struct OpenedCorpus: Equatable {
    let mode: String
    let filePath: String
    let displayName: String
    let content: String
    let sourceType: String

    init(json: JSONObject) {
        self.mode = JSONFieldReader.string(json, key: "mode", fallback: "saved")
        self.filePath = JSONFieldReader.string(json, key: "filePath")
        self.displayName = JSONFieldReader.string(json, key: "displayName", fallback: JSONFieldReader.string(json, key: "fileName"))
        self.content = JSONFieldReader.string(json, key: "content")
        self.sourceType = JSONFieldReader.string(json, key: "sourceType", fallback: "txt")
    }
}

struct WorkspaceSnapshotSummary: Equatable {
    let currentTab: String
    let currentLibraryFolderId: String
    let corpusNames: [String]
    let searchQuery: String

    init(json: JSONObject) {
        self.currentTab = JSONFieldReader.string(json, key: "currentTab", fallback: "stats")
        self.currentLibraryFolderId = JSONFieldReader.string(json, key: "currentLibraryFolderId", fallback: "all")
        let workspace = JSONFieldReader.dictionary(json, key: "workspace")
        self.corpusNames = (workspace["corpusNames"] as? [String]) ?? []
        let search = JSONFieldReader.dictionary(json, key: "search")
        self.searchQuery = JSONFieldReader.string(search, key: "query")
    }
}

struct FrequencyRow: Identifiable, Hashable {
    let id: String
    let word: String
    let count: Int

    init(word: String, count: Int) {
        self.id = word
        self.word = word
        self.count = count
    }
}

struct StatsResult: Equatable {
    let tokenCount: Int
    let typeCount: Int
    let ttr: Double
    let sttr: Double
    let frequencyRows: [FrequencyRow]

    init(json: JSONObject) {
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.typeCount = JSONFieldReader.int(json, key: "typeCount")
        self.ttr = JSONFieldReader.double(json, key: "ttr")
        self.sttr = JSONFieldReader.double(json, key: "sttr")
        self.frequencyRows = JSONFieldReader.array(json, key: "freqRows")
            .compactMap { rowValue in
                guard let row = rowValue as? [Any], row.count >= 2 else { return nil }
                let word = String(describing: row[0])
                let count: Int
                if let value = row[1] as? Int {
                    count = value
                } else if let value = row[1] as? Double {
                    count = Int(value)
                } else {
                    count = 0
                }
                return FrequencyRow(word: word, count: count)
            }
    }
}

struct KWICRow: Identifiable, Hashable {
    let id: String
    let left: String
    let node: String
    let right: String
    let sentenceId: Int

    init(json: JSONObject) {
        let sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        let nodeIndex = JSONFieldReader.int(json, key: "sentenceTokenIndex")
        self.id = "\(sentenceId)-\(nodeIndex)"
        self.left = JSONFieldReader.string(json, key: "left")
        self.node = JSONFieldReader.string(json, key: "node")
        self.right = JSONFieldReader.string(json, key: "right")
        self.sentenceId = sentenceId
    }
}

struct KWICResult: Equatable {
    let rows: [KWICRow]

    init(json: JSONObject) {
        self.rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { $0 as? JSONObject }
            .map(KWICRow.init)
    }
}
