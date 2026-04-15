import CryptoKit
import Foundation
import NaturalLanguage

// NaturalLanguage tokenization/tagging becomes nondeterministic under aggressive parallel test load.
private let parsedDocumentNaturalLanguageLock = NSLock()

struct DocumentCacheKey: Hashable, Sendable {
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

final class ParsedDocumentIndex: @unchecked Sendable {
    let document: ParsedDocument
    private let frequencySummaryLock = NSLock()
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
        frequencySummaryLock.lock()
        defer { frequencySummaryLock.unlock() }
        return cachedFrequencySummary != nil
    }

    private var frequencySummary: FrequencySummary {
        frequencySummaryLock.lock()
        defer { frequencySummaryLock.unlock() }
        if let cachedFrequencySummary {
            return cachedFrequencySummary
        }

        let summary = FrequencySummary(document: document)
        cachedFrequencySummary = summary
        return summary
    }
}

struct FrequencySummary: Sendable {
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

struct PreparedCompareCorpus: Sendable {
    let entry: CompareRequestEntry
    let tokenCount: Int
    let typeCount: Int
    let ttr: Double
    let sttr: Double
    let topWord: String
    let topWordCount: Int
    let frequency: [String: Int]
}

struct ParsedDocument: Sendable {
    let paragraphs: [ParsedParagraph]
    let sentences: [ParsedSentence]
    let tokens: [ParsedToken]

    init(text: String) {
        let parsed = Self.parse(text: text)
        self.paragraphs = parsed.paragraphs
        self.sentences = parsed.sentences
        self.tokens = parsed.sentences.flatMap(\.tokens)
    }

    private static func parse(text: String) -> (paragraphs: [ParsedParagraph], sentences: [ParsedSentence]) {
        parsedDocumentNaturalLanguageLock.lock()
        defer { parsedDocumentNaturalLanguageLock.unlock() }

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

        return (parsedParagraphs, parsedSentences)
    }

    private static func splitParagraphs(in text: String) -> [String] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [""] }
        var paragraphs: [String] = []
        var currentLines: [String] = []

        normalized.enumerateLines { line, _ in
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraphLines(&currentLines, into: &paragraphs)
            } else {
                currentLines.append(line)
            }
        }

        flushParagraphLines(&currentLines, into: &paragraphs)
        return paragraphs.isEmpty ? [normalized] : paragraphs
    }

    private static func flushParagraphLines(_ lines: inout [String], into paragraphs: inout [String]) {
        guard !lines.isEmpty else { return }
        let paragraph = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !paragraph.isEmpty {
            paragraphs.append(paragraph)
        }
        lines.removeAll(keepingCapacity: true)
    }

    private static func tokenizeWords(in text: String, sentenceId: Int) -> [ParsedToken] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tagger = NLTagger(tagSchemes: [.lemma, .lexicalClass])
        tagger.string = text
        var tokens: [ParsedToken] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard AnalysisTextNormalizationSupport.containsWordLikeContent(value) else {
                return true
            }
            let annotations = LinguisticAnnotationSupport.makeAnnotations(
                for: value,
                in: text,
                at: range.lowerBound,
                tagger: tagger
            )
            let token = ParsedToken(
                original: value,
                normalized: AnalysisTextNormalizationSupport.normalizeToken(value),
                sentenceId: sentenceId,
                tokenIndex: tokens.count,
                annotations: annotations
            )
            tokens.append(token)
            return true
        }
        return tokens
    }
}

struct ParsedSentence: Sendable {
    let sentenceId: Int
    let paragraphId: Int
    let text: String
    let tokens: [ParsedToken]
}

struct ParsedParagraph: Sendable {
    let paragraphId: Int
    let text: String
    let sentenceIDs: [Int]
    let tokens: [ParsedToken]
}

struct ParsedToken: Hashable, Sendable {
    let original: String
    let normalized: String
    let sentenceId: Int
    let tokenIndex: Int
    let annotations: TokenLinguisticAnnotations
}
