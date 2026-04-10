import Foundation

struct FrequencyRow: Identifiable, Hashable, Sendable {
    let id: String
    let word: String
    let count: Int
    let rank: Int
    let normFreq: Double
    let range: Int
    let normRange: Double
    let sentenceRange: Int
    let paragraphRange: Int

    init(
        word: String,
        count: Int,
        rank: Int = 0,
        normFreq: Double = 0,
        range: Int = 0,
        normRange: Double = 0,
        sentenceRange: Int = 0,
        paragraphRange: Int = 0
    ) {
        self.id = word
        self.word = word
        self.count = count
        self.rank = rank
        self.normFreq = normFreq
        self.range = range
        self.normRange = normRange
        self.sentenceRange = sentenceRange == 0 ? range : sentenceRange
        self.paragraphRange = paragraphRange == 0 ? min(1, max(self.sentenceRange, 0)) : paragraphRange
    }
}

struct StatsResult: Equatable, Sendable {
    let tokenCount: Int
    let typeCount: Int
    let ttr: Double
    let sttr: Double
    let sentenceCount: Int
    let paragraphCount: Int
    let frequencyRows: [FrequencyRow]

    init(
        tokenCount: Int,
        typeCount: Int,
        ttr: Double,
        sttr: Double,
        sentenceCount: Int,
        paragraphCount: Int,
        frequencyRows: [FrequencyRow]
    ) {
        self.tokenCount = tokenCount
        self.typeCount = typeCount
        self.ttr = ttr
        self.sttr = sttr
        self.sentenceCount = sentenceCount
        self.paragraphCount = paragraphCount
        self.frequencyRows = frequencyRows
    }

    init(json: JSONObject) {
        self.tokenCount = JSONFieldReader.int(json, key: "tokenCount")
        self.typeCount = JSONFieldReader.int(json, key: "typeCount")
        self.ttr = JSONFieldReader.double(json, key: "ttr")
        self.sttr = JSONFieldReader.double(json, key: "sttr")
        self.sentenceCount = JSONFieldReader.int(json, key: "sentenceCount", fallback: 1)
        self.paragraphCount = JSONFieldReader.int(json, key: "paragraphCount", fallback: 1)
        self.frequencyRows = JSONFieldReader.array(json, key: "freqRows")
            .compactMap { rowValue in
                if let row = rowValue as? JSONObject {
                    let sentenceRange = JSONFieldReader.int(row, key: "sentenceRange", fallback: JSONFieldReader.int(row, key: "range"))
                    let paragraphRange = JSONFieldReader.int(row, key: "paragraphRange", fallback: min(1, max(sentenceRange, 0)))
                    return FrequencyRow(
                        word: JSONFieldReader.string(row, key: "word"),
                        count: JSONFieldReader.int(row, key: "count"),
                        rank: JSONFieldReader.int(row, key: "rank"),
                        normFreq: JSONFieldReader.double(row, key: "normFreq"),
                        range: JSONFieldReader.int(row, key: "range", fallback: sentenceRange),
                        normRange: JSONFieldReader.double(row, key: "normRange"),
                        sentenceRange: sentenceRange,
                        paragraphRange: paragraphRange
                    )
                }
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
                let rank = row.count > 2 ? JSONFieldReader.int(["value": row[2]], key: "value") : 0
                let normFreq = row.count > 3 ? JSONFieldReader.double(["value": row[3]], key: "value") : 0
                let range = row.count > 4 ? JSONFieldReader.int(["value": row[4]], key: "value") : 0
                let normRange = row.count > 5 ? JSONFieldReader.double(["value": row[5]], key: "value") : 0
                return FrequencyRow(
                    word: word,
                    count: count,
                    rank: rank,
                    normFreq: normFreq,
                    range: range,
                    normRange: normRange,
                    sentenceRange: range,
                    paragraphRange: min(1, max(range, 0))
                )
            }
    }
}

struct NgramRow: Identifiable, Hashable, Sendable {
    let id: String
    let phrase: String
    let count: Int

    init(phrase: String, count: Int) {
        self.id = phrase
        self.phrase = phrase
        self.count = count
    }
}

struct NgramResult: Equatable, Sendable {
    let n: Int
    let rows: [NgramRow]

    init(n: Int, rows: [NgramRow]) {
        self.n = n
        self.rows = rows
    }

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
