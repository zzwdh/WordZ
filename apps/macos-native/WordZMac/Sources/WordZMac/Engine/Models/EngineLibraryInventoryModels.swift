import Foundation

struct LibraryFolderItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未分类")
    }
}

struct LibraryCorpusItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let folderId: String
    let folderName: String
    let sourceType: String
    let representedPath: String
    let metadata: CorpusMetadataProfile

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未命名语料")
        self.folderId = JSONFieldReader.string(json, key: "folderId")
        self.folderName = JSONFieldReader.string(json, key: "folderName", fallback: "未分类")
        self.sourceType = JSONFieldReader.string(json, key: "sourceType", fallback: "txt")
        self.representedPath = JSONFieldReader.string(json, key: "representedPath")
        self.metadata = CorpusMetadataProfile(
            json: JSONFieldReader.dictionary(json, key: "metadata").isEmpty ? json : JSONFieldReader.dictionary(json, key: "metadata")
        )
    }
}

struct LibraryCorpusSetItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let corpusIDs: [String]
    let corpusNames: [String]
    let metadataFilterState: CorpusMetadataFilterState
    let createdAt: String
    let updatedAt: String

    init(json: JSONObject) {
        self.id = JSONFieldReader.string(json, key: "id")
        self.name = JSONFieldReader.string(json, key: "name", fallback: "未命名语料集")
        self.corpusIDs = JSONFieldReader.array(json, key: "corpusIds").compactMap { $0 as? String }
        self.corpusNames = JSONFieldReader.array(json, key: "corpusNames").compactMap { $0 as? String }
        self.metadataFilterState = CorpusMetadataFilterState(json: JSONFieldReader.dictionary(json, key: "metadataFilter"))
        self.createdAt = JSONFieldReader.string(json, key: "createdAt")
        self.updatedAt = JSONFieldReader.string(json, key: "updatedAt")
    }

    var jsonObject: JSONObject {
        [
            "id": id,
            "name": name,
            "corpusIds": corpusIDs,
            "corpusNames": corpusNames,
            "metadataFilter": metadataFilterState.jsonObject,
            "createdAt": createdAt,
            "updatedAt": updatedAt
        ]
    }
}

struct LibrarySnapshot: Equatable, Sendable {
    let folders: [LibraryFolderItem]
    let corpora: [LibraryCorpusItem]
    let corpusSets: [LibraryCorpusSetItem]

    static let empty = LibrarySnapshot(folders: [], corpora: [], corpusSets: [])

    init(
        folders: [LibraryFolderItem],
        corpora: [LibraryCorpusItem],
        corpusSets: [LibraryCorpusSetItem] = []
    ) {
        self.folders = folders
        self.corpora = corpora
        self.corpusSets = corpusSets
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
        self.corpusSets = JSONFieldReader.array(json, key: "corpusSets")
            .compactMap { $0 as? JSONObject }
            .map(LibraryCorpusSetItem.init)
    }
}
