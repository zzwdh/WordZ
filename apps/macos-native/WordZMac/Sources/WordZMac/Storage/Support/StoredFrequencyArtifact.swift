import Foundation

struct StoredFrequencyArtifact: Equatable, Sendable {
    let textDigest: String
    let tokenCount: Int
    let typeCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let ttr: Double
    let sttr: Double
    let frequencyRows: [FrequencyRow]

    var topWord: String {
        frequencyRows.first?.word ?? ""
    }

    var topWordCount: Int {
        frequencyRows.first?.count ?? 0
    }

    var frequencyMap: [String: Int] {
        frequencyRows.reduce(into: [:]) { partialResult, row in
            partialResult[row.word] = row.count
        }
    }

    var statsResult: StatsResult {
        StatsResult(
            tokenCount: tokenCount,
            typeCount: typeCount,
            ttr: ttr,
            sttr: sttr,
            sentenceCount: sentenceCount,
            paragraphCount: paragraphCount,
            frequencyRows: frequencyRows
        )
    }
}
