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
        let sentences = document.sentences.map(CollocateAssociationCalculator.Sentence.init)
        let ranges = document.sentences.flatMap { sentence in
            kwicMatches(in: sentence, matcher: matcher).map {
                CollocateAssociationCalculator.NodeRange(
                    sentenceId: sentence.sentenceId,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex
                )
            }
        }

        return collocateResult(
            sentences: sentences,
            nodeRanges: ranges,
            frequencyMap: index.frequencyMap,
            tokenCount: index.tokenCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq
        )
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
        let sentenceMap = Dictionary(uniqueKeysWithValues: artifact.sentences.map { ($0.sentenceId, $0) })
        let ranges = positions.compactMap { position -> CollocateAssociationCalculator.NodeRange? in
            guard let sentence = sentenceMap[position.sentenceId],
                  sentence.tokens.indices.contains(position.tokenIndex) else {
                return nil
            }
            return CollocateAssociationCalculator.NodeRange(
                sentenceId: position.sentenceId,
                startIndex: position.tokenIndex,
                endIndex: position.tokenIndex
            )
        }

        return collocateResult(
            sentences: artifact.sentences.map(CollocateAssociationCalculator.Sentence.init),
            nodeRanges: ranges,
            frequencyMap: artifact.frequencyMap,
            tokenCount: artifact.tokenCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq
        )
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

        let ranges = artifact.sentences.flatMap { sentence in
            kwicMatches(in: sentence, matcher: matcher).map {
                CollocateAssociationCalculator.NodeRange(
                    sentenceId: sentence.sentenceId,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex
                )
            }
        }

        return collocateResult(
            sentences: artifact.sentences.map(CollocateAssociationCalculator.Sentence.init),
            nodeRanges: ranges,
            frequencyMap: artifact.frequencyMap,
            tokenCount: artifact.tokenCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq
        )
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

        let candidateSentences = artifact.sentences.filter { candidateSentenceIDs.contains($0.sentenceId) }
        let ranges = candidateSentences.flatMap { sentence in
            kwicMatches(in: sentence, matcher: matcher).map {
                CollocateAssociationCalculator.NodeRange(
                    sentenceId: sentence.sentenceId,
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex
                )
            }
        }

        return collocateResult(
            sentences: candidateSentences.map(CollocateAssociationCalculator.Sentence.init),
            nodeRanges: ranges,
            frequencyMap: artifact.frequencyMap,
            tokenCount: artifact.tokenCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq
        )
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

private func collocateResult(
    sentences: [CollocateAssociationCalculator.Sentence],
    nodeRanges: [CollocateAssociationCalculator.NodeRange],
    frequencyMap: [String: Int],
    tokenCount: Int,
    leftWindow: Int,
    rightWindow: Int,
    minFreq: Int
) -> CollocateResult {
    CollocateResult(
        rows: CollocateAssociationCalculator.calculate(
            sentences: sentences,
            nodeRanges: nodeRanges,
            frequencyMap: frequencyMap,
            tokenCount: tokenCount,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq
        )
    )
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
