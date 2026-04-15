import Foundation

struct KWICRow: Identifiable, Hashable, Sendable {
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

    init(
        id: String,
        left: String,
        node: String,
        right: String,
        sentenceId: Int,
        sentenceTokenIndex: Int
    ) {
        self.id = id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(sentenceId)-\(sentenceTokenIndex)"
            : id
        self.left = left
        self.node = node
        self.right = right
        self.sentenceId = sentenceId
        self.sentenceTokenIndex = sentenceTokenIndex
    }
}

struct KWICResult: Equatable, Sendable {
    let rows: [KWICRow]

    init(json: JSONObject) {
        self.rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { $0 as? JSONObject }
            .map(KWICRow.init)
    }

    init(rows: [KWICRow]) {
        self.rows = rows
    }
}

struct CollocateRow: Identifiable, Hashable, Sendable {
    let id: String
    let word: String
    let total: Int
    let left: Int
    let right: Int
    let wordFreq: Int
    let keywordFreq: Int
    let rate: Double
    let logDice: Double
    let mutualInformation: Double
    let tScore: Double

    init(json: JSONObject) {
        self.word = JSONFieldReader.string(json, key: "word")
        self.total = JSONFieldReader.int(json, key: "total")
        self.left = JSONFieldReader.int(json, key: "left")
        self.right = JSONFieldReader.int(json, key: "right")
        self.wordFreq = JSONFieldReader.int(json, key: "wordFreq")
        self.keywordFreq = JSONFieldReader.int(json, key: "keywordFreq")
        self.rate = JSONFieldReader.double(json, key: "rate")
        self.logDice = JSONFieldReader.double(json, key: "logDice")
        self.mutualInformation = JSONFieldReader.double(json, key: "mutualInformation")
        self.tScore = JSONFieldReader.double(json, key: "tScore")
        self.id = word.isEmpty ? UUID().uuidString : word
    }
}

struct CollocateResult: Equatable, Sendable {
    let rows: [CollocateRow]

    init(items: [Any]) {
        self.rows = items
            .compactMap { $0 as? JSONObject }
            .map(CollocateRow.init)
    }
}

struct ComparePerCorpusValue: Equatable, Sendable {
    let corpusId: String
    let corpusName: String
    let folderName: String
    let count: Int
    let tokenCount: Int
    let normFreq: Double

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.corpusName = JSONFieldReader.string(json, key: "corpusName", fallback: "未命名语料")
        self.folderName = JSONFieldReader.string(json, key: "folderName")
        self.count = JSONFieldReader.int(json, key: "count")
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.normFreq = JSONFieldReader.double(json, key: "normFreq")
    }
}

struct CompareCorpusSummary: Identifiable, Equatable, Sendable {
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

struct CompareRow: Identifiable, Equatable, Sendable {
    let word: String
    let total: Int
    let spread: Int
    let range: Double
    let dominantCorpusName: String
    let keyness: Double
    let effectSize: Double
    let pValue: Double
    let referenceNormFreq: Double
    let perCorpus: [ComparePerCorpusValue]

    var id: String { word }

    init(json: JSONObject) {
        self.word = JSONFieldReader.string(json, key: "word")
        self.total = JSONFieldReader.int(json, key: "total")
        self.spread = JSONFieldReader.int(json, key: "spread")
        self.range = JSONFieldReader.double(json, key: "range")
        self.dominantCorpusName = JSONFieldReader.string(json, key: "dominantCorpusName")
        self.keyness = JSONFieldReader.double(json, key: "keyness")
        self.effectSize = JSONFieldReader.double(json, key: "effectSize")
        self.pValue = JSONFieldReader.double(json, key: "pValue")
        self.referenceNormFreq = JSONFieldReader.double(json, key: "referenceNormFreq")
        self.perCorpus = JSONFieldReader.array(json, key: "perCorpus")
            .compactMap { $0 as? JSONObject }
            .map(ComparePerCorpusValue.init)
    }
}

struct CompareResult: Equatable, Sendable {
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

struct ChiSquareResult: Equatable, Sendable {
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

struct LocatorRow: Identifiable, Equatable, Sendable {
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

    init(
        sentenceId: Int,
        text: String,
        leftWords: String,
        nodeWord: String,
        rightWords: String,
        status: String
    ) {
        self.sentenceId = sentenceId
        self.text = text
        self.leftWords = leftWords
        self.nodeWord = nodeWord
        self.rightWords = rightWords
        self.status = status
    }
}

struct LocatorResult: Equatable, Sendable {
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

    init(sentenceCount: Int, rows: [LocatorRow]) {
        self.sentenceCount = sentenceCount
        self.rows = rows
    }
}
