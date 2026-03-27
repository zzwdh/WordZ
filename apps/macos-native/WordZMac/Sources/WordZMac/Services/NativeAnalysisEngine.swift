import Foundation
import NaturalLanguage

struct NativeAnalysisEngine {
    func runStats(text: String) -> StatsResult {
        let document = ParsedDocument(text: text)
        let frequencyMap = frequencyMap(for: document.tokens)
        let sortedRows = frequencyMap
            .map { FrequencyRow(word: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending
                }
                return $0.count > $1.count
            }

        let tokenCount = document.tokens.count
        let typeCount = frequencyMap.count
        let ttr = tokenCount > 0 ? Double(typeCount) / Double(tokenCount) : 0
        let sttr = standardizedTypeTokenRatio(tokens: document.tokens)

        return StatsResult(json: [
            "tokenCount": tokenCount,
            "typeCount": typeCount,
            "ttr": ttr,
            "sttr": sttr,
            "freqRows": sortedRows.map { [$0.word, $0.count] }
        ])
    }

    func runNgram(text: String, n: Int) -> NgramResult {
        let document = ParsedDocument(text: text)
        let safeN = max(1, n)
        var counts: [String: Int] = [:]

        for sentence in document.sentences {
            let tokens = sentence.tokens.map(\.normalized)
            guard tokens.count >= safeN else { continue }
            for start in 0...(tokens.count - safeN) {
                let phrase = tokens[start..<(start + safeN)].joined(separator: " ")
                counts[phrase, default: 0] += 1
            }
        }

        let rows = counts
            .map { NgramRow(phrase: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count {
                    return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
                }
                return $0.count > $1.count
            }

        return NgramResult(json: [
            "n": safeN,
            "rows": rows.map { [$0.phrase, $0.count] }
        ])
    }

    func runWordCloud(text: String, limit: Int) -> WordCloudResult {
        let stats = runStats(text: text)
        let rows = Array(stats.frequencyRows.prefix(max(1, limit)))
        return WordCloudResult(json: [
            "rows": rows.map { [$0.word, $0.count] }
        ])
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) throws -> KWICResult {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let document = ParsedDocument(text: text)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        var rows: [JSONObject] = []

        for sentence in document.sentences {
            for token in sentence.tokens where matcher.matches(token.original) {
                let leftStart = max(0, token.tokenIndex - safeLeft)
                let rightEnd = min(sentence.tokens.count, token.tokenIndex + safeRight + 1)
                let left = sentence.tokens[leftStart..<token.tokenIndex].map(\.original).joined(separator: " ")
                let right = sentence.tokens[(token.tokenIndex + 1)..<rightEnd].map(\.original).joined(separator: " ")
                rows.append([
                    "left": left,
                    "node": token.original,
                    "right": right,
                    "sentenceId": sentence.sentenceId,
                    "sentenceTokenIndex": token.tokenIndex
                ])
            }
        }

        return KWICResult(json: ["rows": rows])
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) throws -> CollocateResult {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let document = ParsedDocument(text: text)
        let frequency = frequencyMap(for: document.tokens)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for sentence in document.sentences {
            for token in sentence.tokens where matcher.matches(token.original) {
                keywordFreq += 1

                let leftStart = max(0, token.tokenIndex - safeLeft)
                if leftStart < token.tokenIndex {
                    for neighbor in sentence.tokens[leftStart..<token.tokenIndex] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        leftByWord[neighbor.normalized, default: 0] += 1
                    }
                }

                let rightEnd = min(sentence.tokens.count, token.tokenIndex + safeRight + 1)
                if token.tokenIndex + 1 < rightEnd {
                    for neighbor in sentence.tokens[(token.tokenIndex + 1)..<rightEnd] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        rightByWord[neighbor.normalized, default: 0] += 1
                    }
                }
            }
        }

        let rows = totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                [
                    "word": word,
                    "total": total,
                    "left": leftByWord[word, default: 0],
                    "right": rightByWord[word, default: 0],
                    "wordFreq": frequency[word, default: 0],
                    "keywordFreq": keywordFreq,
                    "rate": keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0
                ] as JSONObject
            }

        return CollocateResult(items: rows)
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) -> CompareResult {
        let prepared = comparisonEntries.map { entry -> PreparedCompareCorpus in
            let stats = runStats(text: entry.content)
            let frequency = Dictionary(uniqueKeysWithValues: stats.frequencyRows.map { ($0.word, $0.count) })
            return PreparedCompareCorpus(
                entry: entry,
                tokenCount: stats.tokenCount,
                typeCount: stats.typeCount,
                ttr: stats.ttr,
                sttr: stats.sttr,
                topWord: stats.frequencyRows.first?.word ?? "",
                topWordCount: stats.frequencyRows.first?.count ?? 0,
                frequency: frequency
            )
        }

        let allWords = Set(prepared.flatMap { $0.frequency.keys })
        let rows: [JSONObject] = allWords.map { word in
            let perCorpus: [JSONObject] = prepared.map { corpus in
                let count = corpus.frequency[word, default: 0]
                let normFreq = corpus.tokenCount > 0
                    ? (Double(count) / Double(corpus.tokenCount)) * 10_000
                    : 0
                return [
                    "corpusId": corpus.entry.corpusId,
                    "corpusName": corpus.entry.corpusName,
                    "folderName": corpus.entry.folderName,
                    "count": count,
                    "normFreq": normFreq
                ]
            }

            let total = perCorpus.reduce(0) { $0 + (JSONFieldReader.int($1, key: "count")) }
            let spread = perCorpus.filter { JSONFieldReader.int($0, key: "count") > 0 }.count
            let normFreqs = perCorpus.map { JSONFieldReader.double($0, key: "normFreq") }
            let range = (normFreqs.max() ?? 0) - (normFreqs.min() ?? 0)
            let dominant = perCorpus.max { lhs, rhs in
                JSONFieldReader.int(lhs, key: "count") < JSONFieldReader.int(rhs, key: "count")
            }

            return [
                "word": word,
                "total": total,
                "spread": spread,
                "range": range,
                "dominantCorpusName": JSONFieldReader.string(dominant ?? [:], key: "corpusName"),
                "perCorpus": perCorpus
            ] as JSONObject
        }

        let corpora: [JSONObject] = prepared.map { corpus in
            [
                "corpusId": corpus.entry.corpusId,
                "corpusName": corpus.entry.corpusName,
                "folderName": corpus.entry.folderName,
                "tokenCount": corpus.tokenCount,
                "typeCount": corpus.typeCount,
                "ttr": corpus.ttr,
                "sttr": corpus.sttr,
                "topWord": corpus.topWord,
                "topWordCount": corpus.topWordCount
            ]
        }

        return CompareResult(json: [
            "corpora": corpora,
            "rows": rows
        ])
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) -> ChiSquareResult {
        let aa = Double(max(0, a))
        let bb = Double(max(0, b))
        let cc = Double(max(0, c))
        let dd = Double(max(0, d))

        let rowTotals = [aa + bb, cc + dd]
        let colTotals = [aa + cc, bb + dd]
        let total = rowTotals.reduce(0, +)

        let expected = [
            [rowTotals[0] * colTotals[0] / max(total, 1), rowTotals[0] * colTotals[1] / max(total, 1)],
            [rowTotals[1] * colTotals[0] / max(total, 1), rowTotals[1] * colTotals[1] / max(total, 1)]
        ]

        let observed = [[aa, bb], [cc, dd]]
        let correction = yates ? 0.5 : 0.0
        var chiSquare = 0.0
        for rowIndex in 0..<2 {
            for colIndex in 0..<2 {
                let obs = observed[rowIndex][colIndex]
                let exp = expected[rowIndex][colIndex]
                guard exp > 0 else { continue }
                let delta = max(0, abs(obs - exp) - correction)
                chiSquare += (delta * delta) / exp
            }
        }

        let totalInt = Int(total.rounded())
        let pValue = erfc(sqrt(max(chiSquare, 0) / 2))
        let phi = total > 0 ? sqrt(chiSquare / total) : 0
        let oddsRatio: Double?
        if bb == 0 || cc == 0 {
            oddsRatio = nil
        } else {
            oddsRatio = (aa * dd) / (bb * cc)
        }

        var warnings: [String] = []
        if expected.flatMap({ $0 }).contains(where: { $0 < 5 }) {
            warnings.append("期望频数中存在小于 5 的单元格，结果需谨慎解释。")
        }

        return ChiSquareResult(json: [
            "observed": observed,
            "expected": expected,
            "rowTotals": rowTotals,
            "colTotals": colTotals,
            "total": totalInt,
            "chiSquare": chiSquare,
            "degreesOfFreedom": 1,
            "pValue": pValue,
            "significantAt05": pValue < 0.05,
            "significantAt01": pValue < 0.01,
            "phi": phi,
            "oddsRatio": oddsRatio as Any,
            "yatesCorrection": yates,
            "warnings": warnings
        ])
    }

    func runLocator(
        text: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) -> LocatorResult {
        let document = ParsedDocument(text: text)
        guard !document.sentences.isEmpty else {
            return LocatorResult(json: ["sentences": [], "rows": []])
        }

        let safeSentenceId = min(max(sentenceId, 0), document.sentences.count - 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let start = max(0, safeSentenceId - safeLeft)
        let end = min(document.sentences.count - 1, safeSentenceId + safeRight)

        let sourceSentence = document.sentences[safeSentenceId]
        let sourceNodeIndex = min(max(nodeIndex, 0), max(sourceSentence.tokens.count - 1, 0))
        let sourceNode = sourceSentence.tokens.isEmpty ? nil : sourceSentence.tokens[sourceNodeIndex]

        let rows: [JSONObject] = Array(document.sentences[start...end]).map { sentence in
            let isCurrent = sentence.sentenceId == safeSentenceId
            let status: String
            if isCurrent {
                status = "当前"
            } else if sentence.sentenceId < safeSentenceId {
                status = "前文"
            } else {
                status = "后文"
            }

            let leftWords = isCurrent && sourceNode != nil
                ? sentence.tokens.prefix(sourceNodeIndex).map(\.original).joined(separator: " ")
                : ""
            let nodeWord = isCurrent ? (sourceNode?.original ?? "") : ""
            let rightWords = isCurrent && sourceNode != nil
                ? sentence.tokens.dropFirst(min(sourceNodeIndex + 1, sentence.tokens.count)).map(\.original).joined(separator: " ")
                : ""

            return [
                "sentenceId": sentence.sentenceId,
                "text": sentence.text,
                "leftWords": leftWords,
                "nodeWord": nodeWord,
                "rightWords": rightWords,
                "status": status
            ]
        }

        return LocatorResult(json: [
            "sentences": document.sentences.map { ["sentenceId": $0.sentenceId, "text": $0.text] },
            "rows": rows
        ])
    }

    private func frequencyMap(for tokens: [ParsedToken]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for token in tokens {
            counts[token.normalized, default: 0] += 1
        }
        return counts
    }

    private func standardizedTypeTokenRatio(tokens: [ParsedToken], chunkSize: Int = 1000) -> Double {
        guard !tokens.isEmpty else { return 0 }
        guard tokens.count > chunkSize else {
            let unique = Set(tokens.map(\.normalized)).count
            return Double(unique) / Double(tokens.count)
        }

        var ratios: [Double] = []
        var index = 0
        while index < tokens.count {
            let end = min(index + chunkSize, tokens.count)
            let chunk = tokens[index..<end]
            let unique = Set(chunk.map(\.normalized)).count
            ratios.append(Double(unique) / Double(chunk.count))
            index += chunkSize
        }
        return ratios.reduce(0, +) / Double(ratios.count)
    }
}

private struct PreparedCompareCorpus {
    let entry: CompareRequestEntry
    let tokenCount: Int
    let typeCount: Int
    let ttr: Double
    let sttr: Double
    let topWord: String
    let topWordCount: Int
    let frequency: [String: Int]
}

private struct ParsedDocument {
    let sentences: [ParsedSentence]
    let tokens: [ParsedToken]

    init(text: String) {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = normalizedText
        var parsedSentences: [ParsedSentence] = []
        sentenceTokenizer.enumerateTokens(in: normalizedText.startIndex..<normalizedText.endIndex) { range, _ in
            let sentenceText = String(normalizedText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentenceText.isEmpty else { return true }
            let sentenceId = parsedSentences.count
            let tokens = ParsedDocument.tokenizeWords(in: sentenceText, sentenceId: sentenceId)
            parsedSentences.append(ParsedSentence(sentenceId: sentenceId, text: sentenceText, tokens: tokens))
            return true
        }

        if parsedSentences.isEmpty {
            let fallbackText = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = ParsedDocument.tokenizeWords(in: fallbackText, sentenceId: 0)
            parsedSentences = [ParsedSentence(sentenceId: 0, text: fallbackText, tokens: tokens)]
        }

        self.sentences = parsedSentences
        self.tokens = parsedSentences.flatMap(\.tokens)
    }

    private static func tokenizeWords(in text: String, sentenceId: Int) -> [ParsedToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [ParsedToken] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.range(of: #"\p{L}|\p{N}"#, options: .regularExpression) != nil else {
                return true
            }
            let token = ParsedToken(
                original: value,
                normalized: value.lowercased(),
                sentenceId: sentenceId,
                tokenIndex: tokens.count
            )
            tokens.append(token)
            return true
        }
        return tokens
    }
}

private struct ParsedSentence {
    let sentenceId: Int
    let text: String
    let tokens: [ParsedToken]
}

private struct ParsedToken: Hashable {
    let original: String
    let normalized: String
    let sentenceId: Int
    let tokenIndex: Int
}
