import Foundation

struct PlotDocumentDistribution: Equatable, Sendable {
    let tokenCount: Int
    let hitMarkers: [PlotHitMarker]
}

extension NativeAnalysisEngine {
    func runPlot(
        text: String,
        keyword: String,
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) throws -> PlotDocumentDistribution {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let document = indexedDocument(for: text, documentKey: documentKey).document
        let tokenCount = document.sentences.reduce(0) { $0 + $1.tokens.count }
        let sentenceOffsets = absoluteSentenceOffsets(from: document.sentences.map { sentence in
            PlotSentenceOffset(sentenceId: sentence.sentenceId, tokenCount: sentence.tokens.count)
        })

        var hitMarkers: [PlotHitMarker] = []
        for sentence in document.sentences {
            let sentenceOffset = sentenceOffsets[sentence.sentenceId, default: 0]
            for match in plotMatches(in: sentence, matcher: matcher) {
                hitMarkers.append(
                    PlotHitMarker(
                        id: "\(sentence.sentenceId)-\(match.startIndex)",
                        sentenceId: sentence.sentenceId,
                        tokenIndex: match.startIndex,
                        normalizedPosition: normalizedPosition(
                            absoluteTokenIndex: sentenceOffset + match.startIndex,
                            tokenCount: tokenCount
                        )
                    )
                )
            }
        }

        return PlotDocumentDistribution(tokenCount: tokenCount, hitMarkers: hitMarkers)
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition]
    ) -> PlotDocumentDistribution {
        let tokenCount = artifact.tokenCount
        let sentenceOffsets = absoluteSentenceOffsets(from: artifact.sentences.map { sentence in
            PlotSentenceOffset(sentenceId: sentence.sentenceId, tokenCount: sentence.tokens.count)
        })
        let sentenceMap = Dictionary(uniqueKeysWithValues: artifact.sentences.map { ($0.sentenceId, $0) })

        let hitMarkers: [PlotHitMarker] = positions.compactMap { (position: StoredTokenPosition) -> PlotHitMarker? in
            guard let sentence = sentenceMap[position.sentenceId],
                  sentence.tokens.indices.contains(position.tokenIndex) else {
                return nil
            }
            let absoluteTokenIndex = sentenceOffsets[position.sentenceId, default: 0] + position.tokenIndex
            return PlotHitMarker(
                id: "\(position.sentenceId)-\(position.tokenIndex)",
                sentenceId: position.sentenceId,
                tokenIndex: position.tokenIndex,
                normalizedPosition: normalizedPosition(
                    absoluteTokenIndex: absoluteTokenIndex,
                    tokenCount: tokenCount
                )
            )
        }

        return PlotDocumentDistribution(tokenCount: tokenCount, hitMarkers: hitMarkers)
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        keyword: String,
        searchOptions: SearchOptionsState
    ) throws -> PlotDocumentDistribution {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let tokenCount = artifact.tokenCount
        let sentenceOffsets = absoluteSentenceOffsets(from: artifact.sentences.map { sentence in
            PlotSentenceOffset(sentenceId: sentence.sentenceId, tokenCount: sentence.tokens.count)
        })

        var hitMarkers: [PlotHitMarker] = []
        for sentence in artifact.sentences {
            let sentenceOffset = sentenceOffsets[sentence.sentenceId, default: 0]
            for match in plotMatches(in: sentence, matcher: matcher) {
                hitMarkers.append(
                    PlotHitMarker(
                        id: "\(sentence.sentenceId)-\(match.startIndex)",
                        sentenceId: sentence.sentenceId,
                        tokenIndex: match.startIndex,
                        normalizedPosition: normalizedPosition(
                            absoluteTokenIndex: sentenceOffset + match.startIndex,
                            tokenCount: tokenCount
                        )
                    )
                )
            }
        }

        return PlotDocumentDistribution(tokenCount: tokenCount, hitMarkers: hitMarkers)
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
        keyword: String,
        searchOptions: SearchOptionsState
    ) throws -> PlotDocumentDistribution {
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeAnalysisEngine",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let tokenCount = artifact.tokenCount
        let sentenceOffsets = absoluteSentenceOffsets(from: artifact.sentences.map { sentence in
            PlotSentenceOffset(sentenceId: sentence.sentenceId, tokenCount: sentence.tokens.count)
        })

        var hitMarkers: [PlotHitMarker] = []
        for sentence in artifact.sentences where candidateSentenceIDs.contains(sentence.sentenceId) {
            let sentenceOffset = sentenceOffsets[sentence.sentenceId, default: 0]
            for match in plotMatches(in: sentence, matcher: matcher) {
                hitMarkers.append(
                    PlotHitMarker(
                        id: "\(sentence.sentenceId)-\(match.startIndex)",
                        sentenceId: sentence.sentenceId,
                        tokenIndex: match.startIndex,
                        normalizedPosition: normalizedPosition(
                            absoluteTokenIndex: sentenceOffset + match.startIndex,
                            tokenCount: tokenCount
                        )
                    )
                )
            }
        }

        return PlotDocumentDistribution(tokenCount: tokenCount, hitMarkers: hitMarkers)
    }
}

private struct PlotMatch {
    let startIndex: Int
}

private struct PlotSentenceOffset {
    let sentenceId: Int
    let tokenCount: Int
}

private func plotMatches(in sentence: ParsedSentence, matcher: SearchTextMatcher) -> [PlotMatch] {
    if matcher.options.matchMode == .phraseExact {
        return matcher.matchingPhraseRanges(in: sentence.tokens, comparableText: \.original).map { range in
            PlotMatch(startIndex: range.lowerBound)
        }
    }

    return sentence.tokens.compactMap { token in
        guard matcher.matches(token.original) else { return nil }
        return PlotMatch(startIndex: token.tokenIndex)
    }
}

private func plotMatches(in sentence: TokenizedSentence, matcher: SearchTextMatcher) -> [PlotMatch] {
    if matcher.options.matchMode == .phraseExact {
        return matcher.matchingPhraseRanges(in: sentence.tokens, comparableText: \.original).map { range in
            PlotMatch(startIndex: range.lowerBound)
        }
    }

    return sentence.tokens.compactMap { token in
        guard matcher.matches(token.original) else { return nil }
        return PlotMatch(startIndex: token.tokenIndex)
    }
}

private func absoluteSentenceOffsets(from sentences: [PlotSentenceOffset]) -> [Int: Int] {
    var offsets: [Int: Int] = [:]
    var runningCount = 0
    for sentence in sentences.sorted(by: { $0.sentenceId < $1.sentenceId }) {
        offsets[sentence.sentenceId] = runningCount
        runningCount += sentence.tokenCount
    }
    return offsets
}

private func normalizedPosition(
    absoluteTokenIndex: Int,
    tokenCount: Int
) -> Double {
    guard tokenCount > 0 else { return 0 }
    if tokenCount == 1 {
        return 0.5
    }
    let boundedIndex = min(max(absoluteTokenIndex, 0), tokenCount - 1)
    return min(max(Double(boundedIndex) / Double(tokenCount - 1), 0), 1)
}
