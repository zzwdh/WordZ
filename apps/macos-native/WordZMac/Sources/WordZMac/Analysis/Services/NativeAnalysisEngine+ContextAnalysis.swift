import Foundation

extension NativeAnalysisEngine {
    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) throws -> KWICResult {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let document = indexedDocument(for: text, documentKey: documentKey).document
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        var rows: [JSONObject] = []

        for sentence in document.sentences {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                rows.append(
                    kwicRow(
                        tokens: sentence.tokens,
                        match: match,
                        sentenceId: sentence.sentenceId,
                        leftWindow: safeLeft,
                        rightWindow: safeRight
                    )
                )
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
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) throws -> CollocateResult {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let index = indexedDocument(for: text, documentKey: documentKey)
        let document = index.document
        let frequency = index.frequencyMap
        let tokenCount = max(index.tokenCount, 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for sentence in document.sentences {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                keywordFreq += 1

                let leftStart = max(0, match.startIndex - safeLeft)
                if leftStart < match.startIndex {
                    for neighbor in sentence.tokens[leftStart..<match.startIndex] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        leftByWord[neighbor.normalized, default: 0] += 1
                    }
                }

                let rightEnd = min(sentence.tokens.count, match.endIndex + safeRight + 1)
                if match.endIndex + 1 < rightEnd {
                    for neighbor in sentence.tokens[(match.endIndex + 1)..<rightEnd] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        rightByWord[neighbor.normalized, default: 0] += 1
                    }
                }
            }
        }

        let rows = totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                let wordFreq = frequency[word, default: 0]
                let observed = Double(total)
                let expected = (Double(keywordFreq) * Double(wordFreq)) / Double(tokenCount)
                let mutualInformation = expected > 0 && observed > 0
                    ? log2(observed / expected)
                    : 0
                let tScore = observed > 0
                    ? (observed - expected) / sqrt(observed)
                    : 0
                let logDice = (keywordFreq + wordFreq) > 0 && observed > 0
                    ? 14 + log2((2 * observed) / Double(keywordFreq + wordFreq))
                    : 0
                return [
                    "word": word,
                    "total": total,
                    "left": leftByWord[word, default: 0],
                    "right": rightByWord[word, default: 0],
                    "wordFreq": wordFreq,
                    "keywordFreq": keywordFreq,
                    "rate": keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0,
                    "logDice": logDice,
                    "mutualInformation": mutualInformation,
                    "tScore": tScore
                ] as JSONObject
            }

        return CollocateResult(items: rows)
    }

    func runLocator(
        text: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int,
        documentKey: DocumentCacheKey? = nil
    ) -> LocatorResult {
        let document = indexedDocument(for: text, documentKey: documentKey).document
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

    func runKWIC(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition],
        leftWindow: Int,
        rightWindow: Int
    ) -> KWICResult {
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let sentenceMap = Dictionary(uniqueKeysWithValues: artifact.sentences.map { ($0.sentenceId, $0) })
        var rows: [JSONObject] = []

        for position in positions {
            guard let sentence = sentenceMap[position.sentenceId],
                  sentence.tokens.indices.contains(position.tokenIndex) else {
                continue
            }

            let token = sentence.tokens[position.tokenIndex]
            let leftStart = max(0, position.tokenIndex - safeLeft)
            let rightEnd = min(sentence.tokens.count, position.tokenIndex + safeRight + 1)
            let left = sentence.tokens[leftStart..<position.tokenIndex].map(\.original).joined(separator: " ")
            let right = sentence.tokens[(position.tokenIndex + 1)..<rightEnd].map(\.original).joined(separator: " ")
            rows.append([
                "left": left,
                "node": token.original,
                "right": right,
                "sentenceId": sentence.sentenceId,
                "sentenceTokenIndex": position.tokenIndex
            ])
        }

        return KWICResult(json: ["rows": rows])
    }

    func runKWIC(
        artifact: StoredTokenizedArtifact,
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

        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        var rows: [JSONObject] = []

        for sentence in artifact.sentences {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                rows.append(
                    kwicRow(
                        tokens: sentence.tokens,
                        match: match,
                        sentenceId: sentence.sentenceId,
                        leftWindow: safeLeft,
                        rightWindow: safeRight
                    )
                )
            }
        }

        return KWICResult(json: ["rows": rows])
    }

    func runKWIC(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
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

        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        var rows: [JSONObject] = []

        for sentence in artifact.sentences where candidateSentenceIDs.contains(sentence.sentenceId) {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                rows.append(
                    kwicRow(
                        tokens: sentence.tokens,
                        match: match,
                        sentenceId: sentence.sentenceId,
                        leftWindow: safeLeft,
                        rightWindow: safeRight
                    )
                )
            }
        }

        return KWICResult(json: ["rows": rows])
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition],
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int
    ) -> CollocateResult {
        let frequency = artifact.frequencyMap
        let tokenCount = max(artifact.tokenCount, 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        let sentenceMap = Dictionary(uniqueKeysWithValues: artifact.sentences.map { ($0.sentenceId, $0) })
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for position in positions {
            guard let sentence = sentenceMap[position.sentenceId],
                  sentence.tokens.indices.contains(position.tokenIndex) else {
                continue
            }

            keywordFreq += 1
            let leftStart = max(0, position.tokenIndex - safeLeft)
            if leftStart < position.tokenIndex {
                for neighbor in sentence.tokens[leftStart..<position.tokenIndex] {
                    totalByWord[neighbor.normalized, default: 0] += 1
                    leftByWord[neighbor.normalized, default: 0] += 1
                }
            }

            let rightEnd = min(sentence.tokens.count, position.tokenIndex + safeRight + 1)
            if position.tokenIndex + 1 < rightEnd {
                for neighbor in sentence.tokens[(position.tokenIndex + 1)..<rightEnd] {
                    totalByWord[neighbor.normalized, default: 0] += 1
                    rightByWord[neighbor.normalized, default: 0] += 1
                }
            }
        }

        let rows = totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                let wordFreq = frequency[word, default: 0]
                let observed = Double(total)
                let expected = (Double(keywordFreq) * Double(wordFreq)) / Double(tokenCount)
                let mutualInformation = expected > 0 && observed > 0
                    ? log2(observed / expected)
                    : 0
                let tScore = observed > 0
                    ? (observed - expected) / sqrt(observed)
                    : 0
                let logDice = (keywordFreq + wordFreq) > 0 && observed > 0
                    ? 14 + log2((2 * observed) / Double(keywordFreq + wordFreq))
                    : 0
                return [
                    "word": word,
                    "total": total,
                    "left": leftByWord[word, default: 0],
                    "right": rightByWord[word, default: 0],
                    "wordFreq": wordFreq,
                    "keywordFreq": keywordFreq,
                    "rate": keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0,
                    "logDice": logDice,
                    "mutualInformation": mutualInformation,
                    "tScore": tScore
                ] as JSONObject
            }

        return CollocateResult(items: rows)
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
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

        let frequency = artifact.frequencyMap
        let tokenCount = max(artifact.tokenCount, 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for sentence in artifact.sentences {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                keywordFreq += 1

                let leftStart = max(0, match.startIndex - safeLeft)
                if leftStart < match.startIndex {
                    for neighbor in sentence.tokens[leftStart..<match.startIndex] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        leftByWord[neighbor.normalized, default: 0] += 1
                    }
                }

                let rightEnd = min(sentence.tokens.count, match.endIndex + safeRight + 1)
                if match.endIndex + 1 < rightEnd {
                    for neighbor in sentence.tokens[(match.endIndex + 1)..<rightEnd] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        rightByWord[neighbor.normalized, default: 0] += 1
                    }
                }
            }
        }

        let rows = totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                let wordFreq = frequency[word, default: 0]
                let observed = Double(total)
                let expected = (Double(keywordFreq) * Double(wordFreq)) / Double(tokenCount)
                let mutualInformation = expected > 0 && observed > 0
                    ? log2(observed / expected)
                    : 0
                let tScore = observed > 0
                    ? (observed - expected) / sqrt(observed)
                    : 0
                let logDice = (keywordFreq + wordFreq) > 0 && observed > 0
                    ? 14 + log2((2 * observed) / Double(keywordFreq + wordFreq))
                    : 0
                return [
                    "word": word,
                    "total": total,
                    "left": leftByWord[word, default: 0],
                    "right": rightByWord[word, default: 0],
                    "wordFreq": wordFreq,
                    "keywordFreq": keywordFreq,
                    "rate": keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0,
                    "logDice": logDice,
                    "mutualInformation": mutualInformation,
                    "tScore": tScore
                ] as JSONObject
            }

        return CollocateResult(items: rows)
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
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

        let frequency = artifact.frequencyMap
        let tokenCount = max(artifact.tokenCount, 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let safeMinFreq = max(1, minFreq)
        var totalByWord: [String: Int] = [:]
        var leftByWord: [String: Int] = [:]
        var rightByWord: [String: Int] = [:]
        var keywordFreq = 0

        for sentence in artifact.sentences where candidateSentenceIDs.contains(sentence.sentenceId) {
            for match in kwicMatches(in: sentence, matcher: matcher) {
                keywordFreq += 1

                let leftStart = max(0, match.startIndex - safeLeft)
                if leftStart < match.startIndex {
                    for neighbor in sentence.tokens[leftStart..<match.startIndex] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        leftByWord[neighbor.normalized, default: 0] += 1
                    }
                }

                let rightEnd = min(sentence.tokens.count, match.endIndex + safeRight + 1)
                if match.endIndex + 1 < rightEnd {
                    for neighbor in sentence.tokens[(match.endIndex + 1)..<rightEnd] {
                        totalByWord[neighbor.normalized, default: 0] += 1
                        rightByWord[neighbor.normalized, default: 0] += 1
                    }
                }
            }
        }

        let rows = totalByWord
            .filter { $0.value >= safeMinFreq }
            .map { word, total in
                let wordFreq = frequency[word, default: 0]
                let observed = Double(total)
                let expected = (Double(keywordFreq) * Double(wordFreq)) / Double(tokenCount)
                let mutualInformation = expected > 0 && observed > 0
                    ? log2(observed / expected)
                    : 0
                let tScore = observed > 0
                    ? (observed - expected) / sqrt(observed)
                    : 0
                let logDice = (keywordFreq + wordFreq) > 0 && observed > 0
                    ? 14 + log2((2 * observed) / Double(keywordFreq + wordFreq))
                    : 0
                return [
                    "word": word,
                    "total": total,
                    "left": leftByWord[word, default: 0],
                    "right": rightByWord[word, default: 0],
                    "wordFreq": wordFreq,
                    "keywordFreq": keywordFreq,
                    "rate": keywordFreq > 0 ? Double(total) / Double(keywordFreq) : 0,
                    "logDice": logDice,
                    "mutualInformation": mutualInformation,
                    "tScore": tScore
                ] as JSONObject
            }

        return CollocateResult(items: rows)
    }

    func runLocator(
        artifact: StoredTokenizedArtifact,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) -> LocatorResult {
        guard !artifact.sentences.isEmpty else {
            return LocatorResult(json: ["sentences": [], "rows": []])
        }

        let safeSentenceId = min(max(sentenceId, 0), artifact.sentences.count - 1)
        let safeLeft = max(0, leftWindow)
        let safeRight = max(0, rightWindow)
        let start = max(0, safeSentenceId - safeLeft)
        let end = min(artifact.sentences.count - 1, safeSentenceId + safeRight)

        let sourceSentence = artifact.sentences[safeSentenceId]
        let sourceNodeIndex = min(max(nodeIndex, 0), max(sourceSentence.tokens.count - 1, 0))
        let sourceNode = sourceSentence.tokens.isEmpty ? nil : sourceSentence.tokens[sourceNodeIndex]

        let rows: [JSONObject] = Array(artifact.sentences[start...end]).map { sentence in
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
            "sentences": artifact.sentences.map { ["sentenceId": $0.sentenceId, "text": $0.text] },
            "rows": rows
        ])
    }
}

private struct KWICMatch {
    let startIndex: Int
    let endIndex: Int
    let node: String
}

private func kwicMatches(in sentence: ParsedSentence, matcher: SearchTextMatcher) -> [KWICMatch] {
    if matcher.options.matchMode == .phraseExact {
        return matcher.matchingPhraseRanges(in: sentence.tokens, comparableText: \.original).map { range in
            KWICMatch(
                startIndex: range.lowerBound,
                endIndex: range.upperBound - 1,
                node: sentence.tokens[range].map(\.original).joined(separator: " ")
            )
        }
    }

    return sentence.tokens.compactMap { token in
        guard matcher.matches(token.original) else { return nil }
        return KWICMatch(startIndex: token.tokenIndex, endIndex: token.tokenIndex, node: token.original)
    }
}

private func kwicMatches(in sentence: TokenizedSentence, matcher: SearchTextMatcher) -> [KWICMatch] {
    if matcher.options.matchMode == .phraseExact {
        return matcher.matchingPhraseRanges(in: sentence.tokens, comparableText: \.original).map { range in
            KWICMatch(
                startIndex: range.lowerBound,
                endIndex: range.upperBound - 1,
                node: sentence.tokens[range].map(\.original).joined(separator: " ")
            )
        }
    }

    return sentence.tokens.compactMap { token in
        guard matcher.matches(token.original) else { return nil }
        return KWICMatch(startIndex: token.tokenIndex, endIndex: token.tokenIndex, node: token.original)
    }
}

private func kwicRow<Token>(
    tokens: [Token],
    match: KWICMatch,
    sentenceId: Int,
    leftWindow: Int,
    rightWindow: Int
) -> JSONObject where Token: OriginalTokenProviding {
    let leftStart = max(0, match.startIndex - leftWindow)
    let rightEnd = min(tokens.count, match.endIndex + rightWindow + 1)
    let left = tokens[leftStart..<match.startIndex].map(\.originalToken).joined(separator: " ")
    let right = tokens[(match.endIndex + 1)..<rightEnd].map(\.originalToken).joined(separator: " ")
    return [
        "left": left,
        "node": match.node,
        "right": right,
        "sentenceId": sentenceId,
        "sentenceTokenIndex": match.startIndex
    ]
}

private protocol OriginalTokenProviding {
    var originalToken: String { get }
}

extension ParsedToken: OriginalTokenProviding {
    var originalToken: String { original }
}

extension TokenizedToken: OriginalTokenProviding {
    var originalToken: String { original }
}
