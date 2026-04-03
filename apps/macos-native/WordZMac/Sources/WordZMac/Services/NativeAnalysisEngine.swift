import CryptoKit
import Foundation
import NaturalLanguage

final class NativeAnalysisEngine {
    private let maxCachedDocuments: Int
    private var documentCache: [DocumentCacheKey: ParsedDocumentIndex] = [:]
    private var cacheOrder: [DocumentCacheKey] = []

    init(maxCachedDocuments: Int = 6) {
        self.maxCachedDocuments = max(1, maxCachedDocuments)
    }

    var cachedDocumentCountForTesting: Int {
        documentCache.count
    }

    var cachedFrequencySummaryCountForTesting: Int {
        documentCache.values.reduce(0) { partialResult, index in
            partialResult + (index.hasComputedFrequencySummary ? 1 : 0)
        }
    }

    func runStats(text: String) -> StatsResult {
        let index = indexedDocument(for: text)

        return StatsResult(json: [
            "tokenCount": index.tokenCount,
            "typeCount": index.typeCount,
            "ttr": index.ttr,
            "sttr": index.sttr,
            "sentenceCount": index.sentenceCount,
            "paragraphCount": index.paragraphCount,
            "freqRows": index.sortedFrequencyRows.map { row in
                [
                    "word": row.word,
                    "count": row.count,
                    "rank": row.rank,
                    "normFreq": row.normFreq,
                    "range": row.range,
                    "normRange": row.normRange,
                    "sentenceRange": row.sentenceRange,
                    "paragraphRange": row.paragraphRange
                ]
            }
        ])
    }

    func runNgram(text: String, n: Int) -> NgramResult {
        let document = indexedDocument(for: text).document
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
        _ = limit
        let rows = indexedDocument(for: text).sortedFrequencyRows
        return WordCloudResult(json: [
            "rows": rows.map { [$0.word, $0.count] }
        ])
    }

    func runTokenize(text: String) -> TokenizeResult {
        let document = indexedDocument(for: text).document
        return TokenizeResult(
            sentences: document.sentences.map { sentence in
                TokenizedSentence(
                    sentenceId: sentence.sentenceId,
                    text: sentence.text,
                    tokens: sentence.tokens.map { token in
                        TokenizedToken(
                            original: token.original,
                            normalized: token.normalized,
                            sentenceId: token.sentenceId,
                            tokenIndex: token.tokenIndex
                        )
                    }
                )
            }
        )
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

        let document = indexedDocument(for: text).document
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

        let index = indexedDocument(for: text)
        let document = index.document
        let frequency = index.frequencyMap
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
            let index = indexedDocument(for: entry.content)
            return PreparedCompareCorpus(
                entry: entry,
                tokenCount: index.tokenCount,
                typeCount: index.typeCount,
                ttr: index.ttr,
                sttr: index.sttr,
                topWord: index.sortedFrequencyRows.first?.word ?? "",
                topWordCount: index.sortedFrequencyRows.first?.count ?? 0,
                frequency: index.frequencyMap
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
                    "tokenCount": corpus.tokenCount,
                    "normFreq": normFreq
                ]
            }

            let total = perCorpus.reduce(0) { $0 + (JSONFieldReader.int($1, key: "count")) }
            let spread = perCorpus.filter { JSONFieldReader.int($0, key: "count") > 0 }.count
            let normFreqs = perCorpus.map { JSONFieldReader.double($0, key: "normFreq") }
            let range = (normFreqs.max() ?? 0) - (normFreqs.min() ?? 0)
            let dominant = perCorpus.max { lhs, rhs in
                let lhsNorm = JSONFieldReader.double(lhs, key: "normFreq")
                let rhsNorm = JSONFieldReader.double(rhs, key: "normFreq")
                if lhsNorm == rhsNorm {
                    return JSONFieldReader.int(lhs, key: "count") < JSONFieldReader.int(rhs, key: "count")
                }
                return lhsNorm < rhsNorm
            }
            let dominantCount = JSONFieldReader.int(dominant ?? [:], key: "count")
            let dominantTokenCount = JSONFieldReader.int(dominant ?? [:], key: "tokenCount")
            let referenceCount = max(0, total - dominantCount)
            let referenceTokenCount = max(0, prepared.reduce(0) { $0 + $1.tokenCount } - dominantTokenCount)
            let referenceNormFreq = referenceTokenCount > 0
                ? (Double(referenceCount) / Double(referenceTokenCount)) * 10_000
                : 0
            let keyness = Self.signedLogLikelihood(
                targetCount: dominantCount,
                targetTokenCount: dominantTokenCount,
                referenceCount: referenceCount,
                referenceTokenCount: referenceTokenCount
            )
            let effectSize = Self.logRatio(
                targetCount: dominantCount,
                targetTokenCount: dominantTokenCount,
                referenceCount: referenceCount,
                referenceTokenCount: referenceTokenCount
            )
            let pValue = erfc(sqrt(abs(keyness) / 2))

            return [
                "word": word,
                "total": total,
                "spread": spread,
                "range": range,
                "dominantCorpusName": JSONFieldReader.string(dominant ?? [:], key: "corpusName"),
                "keyness": keyness,
                "effectSize": effectSize,
                "pValue": pValue,
                "referenceNormFreq": referenceNormFreq,
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
        let document = indexedDocument(for: text).document
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

    private func indexedDocument(for text: String) -> ParsedDocumentIndex {
        let key = DocumentCacheKey(text: text)
        if let entry = documentCache[key] {
            touchCacheKey(key)
            return entry
        }

        let index = ParsedDocumentIndex(text: text)
        documentCache[key] = index
        touchCacheKey(key)
        trimCacheIfNeeded()
        return index
    }

    private func touchCacheKey(_ key: DocumentCacheKey) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func trimCacheIfNeeded() {
        while cacheOrder.count > maxCachedDocuments {
            let evicted = cacheOrder.removeFirst()
            documentCache.removeValue(forKey: evicted)
        }
    }

    fileprivate static func buildFrequencyMap(for tokens: [ParsedToken]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for token in tokens {
            counts[token.normalized, default: 0] += 1
        }
        return counts
    }

    fileprivate static func buildStandardizedTypeTokenRatio(tokens: [ParsedToken], chunkSize: Int = 1000) -> Double {
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

    private static func signedLogLikelihood(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let target = Double(max(0, targetCount))
        let reference = Double(max(0, referenceCount))
        let targetTotal = Double(max(0, targetTokenCount))
        let referenceTotal = Double(max(0, referenceTokenCount))
        let grandTotal = targetTotal + referenceTotal
        let observedTotal = target + reference

        guard targetTotal > 0, referenceTotal > 0, grandTotal > 0, observedTotal > 0 else {
            return 0
        }

        let pooledRate = observedTotal / grandTotal
        let expectedTarget = targetTotal * pooledRate
        let expectedReference = referenceTotal * pooledRate
        let targetTerm = target > 0 && expectedTarget > 0 ? target * log(target / expectedTarget) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * log(reference / expectedReference) : 0
        let statistic = 2 * (targetTerm + referenceTerm)

        let targetRate = target / targetTotal
        let referenceRate = reference / referenceTotal
        let sign = targetRate >= referenceRate ? 1.0 : -1.0
        return statistic * sign
    }

    private static func logRatio(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let targetRate = (Double(max(0, targetCount)) + 0.5) / (Double(max(0, targetTokenCount)) + 1)
        let referenceRate = (Double(max(0, referenceCount)) + 0.5) / (Double(max(0, referenceTokenCount)) + 1)
        guard targetRate > 0, referenceRate > 0 else { return 0 }
        return log2(targetRate / referenceRate)
    }
}

private struct DocumentCacheKey: Hashable {
    let textLength: Int
    let textDigest: String

    init(text: String) {
        let data = Data(text.utf8)
        self.textLength = data.count
        self.textDigest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

private final class ParsedDocumentIndex {
    let document: ParsedDocument
    private var cachedFrequencySummary: FrequencySummary?

    init(text: String) {
        self.document = ParsedDocument(text: text)
    }

    var frequencyMap: [String: Int] {
        frequencySummary.frequencyMap
    }

    var sortedFrequencyRows: [FrequencyRow] {
        frequencySummary.sortedFrequencyRows
    }

    var tokenCount: Int {
        document.tokens.count
    }

    var typeCount: Int {
        frequencySummary.typeCount
    }

    var paragraphCount: Int {
        document.paragraphs.count
    }

    var sentenceCount: Int {
        document.sentences.count
    }

    var ttr: Double {
        frequencySummary.ttr
    }

    var sttr: Double {
        frequencySummary.sttr
    }

    var hasComputedFrequencySummary: Bool {
        cachedFrequencySummary != nil
    }

    private var frequencySummary: FrequencySummary {
        if let cachedFrequencySummary {
            return cachedFrequencySummary
        }

        let summary = FrequencySummary(document: document)
        cachedFrequencySummary = summary
        return summary
    }
}

private struct FrequencySummary {
    let frequencyMap: [String: Int]
    let sortedFrequencyRows: [FrequencyRow]
    let typeCount: Int
    let ttr: Double
    let sttr: Double

    init(document: ParsedDocument) {
        let tokens = document.tokens
        let frequencyMap = NativeAnalysisEngine.buildFrequencyMap(for: tokens)
        let sentenceCount = max(document.sentences.count, 1)
        var sentenceRangeMap: [String: Int] = [:]
        for sentence in document.sentences {
            let words = Set(sentence.tokens.map(\.normalized))
            for word in words {
                sentenceRangeMap[word, default: 0] += 1
            }
        }
        var paragraphRangeMap: [String: Int] = [:]
        for paragraph in document.paragraphs {
            let words = Set(paragraph.tokens.map(\.normalized))
            for word in words {
                paragraphRangeMap[word, default: 0] += 1
            }
        }
        self.frequencyMap = frequencyMap
        self.sortedFrequencyRows = frequencyMap
            .sorted {
                if $0.value == $1.value {
                    return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending
                }
                return $0.value > $1.value
            }
            .enumerated()
            .map { index, element in
                let normFreq = tokens.isEmpty ? 0 : (Double(element.value) / Double(tokens.count)) * 10_000
                let sentenceRange = sentenceRangeMap[element.key, default: 0]
                let paragraphRange = paragraphRangeMap[element.key, default: 0]
                let normRange = (Double(sentenceRange) / Double(sentenceCount)) * 100
                return FrequencyRow(
                    word: element.key,
                    count: element.value,
                    rank: index + 1,
                    normFreq: normFreq,
                    range: sentenceRange,
                    normRange: normRange,
                    sentenceRange: sentenceRange,
                    paragraphRange: paragraphRange
                )
            }
        self.typeCount = frequencyMap.count
        self.ttr = tokens.isEmpty ? 0 : Double(frequencyMap.count) / Double(tokens.count)
        self.sttr = NativeAnalysisEngine.buildStandardizedTypeTokenRatio(tokens: tokens)
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
    let paragraphs: [ParsedParagraph]
    let sentences: [ParsedSentence]
    let tokens: [ParsedToken]

    init(text: String) {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n")
        let rawParagraphs = ParsedDocument.splitParagraphs(in: normalizedText)
        var parsedParagraphs: [ParsedParagraph] = []
        var parsedSentences: [ParsedSentence] = []

        for paragraphText in rawParagraphs {
            let paragraphId = parsedParagraphs.count
            let sentenceTokenizer = NLTokenizer(unit: .sentence)
            sentenceTokenizer.string = paragraphText
            let sentenceStartIndex = parsedSentences.count
            sentenceTokenizer.enumerateTokens(in: paragraphText.startIndex..<paragraphText.endIndex) { range, _ in
                let sentenceText = String(paragraphText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sentenceText.isEmpty else { return true }
                let sentenceId = parsedSentences.count
                let tokens = ParsedDocument.tokenizeWords(in: sentenceText, sentenceId: sentenceId)
                parsedSentences.append(
                    ParsedSentence(
                        sentenceId: sentenceId,
                        paragraphId: paragraphId,
                        text: sentenceText,
                        tokens: tokens
                    )
                )
                return true
            }
            if parsedSentences.count == sentenceStartIndex {
                let sentenceId = parsedSentences.count
                let tokens = ParsedDocument.tokenizeWords(in: paragraphText, sentenceId: sentenceId)
                parsedSentences.append(
                    ParsedSentence(
                        sentenceId: sentenceId,
                        paragraphId: paragraphId,
                        text: paragraphText,
                        tokens: tokens
                    )
                )
            }
            let paragraphSentences = Array(parsedSentences[sentenceStartIndex..<parsedSentences.count])
            let paragraphTokens = paragraphSentences.flatMap(\.tokens)
            parsedParagraphs.append(
                ParsedParagraph(
                    paragraphId: paragraphId,
                    text: paragraphText,
                    sentenceIDs: paragraphSentences.map(\.sentenceId),
                    tokens: paragraphTokens
                )
            )
        }

        if parsedSentences.isEmpty {
            let fallbackText = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let tokens = ParsedDocument.tokenizeWords(in: fallbackText, sentenceId: 0)
            parsedSentences = [ParsedSentence(sentenceId: 0, paragraphId: 0, text: fallbackText, tokens: tokens)]
            parsedParagraphs = [
                ParsedParagraph(
                    paragraphId: 0,
                    text: fallbackText,
                    sentenceIDs: [0],
                    tokens: tokens
                )
            ]
        }

        self.paragraphs = parsedParagraphs
        self.sentences = parsedSentences
        self.tokens = parsedSentences.flatMap(\.tokens)
    }

    private static func splitParagraphs(in text: String) -> [String] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [""] }
        let nsRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let ranges = blankLineSeparator.matches(in: normalized, range: nsRange).compactMap {
            Range($0.range, in: normalized)
        }
        guard !ranges.isEmpty else { return [normalized] }
        var paragraphs: [String] = []
        var cursor = normalized.startIndex
        for range in ranges {
            let value = String(normalized[cursor..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                paragraphs.append(value)
            }
            cursor = range.upperBound
        }
        let tail = String(normalized[cursor..<normalized.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            paragraphs.append(tail)
        }
        return paragraphs.isEmpty ? [normalized] : paragraphs
    }

    private static let blankLineSeparator = try! NSRegularExpression(pattern: #"\n\s*\n+"#)

    private static func tokenizeWords(in text: String, sentenceId: Int) -> [ParsedToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [ParsedToken] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard AnalysisTextNormalizationSupport.containsWordLikeContent(value) else {
                return true
            }
            let token = ParsedToken(
                original: value,
                normalized: AnalysisTextNormalizationSupport.normalizeToken(value),
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
    let paragraphId: Int
    let text: String
    let tokens: [ParsedToken]
}

private struct ParsedParagraph {
    let paragraphId: Int
    let text: String
    let sentenceIDs: [Int]
    let tokens: [ParsedToken]
}

private struct ParsedToken: Hashable {
    let original: String
    let normalized: String
    let sentenceId: Int
    let tokenIndex: Int
}
