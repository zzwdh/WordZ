import Foundation

enum CollocateAssociationCalculator {
    struct Sentence: Sendable {
        let sentenceId: Int
        let tokens: [String]

        init(sentenceId: Int, tokens: [String]) {
            self.sentenceId = sentenceId
            self.tokens = tokens
        }

        init(_ sentence: TokenizedSentence) {
            self.sentenceId = sentence.sentenceId
            self.tokens = sentence.tokens.map(\.normalized)
        }

        init(_ sentence: ParsedSentence) {
            self.sentenceId = sentence.sentenceId
            self.tokens = sentence.tokens.map(\.normalized)
        }
    }

    struct NodeRange: Sendable {
        let sentenceId: Int
        let startIndex: Int
        let endIndex: Int
    }

    static func calculate(
        sentences: [Sentence],
        nodeRanges: [NodeRange],
        frequencyMap: [String: Int],
        tokenCount: Int,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int
    ) -> [CollocateRow] {
        let sentenceByID = Dictionary(uniqueKeysWithValues: sentences.map { ($0.sentenceId, $0) })
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        let safeTokenCount = max(tokenCount, 1)
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for nodeRange in nodeRanges {
            guard let sentence = sentenceByID[nodeRange.sentenceId],
                  sentence.tokens.indices.contains(nodeRange.startIndex),
                  sentence.tokens.indices.contains(nodeRange.endIndex),
                  nodeRange.startIndex <= nodeRange.endIndex else {
                continue
            }

            keywordFreq += 1
            let leftStart = max(0, nodeRange.startIndex - safeLeft)
            if leftStart < nodeRange.startIndex {
                for neighbor in sentence.tokens[leftStart..<nodeRange.startIndex] where !neighbor.isEmpty {
                    totalByWord[neighbor, default: 0] += 1
                    leftByWord[neighbor, default: 0] += 1
                }
            }

            let rightEnd = min(sentence.tokens.count, nodeRange.endIndex + safeRight + 1)
            if nodeRange.endIndex + 1 < rightEnd {
                for neighbor in sentence.tokens[(nodeRange.endIndex + 1)..<rightEnd] where !neighbor.isEmpty {
                    totalByWord[neighbor, default: 0] += 1
                    rightByWord[neighbor, default: 0] += 1
                }
            }
        }

        return totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                let wordFreq = frequencyMap[word, default: 0]
                let observed = Double(total)
                let expected = (Double(keywordFreq) * Double(wordFreq)) / Double(safeTokenCount)
                let mutualInformation = expected > 0 && observed > 0
                    ? log2(observed / expected)
                    : 0
                let tScore = observed > 0
                    ? (observed - expected) / sqrt(observed)
                    : 0
                let logDice = (keywordFreq + wordFreq) > 0 && observed > 0
                    ? 14 + log2((2 * observed) / Double(keywordFreq + wordFreq))
                    : 0
                return CollocateRow(
                    word: word,
                    total: total,
                    left: leftByWord[word, default: 0],
                    right: rightByWord[word, default: 0],
                    wordFreq: wordFreq,
                    keywordFreq: keywordFreq,
                    rate: keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0,
                    logDice: logDice,
                    mutualInformation: mutualInformation,
                    tScore: tScore
                )
            }
            .sorted {
                $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
            }
    }
}
