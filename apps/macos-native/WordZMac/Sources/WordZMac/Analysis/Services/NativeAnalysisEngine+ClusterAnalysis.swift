import Foundation

extension NativeAnalysisEngine {
    func runCluster(_ request: ClusterRunRequest) -> ClusterResult {
        let safeNValues = Array(Set(request.nValues.map { min(max($0, 2), 5) })).sorted()
        let targetStats = clusterStatistics(
            for: request.targetEntries,
            caseSensitive: request.caseSensitive,
            stopwordFilter: request.stopwordFilter,
            punctuationMode: request.punctuationMode,
            nValues: safeNValues
        )
        let referenceStats = clusterStatistics(
            for: request.referenceEntries,
            caseSensitive: request.caseSensitive,
            stopwordFilter: request.stopwordFilter,
            punctuationMode: request.punctuationMode,
            nValues: safeNValues
        )

        let keys = Set(targetStats.aggregates.keys).union(referenceStats.aggregates.keys)
        let rows = keys.map { key -> ClusterRow in
            let targetAggregate = targetStats.aggregates[key]
            let referenceAggregate = referenceStats.aggregates[key]
            let phrase = clusterDisplayPhrase(
                target: targetAggregate?.surfaceCounts ?? [:],
                reference: referenceAggregate?.surfaceCounts ?? [:],
                fallback: key
            )
            let targetFrequency = targetAggregate?.frequency ?? 0
            let targetRange = targetAggregate?.documentIDs.count ?? 0
            let referenceFrequency = referenceAggregate?.frequency ?? 0
            let referenceRange = referenceAggregate?.documentIDs.count ?? 0
            return ClusterRow(
                phrase: phrase,
                n: targetAggregate?.n ?? referenceAggregate?.n ?? 2,
                frequency: targetFrequency,
                normalizedFrequency: normalizedFrequency(count: targetFrequency, tokenCount: targetStats.tokenCount),
                range: targetRange,
                rangePercentage: normalizedRange(count: targetRange, documentCount: targetStats.documentCount),
                referenceFrequency: request.referenceEntries.isEmpty ? nil : referenceFrequency,
                referenceNormalizedFrequency: request.referenceEntries.isEmpty ? nil : normalizedFrequency(count: referenceFrequency, tokenCount: referenceStats.tokenCount),
                referenceRange: request.referenceEntries.isEmpty ? nil : referenceRange,
                logRatio: request.referenceEntries.isEmpty
                    ? nil
                    : Self.logRatio(
                        targetCount: targetFrequency,
                        targetTokenCount: max(targetStats.tokenCount, 1),
                        referenceCount: referenceFrequency,
                        referenceTokenCount: max(referenceStats.tokenCount, 1)
                    )
            )
        }
        .sorted {
            if $0.frequency == $1.frequency {
                return $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending
            }
            return $0.frequency > $1.frequency
        }

        return ClusterResult(
            mode: request.mode,
            targetDocumentCount: targetStats.documentCount,
            referenceDocumentCount: referenceStats.documentCount,
            targetTokenCount: targetStats.tokenCount,
            referenceTokenCount: referenceStats.tokenCount,
            rows: rows
        )
    }

    private func clusterStatistics(
        for entries: [ClusterCorpusEntry],
        caseSensitive: Bool,
        stopwordFilter: StopwordFilterState,
        punctuationMode: ClusterPunctuationMode,
        nValues: [Int]
    ) -> ClusterScanSummary {
        guard !entries.isEmpty else {
            return ClusterScanSummary(documentCount: 0, tokenCount: 0, aggregates: [:])
        }

        let stopwordSet = Set(stopwordFilter.parsedWords)
        var tokenCount = 0
        var aggregates: [String: ClusterAggregate] = [:]

        for entry in entries {
            let document = indexedDocument(for: entry.content, documentKey: DocumentCacheKey(text: entry.content)).document
            var seenKeys = Set<String>()

            for sentence in document.sentences {
                let segments = clusterSegments(in: sentence.text, punctuationMode: punctuationMode, caseSensitive: caseSensitive)
                for segment in segments {
                    tokenCount += segment.count
                    guard !segment.isEmpty else { continue }

                    for n in nValues where segment.count >= n {
                        for start in 0...(segment.count - n) {
                            let slice = Array(segment[start..<(start + n)])
                            let normalizedTokens = slice.map(\.normalized)
                            guard clusterCandidatePassesStopwords(
                                normalizedTokens: normalizedTokens,
                                stopwordFilter: stopwordFilter,
                                stopwordSet: stopwordSet
                            ) else {
                                continue
                            }
                            let surface = slice.map(\.surface).joined(separator: " ")
                            let key = caseSensitive
                                ? surface.precomposedStringWithCompatibilityMapping
                                : normalizedTokens.joined(separator: " ")
                            var aggregate = aggregates[key] ?? ClusterAggregate(n: n)
                            aggregate.frequency += 1
                            aggregate.surfaceCounts[surface, default: 0] += 1
                            if seenKeys.insert(key).inserted {
                                aggregate.documentIDs.insert(entry.corpusId)
                            }
                            aggregates[key] = aggregate
                        }
                    }
                }
            }
        }

        return ClusterScanSummary(
            documentCount: entries.count,
            tokenCount: tokenCount,
            aggregates: aggregates
        )
    }

    private func clusterSegments(
        in text: String,
        punctuationMode: ClusterPunctuationMode,
        caseSensitive: Bool
    ) -> [[ClusterSurfaceToken]] {
        var segments: [[ClusterSurfaceToken]] = []
        var currentSegment: [ClusterSurfaceToken] = []
        var buffer = ""
        let scalars = Array(text.unicodeScalars)

        func flushToken() {
            let trimmed = buffer.trimmingCharacters(in: CharacterSet(charactersIn: "'’"))
            defer { buffer.removeAll(keepingCapacity: true) }
            guard !trimmed.isEmpty else { return }
            let normalized = AnalysisTextNormalizationSupport.normalizeSearchText(trimmed, caseSensitive: caseSensitive)
            guard !normalized.isEmpty else { return }
            currentSegment.append(
                ClusterSurfaceToken(
                    surface: trimmed,
                    normalized: AnalysisTextNormalizationSupport.normalizeToken(trimmed)
                )
            )
        }

        func flushSegment() {
            flushToken()
            guard !currentSegment.isEmpty else { return }
            segments.append(currentSegment)
            currentSegment.removeAll(keepingCapacity: true)
        }

        for (index, scalar) in scalars.enumerated() {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if (scalar == "'" || scalar == "’"),
               !buffer.isEmpty,
               scalars.indices.contains(index + 1),
               CharacterSet.alphanumerics.contains(scalars[index + 1]) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                flushToken()
                continue
            }

            flushToken()
            if punctuationMode == .boundary {
                flushSegment()
            }
        }

        flushSegment()
        return segments
    }

    private func clusterCandidatePassesStopwords(
        normalizedTokens: [String],
        stopwordFilter: StopwordFilterState,
        stopwordSet: Set<String>
    ) -> Bool {
        guard stopwordFilter.enabled, !stopwordSet.isEmpty else { return true }
        switch stopwordFilter.mode {
        case .exclude:
            return !normalizedTokens.contains(where: stopwordSet.contains)
        case .include:
            return normalizedTokens.allSatisfy(stopwordSet.contains)
        }
    }

    private func clusterDisplayPhrase(
        target: [String: Int],
        reference: [String: Int],
        fallback: String
    ) -> String {
        let combined = target.merging(reference, uniquingKeysWith: +)
        guard let winner = combined.max(by: {
            if $0.value == $1.value {
                return $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedDescending
            }
            return $0.value < $1.value
        })?.key else {
            return fallback
        }
        return winner
    }

    private func normalizedFrequency(count: Int, tokenCount: Int) -> Double {
        guard tokenCount > 0 else { return 0 }
        return (Double(count) / Double(tokenCount)) * 10_000
    }

    private func normalizedRange(count: Int, documentCount: Int) -> Double {
        guard documentCount > 0 else { return 0 }
        return (Double(count) / Double(documentCount)) * 100
    }
}

private struct ClusterScanSummary {
    let documentCount: Int
    let tokenCount: Int
    let aggregates: [String: ClusterAggregate]
}

private struct ClusterAggregate {
    let n: Int
    var frequency = 0
    var surfaceCounts: [String: Int] = [:]
    var documentIDs: Set<String> = []
}

private struct ClusterSurfaceToken {
    let surface: String
    let normalized: String
}
