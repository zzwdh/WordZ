import Foundation

struct CorpusInfoSummary: Equatable, Sendable {
    let corpusId: String
    let title: String
    let folderName: String
    let sourceType: String
    let representedPath: String
    let detectedEncoding: String
    let importedAt: String
    let tokenCount: Int
    let typeCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let characterCount: Int
    let ttr: Double
    let sttr: Double
    let metadata: CorpusMetadataProfile
    let cleaningStatus: LibraryCorpusCleaningStatus
    let cleaningSummary: LibraryCorpusCleaningReportSummary?

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.title = JSONFieldReader.string(json, key: "title", fallback: "未命名语料")
        self.folderName = JSONFieldReader.string(json, key: "folderName", fallback: "未分类")
        self.sourceType = JSONFieldReader.string(json, key: "sourceType", fallback: "txt")
        self.representedPath = JSONFieldReader.string(json, key: "representedPath")
        self.detectedEncoding = JSONFieldReader.string(json, key: "detectedEncoding")
        self.importedAt = JSONFieldReader.string(json, key: "importedAt")
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.typeCount = JSONFieldReader.int(json, key: "typeCount")
        self.sentenceCount = JSONFieldReader.int(json, key: "sentenceCount")
        self.paragraphCount = JSONFieldReader.int(json, key: "paragraphCount")
        self.characterCount = JSONFieldReader.int(json, key: "characterCount")
        self.ttr = JSONFieldReader.double(json, key: "ttr")
        self.sttr = JSONFieldReader.double(json, key: "sttr")
        self.metadata = CorpusMetadataProfile(
            json: JSONFieldReader.dictionary(json, key: "metadata").isEmpty ? json : JSONFieldReader.dictionary(json, key: "metadata")
        )
        let cleaningSummaryObject = JSONFieldReader.dictionary(json, key: "cleaningSummary")
        let resolvedCleaningSummary = cleaningSummaryObject.isEmpty
            ? nil
            : LibraryCorpusCleaningReportSummary(json: cleaningSummaryObject)
        self.cleaningSummary = resolvedCleaningSummary?.isPending == true ? nil : resolvedCleaningSummary
        if let resolvedCleaningSummary {
            self.cleaningStatus = resolvedCleaningSummary.status
        } else {
            self.cleaningStatus = LibraryCorpusCleaningStatus(
                rawValue: JSONFieldReader.string(json, key: "cleaningStatus")
            )
        }
    }
}

struct OpenedCorpus: Equatable, Sendable {
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
