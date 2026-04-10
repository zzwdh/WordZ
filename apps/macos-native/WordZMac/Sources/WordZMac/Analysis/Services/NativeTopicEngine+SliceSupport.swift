import CryptoKit
import Foundation
import NaturalLanguage

extension NativeTopicEngine {
    func makeSlices(for text: String, cacheKey: String) throws -> [TopicTextSlice] {
        if let cached = sliceCache[cacheKey] {
            touchSliceCacheKey(cacheKey)
            return cached
        }

        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text
        var slices: [TopicTextSlice] = []
        var paragraphIndex = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            defer { paragraphIndex += 1 }
            guard !paragraph.isEmpty else { return true }

            let tokens = englishTokens(for: paragraph)
            guard tokens.count >= 3 else { return true }
            slices.append(
                TopicTextSlice(
                    id: "paragraph-\(paragraphIndex)",
                    paragraphIndex: paragraphIndex + 1,
                    text: paragraph,
                    tokens: tokens
                )
            )
            return true
        }

        guard !slices.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
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

    func englishTokens(for text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var tokens: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            let raw = String(text[tokenRange]).lowercased()
            let lemma = (tag?.rawValue ?? raw).lowercased()
            let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.range(of: "[a-z]", options: .regularExpression) != nil else {
                return true
            }
            tokens.append(normalized)
            return true
        }
        return tokens
    }

    static func stableHash(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
