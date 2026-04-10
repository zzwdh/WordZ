import Foundation

struct NativeStoredCorpusDocument: Codable, Equatable {
    let schemaVersion: Int
    let importedAt: String
    let sourceType: String
    let representedPath: String
    let detectedEncoding: String
    let text: String
}

struct NativeFolderRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String

    var libraryItem: LibraryFolderItem {
        LibraryFolderItem(json: [
            "id": id,
            "name": name
        ])
    }
}

struct NativeCorpusRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var folderId: String
    var folderName: String
    var sourceType: String
    var representedPath: String
    var storageFileName: String
    var metadata: CorpusMetadataProfile

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case folderId
        case folderName
        case sourceType
        case representedPath
        case storageFileName
        case metadata
    }

    init(
        id: String,
        name: String,
        folderId: String,
        folderName: String,
        sourceType: String,
        representedPath: String,
        storageFileName: String,
        metadata: CorpusMetadataProfile
    ) {
        self.id = id
        self.name = name
        self.folderId = folderId
        self.folderName = folderName
        self.sourceType = sourceType
        self.representedPath = representedPath
        self.storageFileName = storageFileName
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderId = try container.decode(String.self, forKey: .folderId)
        folderName = try container.decode(String.self, forKey: .folderName)
        sourceType = try container.decode(String.self, forKey: .sourceType)
        representedPath = try container.decode(String.self, forKey: .representedPath)
        storageFileName = try container.decode(String.self, forKey: .storageFileName)
        metadata = try container.decodeIfPresent(CorpusMetadataProfile.self, forKey: .metadata) ?? .empty
    }

    var libraryItem: LibraryCorpusItem {
        LibraryCorpusItem(json: jsonObject)
    }

    var jsonObject: JSONObject {
        [
            "id": id,
            "name": name,
            "folderId": folderId,
            "folderName": folderName,
            "sourceType": sourceType,
            "representedPath": representedPath,
            "metadata": metadata.jsonObject
        ]
    }
}

struct NativeCorpusSetRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var corpusIDs: [String]
    var corpusNames: [String]
    var metadataFilterState: CorpusMetadataFilterState
    let createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case corpusIDs = "corpusIds"
        case corpusNames
        case metadataFilterState = "metadataFilter"
        case createdAt
        case updatedAt
    }

    var libraryItem: LibraryCorpusSetItem {
        LibraryCorpusSetItem(json: jsonObject)
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

struct NativeRecycleRecord: Codable, Equatable, Identifiable {
    let recycleEntryId: String
    let type: String
    let deletedAt: String
    let name: String
    let originalFolderName: String
    let sourceType: String
    let itemCount: Int
    let folder: NativeFolderRecord?
    var corpora: [NativeCorpusRecord]

    var id: String { recycleEntryId }

    var recycleItem: RecycleBinEntry {
        RecycleBinEntry(json: [
            "recycleEntryId": recycleEntryId,
            "type": type,
            "deletedAt": deletedAt,
            "name": name,
            "originalFolderName": originalFolderName,
            "sourceType": sourceType,
            "itemCount": itemCount
        ])
    }
}
