import Foundation

struct Corpus: Equatable, Sendable {
    let id: String
    let name: String
    let text: String

    init(id: String, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

struct Token: Hashable, Sendable {
    let surface: String
    let normalized: String
}

struct FrequencyTable: Equatable, Sendable {
    let tokenCount: Int
    let typeCount: Int
    let counts: [String: Int]

    init(counts: [String: Int], tokenCount: Int) {
        self.counts = counts
        self.tokenCount = tokenCount
        self.typeCount = counts.count
    }

    func frequency(of term: String) -> Int {
        counts[term, default: 0]
    }

    func normalizedFrequency(of term: String, per unit: Double = 1_000_000) -> Double {
        guard tokenCount > 0 else { return 0 }
        return (Double(frequency(of: term)) / Double(tokenCount)) * unit
    }
}

enum KeywordStatisticMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case logLikelihood
    case chiSquare

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .logLikelihood:
            return wordZText("Log-Likelihood", "Log-Likelihood", mode: mode)
        case .chiSquare:
            return wordZText("Chi-square", "Chi-square", mode: mode)
        }
    }
}

struct KeywordPreprocessingOptions: Equatable, Codable, Sendable {
    var lowercased: Bool
    var removePunctuation: Bool
    var stopwordFilter: StopwordFilterState
    var minimumFrequency: Int
    var statistic: KeywordStatisticMethod

    static let `default` = KeywordPreprocessingOptions(
        lowercased: true,
        removePunctuation: true,
        stopwordFilter: .default,
        minimumFrequency: 2,
        statistic: .logLikelihood
    )
}

struct KeywordRequestEntry: Equatable, Sendable {
    let corpusId: String
    let corpusName: String
    let folderName: String
    let content: String

    func asCorpus() -> Corpus {
        Corpus(id: corpusId, name: corpusName, text: content)
    }

    func asJSONObject() -> JSONObject {
        [
            "corpusId": corpusId,
            "corpusName": corpusName,
            "folderName": folderName,
            "content": content
        ]
    }
}

struct KeywordCorpusSummary: Equatable, Sendable {
    let corpusId: String
    let corpusName: String
    let folderName: String
    let tokenCount: Int
    let typeCount: Int

    init(corpusId: String, corpusName: String, folderName: String, tokenCount: Int, typeCount: Int) {
        self.corpusId = corpusId
        self.corpusName = corpusName
        self.folderName = folderName
        self.tokenCount = tokenCount
        self.typeCount = typeCount
    }

    init(json: JSONObject) {
        self.corpusId = JSONFieldReader.string(json, key: "corpusId")
        self.corpusName = JSONFieldReader.string(json, key: "corpusName", fallback: "未命名语料")
        self.folderName = JSONFieldReader.string(json, key: "folderName")
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.typeCount = JSONFieldReader.int(json, key: "typeCount")
    }

    func asJSONObject() -> JSONObject {
        [
            "corpusId": corpusId,
            "corpusName": corpusName,
            "folderName": folderName,
            "tokenCount": tokenCount,
            "typeCount": typeCount
        ]
    }
}

struct KeywordResultRow: Identifiable, Equatable, Sendable {
    let word: String
    let rank: Int
    let targetFrequency: Int
    let referenceFrequency: Int
    let targetNormalizedFrequency: Double
    let referenceNormalizedFrequency: Double
    let keynessScore: Double
    let logRatio: Double
    let pValue: Double

    var id: String { word }

    init(
        word: String,
        rank: Int,
        targetFrequency: Int,
        referenceFrequency: Int,
        targetNormalizedFrequency: Double,
        referenceNormalizedFrequency: Double,
        keynessScore: Double,
        logRatio: Double,
        pValue: Double
    ) {
        self.word = word
        self.rank = rank
        self.targetFrequency = targetFrequency
        self.referenceFrequency = referenceFrequency
        self.targetNormalizedFrequency = targetNormalizedFrequency
        self.referenceNormalizedFrequency = referenceNormalizedFrequency
        self.keynessScore = keynessScore
        self.logRatio = logRatio
        self.pValue = pValue
    }

    init(json: JSONObject) {
        self.word = JSONFieldReader.string(json, key: "word")
        self.rank = JSONFieldReader.int(json, key: "rank")
        self.targetFrequency = JSONFieldReader.int(json, key: "targetFrequency")
        self.referenceFrequency = JSONFieldReader.int(json, key: "referenceFrequency")
        self.targetNormalizedFrequency = JSONFieldReader.double(json, key: "targetNormalizedFrequency")
        self.referenceNormalizedFrequency = JSONFieldReader.double(json, key: "referenceNormalizedFrequency")
        self.keynessScore = JSONFieldReader.double(json, key: "keynessScore")
        self.logRatio = JSONFieldReader.double(json, key: "logRatio")
        self.pValue = JSONFieldReader.double(json, key: "pValue")
    }

    func asJSONObject() -> JSONObject {
        [
            "word": word,
            "rank": rank,
            "targetFrequency": targetFrequency,
            "referenceFrequency": referenceFrequency,
            "targetNormalizedFrequency": targetNormalizedFrequency,
            "referenceNormalizedFrequency": referenceNormalizedFrequency,
            "keynessScore": keynessScore,
            "logRatio": logRatio,
            "pValue": pValue
        ]
    }
}

struct KeywordResult: Equatable, Sendable {
    let statistic: KeywordStatisticMethod
    let targetCorpus: KeywordCorpusSummary
    let referenceCorpus: KeywordCorpusSummary
    let rows: [KeywordResultRow]

    init(
        statistic: KeywordStatisticMethod,
        targetCorpus: KeywordCorpusSummary,
        referenceCorpus: KeywordCorpusSummary,
        rows: [KeywordResultRow]
    ) {
        self.statistic = statistic
        self.targetCorpus = targetCorpus
        self.referenceCorpus = referenceCorpus
        self.rows = rows
    }

    init(json: JSONObject) {
        self.statistic = KeywordStatisticMethod(
            rawValue: JSONFieldReader.string(json, key: "statistic", fallback: KeywordStatisticMethod.logLikelihood.rawValue)
        ) ?? .logLikelihood
        self.targetCorpus = KeywordCorpusSummary(json: JSONFieldReader.dictionary(json, key: "targetCorpus"))
        self.referenceCorpus = KeywordCorpusSummary(json: JSONFieldReader.dictionary(json, key: "referenceCorpus"))
        self.rows = JSONFieldReader.array(json, key: "rows")
            .compactMap { $0 as? JSONObject }
            .map(KeywordResultRow.init)
    }

    func asJSONObject() -> JSONObject {
        [
            "statistic": statistic.rawValue,
            "targetCorpus": targetCorpus.asJSONObject(),
            "referenceCorpus": referenceCorpus.asJSONObject(),
            "rows": rows.map { $0.asJSONObject() }
        ]
    }
}
