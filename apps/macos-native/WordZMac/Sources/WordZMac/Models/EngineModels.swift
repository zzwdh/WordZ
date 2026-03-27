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

struct RecycleBinEntry: Identifiable, Equatable {
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

struct RecycleBinSnapshot: Equatable {
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

struct LibraryImportResult: Equatable {
    let importedCount: Int
    let skippedCount: Int
    let importedItems: [LibraryCorpusItem]

    init(json: JSONObject) {
        self.importedCount = JSONFieldReader.int(json, key: "importedCount")
        self.skippedCount = JSONFieldReader.int(json, key: "skippedCount")
        self.importedItems = JSONFieldReader.array(json, key: "importedItems")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusItem.init)
    }
}

struct LibraryBackupSummary: Equatable {
    let backupDir: String
    let folderCount: Int
    let corpusCount: Int

    init(json: JSONObject) {
        self.backupDir = JSONFieldReader.string(json, key: "backupDir")
        self.folderCount = JSONFieldReader.int(json, key: "folderCount")
        self.corpusCount = JSONFieldReader.int(json, key: "corpusCount")
    }
}

struct LibraryRestoreSummary: Equatable {
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

struct LibraryRepairSummary: Equatable {
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

struct LibrarySnapshot: Equatable {
    let folders: [LibraryFolderItem]
    let corpora: [LibraryCorpusItem]

    static let empty = LibrarySnapshot(folders: [], corpora: [])

    init(folders: [LibraryFolderItem], corpora: [LibraryCorpusItem]) {
        self.folders = folders
        self.corpora = corpora
    }

    init(json: JSONObject) {
        self.folders = JSONFieldReader.array(json, key: "folders")
            .compactMap { $0 as? JSONObject }
            .map(LibraryFolderItem.init)
        let corpusPayload = JSONFieldReader.array(json, key: "corpora")
        let normalizedCorpusPayload = corpusPayload.isEmpty
            ? JSONFieldReader.array(json, key: "items")
            : corpusPayload
        self.corpora = normalizedCorpusPayload
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
    let corpusIds: [String]
    let corpusNames: [String]
    let searchQuery: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let ngramSize: String
    let ngramPageSize: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String

    static let empty = WorkspaceSnapshotSummary(draft: WorkspaceStateDraft.empty)

    init(
        currentTab: String,
        currentLibraryFolderId: String,
        corpusIds: [String],
        corpusNames: [String],
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
    ) {
        self.currentTab = currentTab
        self.currentLibraryFolderId = currentLibraryFolderId
        self.corpusIds = corpusIds
        self.corpusNames = corpusNames
        self.searchQuery = searchQuery
        self.searchOptions = searchOptions
        self.stopwordFilter = stopwordFilter
        self.ngramSize = ngramSize
        self.ngramPageSize = ngramPageSize
        self.kwicLeftWindow = kwicLeftWindow
        self.kwicRightWindow = kwicRightWindow
        self.collocateLeftWindow = collocateLeftWindow
        self.collocateRightWindow = collocateRightWindow
        self.collocateMinFreq = collocateMinFreq
    }

    init(json: JSONObject) {
        self.currentTab = JSONFieldReader.string(json, key: "currentTab", fallback: "stats")
        self.currentLibraryFolderId = JSONFieldReader.string(json, key: "currentLibraryFolderId", fallback: "all")
        let workspace = JSONFieldReader.dictionary(json, key: "workspace")
        self.corpusIds = (workspace["corpusIds"] as? [String]) ?? []
        self.corpusNames = (workspace["corpusNames"] as? [String]) ?? []
        let search = JSONFieldReader.dictionary(json, key: "search")
        self.searchQuery = JSONFieldReader.string(search, key: "query")
        self.searchOptions = SearchOptionsState(json: JSONFieldReader.dictionary(search, key: "options"))
        self.stopwordFilter = StopwordFilterState(json: JSONFieldReader.dictionary(search, key: "stopwordFilter"))
        let ngram = JSONFieldReader.dictionary(json, key: "ngram")
        self.ngramSize = JSONFieldReader.string(ngram, key: "size", fallback: "2")
        self.ngramPageSize = JSONFieldReader.string(ngram, key: "pageSize", fallback: "10")
        let kwic = JSONFieldReader.dictionary(json, key: "kwic")
        self.kwicLeftWindow = JSONFieldReader.string(kwic, key: "leftWindow", fallback: "5")
        self.kwicRightWindow = JSONFieldReader.string(kwic, key: "rightWindow", fallback: "5")
        let collocate = JSONFieldReader.dictionary(json, key: "collocate")
        self.collocateLeftWindow = JSONFieldReader.string(collocate, key: "leftWindow", fallback: "5")
        self.collocateRightWindow = JSONFieldReader.string(collocate, key: "rightWindow", fallback: "5")
        self.collocateMinFreq = JSONFieldReader.string(collocate, key: "minFreq", fallback: "1")
    }

    init(draft: WorkspaceStateDraft) {
        self.init(
            currentTab: draft.currentTab,
            currentLibraryFolderId: draft.currentLibraryFolderId,
            corpusIds: draft.corpusIds,
            corpusNames: draft.corpusNames,
            searchQuery: draft.searchQuery,
            searchOptions: draft.searchOptions,
            stopwordFilter: draft.stopwordFilter,
            ngramSize: draft.ngramSize,
            ngramPageSize: draft.ngramPageSize,
            kwicLeftWindow: draft.kwicLeftWindow,
            kwicRightWindow: draft.kwicRightWindow,
            collocateLeftWindow: draft.collocateLeftWindow,
            collocateRightWindow: draft.collocateRightWindow,
            collocateMinFreq: draft.collocateMinFreq
        )
    }
}

struct UISettingsSnapshot: Equatable {
    let zoom: Int
    let fontScale: Int
    let fontFamily: String
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool

    static let `default` = UISettingsSnapshot(
        zoom: 100,
        fontScale: 100,
        fontFamily: "system",
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false
    )

    init(json: JSONObject) {
        self.zoom = JSONFieldReader.int(json, key: "zoom", fallback: 100)
        self.fontScale = JSONFieldReader.int(json, key: "fontScale", fallback: 100)
        self.fontFamily = JSONFieldReader.string(json, key: "fontFamily", fallback: "system")
        self.showWelcomeScreen = JSONFieldReader.bool(json, key: "showWelcomeScreen", fallback: true)
        self.restoreWorkspace = JSONFieldReader.bool(json, key: "restoreWorkspace", fallback: true)
        self.debugLogging = JSONFieldReader.bool(json, key: "debugLogging", fallback: false)
    }

    init(
        zoom: Int,
        fontScale: Int,
        fontFamily: String,
        showWelcomeScreen: Bool,
        restoreWorkspace: Bool,
        debugLogging: Bool
    ) {
        self.zoom = zoom
        self.fontScale = fontScale
        self.fontFamily = fontFamily
        self.showWelcomeScreen = showWelcomeScreen
        self.restoreWorkspace = restoreWorkspace
        self.debugLogging = debugLogging
    }

    func asJSONObject() -> JSONObject {
        [
            "zoom": zoom,
            "fontScale": fontScale,
            "fontFamily": fontFamily,
            "showWelcomeScreen": showWelcomeScreen,
            "restoreWorkspace": restoreWorkspace,
            "debugLogging": debugLogging
        ]
    }
}

struct WorkspaceStateDraft: Equatable {
    let currentTab: String
    let currentLibraryFolderId: String
    let corpusIds: [String]
    let corpusNames: [String]
    let searchQuery: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let ngramSize: String
    let ngramPageSize: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String

    static let empty = WorkspaceStateDraft(
        currentTab: "library",
        currentLibraryFolderId: "all",
        corpusIds: [],
        corpusNames: [],
        searchQuery: "",
        searchOptions: .default,
        stopwordFilter: .default,
        ngramSize: "2",
        ngramPageSize: "10",
        kwicLeftWindow: "5",
        kwicRightWindow: "5",
        collocateLeftWindow: "5",
        collocateRightWindow: "5",
        collocateMinFreq: "1"
    )

    func asJSONObject() -> JSONObject {
        [
            "currentTab": currentTab,
            "currentLibraryFolderId": currentLibraryFolderId,
            "workspace": [
                "corpusIds": corpusIds,
                "corpusNames": corpusNames
            ],
            "search": [
                "query": searchQuery,
                "options": searchOptions.asJSONObject(),
                "stopwordFilter": stopwordFilter.asJSONObject()
            ],
            "ngram": [
                "pageSize": ngramPageSize,
                "size": ngramSize
            ],
            "kwic": [
                "leftWindow": kwicLeftWindow,
                "rightWindow": kwicRightWindow,
                "pageSize": "10",
                "scope": "current",
                "sortMode": "original"
            ],
            "collocate": [
                "leftWindow": collocateLeftWindow,
                "rightWindow": collocateRightWindow,
                "minFreq": collocateMinFreq,
                "pageSize": "10"
            ]
        ]
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

struct NgramRow: Identifiable, Hashable {
    let id: String
    let phrase: String
    let count: Int

    init(phrase: String, count: Int) {
        self.id = phrase
        self.phrase = phrase
        self.count = count
    }
}

struct NgramResult: Equatable {
    let n: Int
    let rows: [NgramRow]

    init(json: JSONObject) {
        self.n = JSONFieldReader.int(json, key: "n", fallback: 2)
        self.rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { rowValue in
                guard let row = rowValue as? [Any], row.count >= 2 else { return nil }
                let phrase = String(describing: row[0])
                let count: Int
                if let value = row[1] as? Int {
                    count = value
                } else if let value = row[1] as? Double {
                    count = Int(value)
                } else {
                    count = 0
                }
                return NgramRow(phrase: phrase, count: count)
            }
    }
}

struct WordCloudResult: Equatable {
    let rows: [FrequencyRow]

    init(json: JSONObject) {
        self.rows = JSONFieldReader.array(json, key: "rows")
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
    let sentenceTokenIndex: Int

    init(json: JSONObject) {
        let sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        let nodeIndex = JSONFieldReader.int(json, key: "sentenceTokenIndex")
        self.id = "\(sentenceId)-\(nodeIndex)"
        self.left = JSONFieldReader.string(json, key: "left")
        self.node = JSONFieldReader.string(json, key: "node")
        self.right = JSONFieldReader.string(json, key: "right")
        self.sentenceId = sentenceId
        self.sentenceTokenIndex = nodeIndex
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

struct CollocateRow: Identifiable, Hashable {
    let id: String
    let word: String
    let total: Int
    let left: Int
    let right: Int
    let wordFreq: Int
    let keywordFreq: Int
    let rate: Double

    init(json: JSONObject) {
        self.word = JSONFieldReader.string(json, key: "word")
        self.total = JSONFieldReader.int(json, key: "total")
        self.left = JSONFieldReader.int(json, key: "left")
        self.right = JSONFieldReader.int(json, key: "right")
        self.wordFreq = JSONFieldReader.int(json, key: "wordFreq")
        self.keywordFreq = JSONFieldReader.int(json, key: "keywordFreq")
        self.rate = JSONFieldReader.double(json, key: "rate")
        self.id = word.isEmpty ? UUID().uuidString : word
    }
}

struct CollocateResult: Equatable {
    let rows: [CollocateRow]

    init(items: [Any]) {
        self.rows = items
            .compactMap { $0 as? JSONObject }
            .map(CollocateRow.init)
    }
}

struct ComparePerCorpusValue: Equatable {
    let corpusId: String
    let corpusName: String
    let folderName: String
    let count: Int
    let normFreq: Double

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.corpusName = JSONFieldReader.string(json, key: "corpusName", fallback: "未命名语料")
        self.folderName = JSONFieldReader.string(json, key: "folderName")
        self.count = JSONFieldReader.int(json, key: "count")
        self.normFreq = JSONFieldReader.double(json, key: "normFreq")
    }
}

struct CompareCorpusSummary: Identifiable, Equatable {
    let corpusId: String
    let corpusName: String
    let folderName: String
    let tokenCount: Int
    let typeCount: Int
    let ttr: Double
    let sttr: Double
    let topWord: String
    let topWordCount: Int

    var id: String { corpusId }

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.corpusName = JSONFieldReader.string(json, key: "corpusName", fallback: "未命名语料")
        self.folderName = JSONFieldReader.string(json, key: "folderName")
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.typeCount = JSONFieldReader.int(json, key: "typeCount")
        self.ttr = JSONFieldReader.double(json, key: "ttr")
        self.sttr = JSONFieldReader.double(json, key: "sttr")
        self.topWord = JSONFieldReader.string(json, key: "topWord")
        self.topWordCount = JSONFieldReader.int(json, key: "topWordCount")
    }
}

struct CompareRow: Identifiable, Equatable {
    let word: String
    let total: Int
    let spread: Int
    let range: Double
    let dominantCorpusName: String
    let perCorpus: [ComparePerCorpusValue]

    var id: String { word }

    init(json: JSONObject) {
        self.word = JSONFieldReader.string(json, key: "word")
        self.total = JSONFieldReader.int(json, key: "total")
        self.spread = JSONFieldReader.int(json, key: "spread")
        self.range = JSONFieldReader.double(json, key: "range")
        self.dominantCorpusName = JSONFieldReader.string(json, key: "dominantCorpusName")
        self.perCorpus = JSONFieldReader.array(json, key: "perCorpus")
            .compactMap { $0 as? JSONObject }
            .map(ComparePerCorpusValue.init)
    }
}

struct CompareResult: Equatable {
    let corpora: [CompareCorpusSummary]
    let rows: [CompareRow]

    init(json: JSONObject) {
        self.corpora = JSONFieldReader.array(json, key: "corpora")
            .compactMap { $0 as? JSONObject }
            .map(CompareCorpusSummary.init)
        self.rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { $0 as? JSONObject }
            .map(CompareRow.init)
    }
}

struct CompareRequestEntry: Sendable, Equatable {
    let corpusId: String
    let corpusName: String
    let folderId: String
    let folderName: String
    let sourceType: String
    let content: String

    func asJSONObject() -> JSONObject {
        [
            "corpusId": corpusId,
            "corpusName": corpusName,
            "folderId": folderId,
            "folderName": folderName,
            "sourceType": sourceType,
            "content": content
        ]
    }
}

struct ChiSquareResult: Equatable {
    let observed: [[Double]]
    let expected: [[Double]]
    let rowTotals: [Double]
    let colTotals: [Double]
    let total: Int
    let chiSquare: Double
    let degreesOfFreedom: Int
    let pValue: Double
    let significantAt05: Bool
    let significantAt01: Bool
    let phi: Double
    let oddsRatio: Double?
    let yatesCorrection: Bool
    let warnings: [String]

    init(json: JSONObject) {
        self.observed = JSONFieldReader.array(json, key: "observed")
            .compactMap { row in
                (row as? [Any])?.compactMap {
                    if let value = $0 as? Double { return value }
                    if let value = $0 as? Int { return Double(value) }
                    return nil
                }
            }
        self.expected = JSONFieldReader.array(json, key: "expected")
            .compactMap { row in
                (row as? [Any])?.compactMap {
                    if let value = $0 as? Double { return value }
                    if let value = $0 as? Int { return Double(value) }
                    return nil
                }
            }
        self.rowTotals = JSONFieldReader.array(json, key: "rowTotals").compactMap {
            if let value = $0 as? Double { return value }
            if let value = $0 as? Int { return Double(value) }
            return nil
        }
        self.colTotals = JSONFieldReader.array(json, key: "colTotals").compactMap {
            if let value = $0 as? Double { return value }
            if let value = $0 as? Int { return Double(value) }
            return nil
        }
        self.total = JSONFieldReader.int(json, key: "total")
        self.chiSquare = JSONFieldReader.double(json, key: "chiSquare")
        self.degreesOfFreedom = JSONFieldReader.int(json, key: "degreesOfFreedom", fallback: 1)
        self.pValue = JSONFieldReader.double(json, key: "pValue")
        self.significantAt05 = JSONFieldReader.bool(json, key: "significantAt05")
        self.significantAt01 = JSONFieldReader.bool(json, key: "significantAt01")
        self.phi = JSONFieldReader.double(json, key: "phi")
        let oddsRatioValue = json["oddsRatio"] as? Double ?? (json["oddsRatio"] as? Int).map(Double.init)
        self.oddsRatio = oddsRatioValue?.isFinite == true ? oddsRatioValue : nil
        self.yatesCorrection = JSONFieldReader.bool(json, key: "yatesCorrection")
        self.warnings = (json["warnings"] as? [String]) ?? []
    }
}

struct LocatorRow: Identifiable, Equatable {
    let sentenceId: Int
    let text: String
    let leftWords: String
    let nodeWord: String
    let rightWords: String
    let status: String

    var id: String { String(sentenceId) }

    init(json: JSONObject) {
        self.sentenceId = JSONFieldReader.int(json, key: "sentenceId")
        self.text = JSONFieldReader.string(json, key: "text")
        self.leftWords = JSONFieldReader.string(json, key: "leftWords")
        self.nodeWord = JSONFieldReader.string(json, key: "nodeWord")
        self.rightWords = JSONFieldReader.string(json, key: "rightWords")
        self.status = JSONFieldReader.string(json, key: "status")
    }
}

struct LocatorResult: Equatable {
    let sentenceCount: Int
    let rows: [LocatorRow]

    init(json: JSONObject) {
        let sentenceArray = JSONFieldReader.array(json, key: "sentences")
        let rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { $0 as? JSONObject }
            .map(LocatorRow.init)
        self.sentenceCount = sentenceArray.isEmpty ? rows.count : sentenceArray.count
        self.rows = rows
    }
}
