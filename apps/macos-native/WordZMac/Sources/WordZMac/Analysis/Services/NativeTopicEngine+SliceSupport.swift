import CryptoKit
import Foundation
import NaturalLanguage

private struct TopicSliceChunk {
    let paragraphIndex: Int
    let text: String
    let tokens: [String]
    let keywordTerms: [String]
    let keywordBigrams: [String]

    var isSmall: Bool {
        tokens.count < 5 && keywordTerms.count < 2
    }
}

extension NativeTopicEngine {
    private static let defaultStopwords = Set(StopwordFilterState.default.parsedWords)

    func makeSlices(for text: String, cacheKey: String) throws -> [TopicTextSlice] {
        if let cached = sliceCache[cacheKey] {
            touchSliceCacheKey(cacheKey)
            return cached
        }

        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text
        var paragraphTexts: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                paragraphTexts.append(paragraph)
            }
            return true
        }

        var chunks: [TopicSliceChunk] = []
        for (paragraphOffset, paragraphText) in paragraphTexts.enumerated() {
            chunks.append(contentsOf: sliceChunks(in: paragraphText, paragraphIndex: paragraphOffset + 1))
        }

        guard !chunks.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }

        var occurrenceCountsByHash: [String: Int] = [:]
        let slices = chunks.enumerated().map { offset, chunk -> TopicTextSlice in
            let hash = Self.stableHash(for: chunk.text)
            occurrenceCountsByHash[hash, default: 0] += 1
            let occurrence = occurrenceCountsByHash[hash] ?? 1
            let uniqueID = occurrence == 1 ? hash : "\(hash)-\(occurrence)"
            return TopicTextSlice(
                id: "slice-p\(chunk.paragraphIndex)-\(offset + 1)-\(uniqueID)",
                paragraphIndex: chunk.paragraphIndex,
                text: chunk.text,
                tokens: chunk.tokens,
                keywordTerms: chunk.keywordTerms,
                keywordBigrams: chunk.keywordBigrams
            )
        }

        sliceCache[cacheKey] = slices
        sliceCacheOrder.removeAll(where: { $0 == cacheKey })
        sliceCacheOrder.append(cacheKey)
        if sliceCacheOrder.count > maxSliceCacheEntries, let evicted = sliceCacheOrder.first {
            sliceCache.removeValue(forKey: evicted)
            sliceCacheOrder.removeFirst()
        }
        return slices
    }

    func touchSliceCacheKey(_ cacheKey: String) {
        sliceCacheOrder.removeAll(where: { $0 == cacheKey })
        sliceCacheOrder.append(cacheKey)
    }

    fileprivate func sliceChunks(in paragraph: String, paragraphIndex: Int) -> [TopicSliceChunk] {
        let sentences = sentenceTexts(in: paragraph)
            .flatMap { refinedSentenceUnits(from: $0) }
        guard !sentences.isEmpty else {
            return buildChunk(text: paragraph, paragraphIndex: paragraphIndex).map { [$0] } ?? []
        }

        var rawChunks: [String] = []
        var currentSentences: [String] = []
        var currentTokenBudget = 0

        for sentence in sentences {
            let sentenceTokenCount = TopicFilterSupport.tokenize(sentence).count
            let shouldSplit = !currentSentences.isEmpty && (
                currentSentences.count >= 2
                || (currentTokenBudget >= 32 && currentTokenBudget + sentenceTokenCount > 56)
                || currentTokenBudget + sentenceTokenCount > 72
            )

            if shouldSplit {
                rawChunks.append(currentSentences.joined(separator: " "))
                currentSentences = [sentence]
                currentTokenBudget = sentenceTokenCount
            } else {
                currentSentences.append(sentence)
                currentTokenBudget += sentenceTokenCount
            }
        }

        if !currentSentences.isEmpty {
            rawChunks.append(currentSentences.joined(separator: " "))
        }

        var chunks = rawChunks.compactMap { buildChunk(text: $0, paragraphIndex: paragraphIndex) }
        if chunks.isEmpty, let fallback = buildChunk(text: paragraph, paragraphIndex: paragraphIndex) {
            chunks = [fallback]
        }
        return mergeSmallChunks(chunks)
    }

    func refinedSentenceUnits(from sentence: String) -> [String] {
        let normalized = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        guard TopicFilterSupport.tokenize(normalized).count > 56 else {
            return [normalized]
        }

        let clauseSegments = splitTopicClauseText(normalized, separators: [";", ":"])
        let primarySegments = clauseSegments.count > 1 ? clauseSegments : [normalized]

        var refined: [String] = []
        refined.reserveCapacity(primarySegments.count)
        for segment in primarySegments {
            if TopicFilterSupport.tokenize(segment).count > 56 {
                let commaSegments = splitTopicClauseText(segment, separators: [","])
                if commaSegments.count > 1 {
                    refined.append(contentsOf: commaSegments)
                    continue
                }
            }
            refined.append(segment)
        }
        return refined.filter { !$0.isEmpty }
    }

    func splitTopicClauseText(
        _ text: String,
        separators: Set<Character>
    ) -> [String] {
        text
            .split(whereSeparator: { separators.contains($0) })
            .map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    func sentenceTexts(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        if sentences.isEmpty {
            return [text.trimmingCharacters(in: .whitespacesAndNewlines)].filter { !$0.isEmpty }
        }
        return sentences
    }

    fileprivate func buildChunk(text: String, paragraphIndex: Int) -> TopicSliceChunk? {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return nil }

        let terms = englishTerms(for: normalizedText)
        guard !terms.tokens.isEmpty || !terms.keywordTerms.isEmpty else {
            return nil
        }

        return TopicSliceChunk(
            paragraphIndex: paragraphIndex,
            text: normalizedText,
            tokens: terms.tokens,
            keywordTerms: terms.keywordTerms,
            keywordBigrams: terms.keywordBigrams
        )
    }

    fileprivate func mergeSmallChunks(_ chunks: [TopicSliceChunk]) -> [TopicSliceChunk] {
        guard chunks.count > 1 else { return chunks }

        var working = chunks
        var index = 0
        while index < working.count {
            guard working[index].isSmall, working.count > 1 else {
                index += 1
                continue
            }

            let paragraphIndex = working[index].paragraphIndex
            let mergeIndex: Int
            if index == 0 {
                mergeIndex = 1
            } else if index == working.count - 1 {
                mergeIndex = index - 1
            } else {
                let previousAffinity = mergeAffinity(
                    between: working[index],
                    and: working[index - 1]
                )
                let nextAffinity = mergeAffinity(
                    between: working[index],
                    and: working[index + 1]
                )
                if previousAffinity == nextAffinity {
                    mergeIndex = working[index - 1].tokens.count <= working[index + 1].tokens.count
                        ? index - 1
                        : index + 1
                } else {
                    mergeIndex = previousAffinity > nextAffinity ? index - 1 : index + 1
                }
            }

            let mergedText: String
            let replacementIndex: Int
            let removalIndex: Int
            if mergeIndex < index {
                mergedText = working[mergeIndex].text + " " + working[index].text
                replacementIndex = mergeIndex
                removalIndex = index
            } else {
                mergedText = working[index].text + " " + working[mergeIndex].text
                replacementIndex = index
                removalIndex = mergeIndex
            }

            guard let mergedChunk = buildChunk(text: mergedText, paragraphIndex: paragraphIndex) else {
                index += 1
                continue
            }

            working[replacementIndex] = mergedChunk
            working.remove(at: removalIndex)
            index = max(0, replacementIndex - 1)
        }

        return working
    }

    fileprivate func mergeAffinity(
        between lhs: TopicSliceChunk,
        and rhs: TopicSliceChunk
    ) -> Double {
        let lhsKeywords = Set(lhs.keywordTerms)
        let rhsKeywords = Set(rhs.keywordTerms)
        let keywordUnion = lhsKeywords.union(rhsKeywords)
        let keywordOverlap = keywordUnion.isEmpty
            ? 0
            : Double(lhsKeywords.intersection(rhsKeywords).count) / Double(keywordUnion.count)
        let tokenCosine = tokenBagCosineSimilarity(lhs.tokens, rhs.tokens)
        return (keywordOverlap * 0.65) + (tokenCosine * 0.35)
    }

    func tokenBagCosineSimilarity(
        _ lhsTokens: [String],
        _ rhsTokens: [String]
    ) -> Double {
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let lhsCounts = Dictionary(grouping: lhsTokens, by: { $0 }).mapValues(\.count)
        let rhsCounts = Dictionary(grouping: rhsTokens, by: { $0 }).mapValues(\.count)
        let sharedTerms = Set(lhsCounts.keys).intersection(rhsCounts.keys)
        let numerator = sharedTerms.reduce(0.0) { partialResult, term in
            partialResult + Double((lhsCounts[term] ?? 0) * (rhsCounts[term] ?? 0))
        }
        let lhsMagnitude = sqrt(lhsCounts.values.reduce(0.0) { $0 + Double($1 * $1) })
        let rhsMagnitude = sqrt(rhsCounts.values.reduce(0.0) { $0 + Double($1 * $1) })
        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return numerator / (lhsMagnitude * rhsMagnitude)
    }

    func englishTerms(for text: String) -> (tokens: [String], keywordTerms: [String], keywordBigrams: [String]) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var allTerms: [String] = []
        var keywordTerms: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]

        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            let raw = String(text[tokenRange]).lowercased()
            let lemmaTag = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0
            let lemma = (lemmaTag?.rawValue ?? raw).lowercased()
            let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.range(of: "[a-z]", options: .regularExpression) != nil else {
                return true
            }

            allTerms.append(normalized)
            if tag == .noun || tag == .adjective {
                keywordTerms.append(normalized)
            }
            return true
        }

        let contentTerms = filteredContentTerms(from: allTerms)
        let contentKeywordTerms = filteredContentTerms(from: keywordTerms)
        let resolvedKeywordTerms = contentKeywordTerms.isEmpty ? Array(contentTerms.prefix(6)) : contentKeywordTerms
        let keywordBigrams = buildKeywordBigrams(from: resolvedKeywordTerms)

        return (
            tokens: contentTerms,
            keywordTerms: resolvedKeywordTerms,
            keywordBigrams: keywordBigrams
        )
    }

    func filteredContentTerms(from terms: [String]) -> [String] {
        let filtered = terms.filter { term in
            term.count > 1 && !Self.defaultStopwords.contains(term)
        }
        if !filtered.isEmpty {
            return filtered
        }
        return terms.filter { $0.count > 1 }
    }

    func buildKeywordBigrams(from terms: [String]) -> [String] {
        guard terms.count > 1 else { return [] }
        var bigrams: [String] = []
        bigrams.reserveCapacity(max(0, terms.count - 1))
        for index in 0..<(terms.count - 1) {
            bigrams.append("\(terms[index]) \(terms[index + 1])")
        }
        return bigrams
    }

    static func stableHash(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
