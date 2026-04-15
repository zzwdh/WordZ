import Foundation

extension NativeTopicEngine {
    func buildResult(
        slices: [TopicTextSlice],
        embeddings: [[Double]],
        clustered: TopicClusteringResult,
        model: TopicEmbeddingModel,
        diagnostics: TopicAnalysisDiagnostics,
        warnings: [String]
    ) -> TopicAnalysisResult {
        let clusteredSliceIndexSet = Set(clustered.validClusters.flatMap(\.memberIndices))
        let clusteredSlices = clusteredSliceIndexSet.sorted().map { slices[$0] }
        let clusteredSliceDocumentFrequency = buildSliceDocumentFrequency(slices: clusteredSlices)

        var summaries: [TopicClusterSummary] = []
        var segments: [TopicSegmentRow] = []

        for (clusterIndex, cluster) in clustered.validClusters.enumerated() {
            let clusterID = "topic-\(clusterIndex + 1)"
            let clusterIndexSet = Set(cluster.memberIndices)
            let clusterSlices = cluster.memberIndices.map { slices[$0] }
            let restSlices = slices.enumerated().compactMap { index, slice in
                clusterIndexSet.contains(index) ? nil : slice
            }
            let candidates = buildKeywordCandidates(
                slices: clusterSlices,
                restSlices: restSlices,
                clusteredSliceDocumentFrequency: clusteredSliceDocumentFrequency,
                clusteredSliceCount: clusteredSlices.count
            )
            let representativeIDs = representativeSegmentIDs(
                cluster: cluster,
                slices: slices,
                embeddings: embeddings,
                similarityMatrix: clustered.similarityMatrix
            )
            summaries.append(
                TopicClusterSummary(
                    id: clusterID,
                    index: clusterIndex + 1,
                    isOutlier: false,
                    size: cluster.memberIndices.count,
                    keywordCandidates: candidates,
                    representativeSegmentIDs: representativeIDs
                )
            )
            for memberIndex in cluster.memberIndices {
                segments.append(
                    TopicSegmentRow(
                        id: slices[memberIndex].id,
                        topicID: clusterID,
                        paragraphIndex: slices[memberIndex].paragraphIndex,
                        text: slices[memberIndex].text,
                        similarityScore: cosineSimilarity(embeddings[memberIndex], cluster.centroid),
                        isOutlier: false
                    )
                )
            }
        }

        if !clustered.outlierIndices.isEmpty {
            let outlierIndexSet = Set(clustered.outlierIndices)
            let outlierSlices = clustered.outlierIndices.map { slices[$0] }
            let restSlices = slices.enumerated().compactMap { index, slice in
                outlierIndexSet.contains(index) ? nil : slice
            }
            let candidates = buildKeywordCandidates(
                slices: outlierSlices,
                restSlices: restSlices,
                clusteredSliceDocumentFrequency: clusteredSliceDocumentFrequency,
                clusteredSliceCount: clusteredSlices.count
            )
            let representativeIDs = clustered.outlierIndices
                .sorted { slices[$0].paragraphIndex < slices[$1].paragraphIndex }
                .prefix(3)
                .map { slices[$0].id }
            summaries.append(
                TopicClusterSummary(
                    id: TopicAnalysisResult.outlierTopicID,
                    index: 0,
                    isOutlier: true,
                    size: clustered.outlierIndices.count,
                    keywordCandidates: candidates,
                    representativeSegmentIDs: representativeIDs
                )
            )
            for memberIndex in clustered.outlierIndices {
                segments.append(
                    TopicSegmentRow(
                        id: slices[memberIndex].id,
                        topicID: TopicAnalysisResult.outlierTopicID,
                        paragraphIndex: slices[memberIndex].paragraphIndex,
                        text: slices[memberIndex].text,
                        similarityScore: 0,
                        isOutlier: true
                    )
                )
            }
        }

        let clusterOrder = Dictionary(uniqueKeysWithValues: summaries.enumerated().map { ($1.id, $0) })
        let sortedSegments = segments.sorted { lhs, rhs in
            let lhsOrder = clusterOrder[lhs.topicID] ?? .max
            let rhsOrder = clusterOrder[rhs.topicID] ?? .max
            if lhsOrder == rhsOrder {
                return lhs.paragraphIndex < rhs.paragraphIndex
            }
            return lhsOrder < rhsOrder
        }

        let dedupedWarnings = deduplicatedWarnings(warnings)
        let modelVersionSuffix = model.providerRevision.split(separator: "::").last.map(String.init) ?? ""
        let modelVersion = modelVersionSuffix.isEmpty
            ? "\(model.manifest.modelID)-\(model.manifest.version)"
            : "\(model.manifest.modelID)-\(model.manifest.version)-\(modelVersionSuffix)"

        return TopicAnalysisResult(
            modelVersion: modelVersion,
            modelProvider: model.providerLabel,
            usesFallbackProvider: model.providerLabel == "hashed-fallback",
            diagnostics: diagnostics,
            clusters: summaries,
            segments: sortedSegments,
            totalSegments: slices.count,
            clusteredSegments: clustered.validClusters.reduce(0) { $0 + $1.memberIndices.count },
            outlierCount: clustered.outlierIndices.count,
            warnings: dedupedWarnings
        )
    }

    func buildSliceDocumentFrequency(slices: [TopicTextSlice]) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for slice in slices {
            let uniqueTerms = Set(candidateTerms(for: slice).map(canonicalKeyword))
            for term in uniqueTerms {
                frequency[term, default: 0] += 1
            }
        }
        return frequency
    }

    func buildKeywordCandidates(
        slices: [TopicTextSlice],
        restSlices: [TopicTextSlice],
        clusteredSliceDocumentFrequency: [String: Int],
        clusteredSliceCount: Int
    ) -> [TopicKeywordCandidate] {
        let targetWeights = aggregateWeightedCandidateTerms(from: slices)
        let restWeights = aggregateWeightedCandidateTerms(from: restSlices)
        let targetPresence = buildSliceDocumentFrequency(slices: slices)
        let restPresence = buildSliceDocumentFrequency(slices: restSlices)
        let targetTotalWeight = targetWeights.values.reduce(0, +)
        let restTotalWeight = restWeights.values.reduce(0, +)

        guard targetTotalWeight > 0 else { return [] }

        let scored = targetWeights.compactMap { term, count -> TopicKeywordCandidate? in
            let tf = count / targetTotalWeight
            let restTF = restTotalWeight > 0
                ? (restWeights[term] ?? 0) / restTotalWeight
                : 0
            let targetShare = Double(targetPresence[term] ?? 0) / Double(max(1, slices.count))
            let restShare = restSlices.isEmpty
                ? 0
                : Double(restPresence[term] ?? 0) / Double(max(1, restSlices.count))
            let contrast = max(0.01, (targetShare - restShare) + 0.08)
            let tfLift = max(0.01, tf - (restTF * 0.6) + 0.02)
            let globalShare = clusteredSliceCount == 0
                ? 0
                : Double(clusteredSliceDocumentFrequency[term] ?? 0) / Double(clusteredSliceCount)
            let genericPenalty = globalShare > 0.4
                ? max(0.12, 1 - ((globalShare - 0.4) / 0.6))
                : 1
            let df = Double(max(1, clusteredSliceDocumentFrequency[term] ?? 1))
            let idf = log(1 + (Double(max(1, clusteredSliceCount)) / df))
            let score = ((tfLift * 0.58) + (contrast * 0.42)) * (1 + idf) * genericPenalty
            guard score > 0 else { return nil }
            return TopicKeywordCandidate(term: term, score: score)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        return Array(deduplicatedKeywordCandidates(scored).prefix(12))
    }

    func candidateTerms(for slice: TopicTextSlice) -> [String] {
        let terms = slice.keywordTerms
        if !terms.isEmpty {
            return terms.map(canonicalKeyword)
        }
        return slice.tokens.map(canonicalKeyword)
    }

    func aggregateWeightedCandidateTerms(from slices: [TopicTextSlice]) -> [String: Double] {
        var counts: [String: Double] = [:]
        for slice in slices {
            for (term, weight) in weightedCandidateTerms(for: slice) {
                counts[term, default: 0] += weight
            }
        }
        return counts
    }

    func weightedCandidateTerms(for slice: TopicTextSlice) -> [(String, Double)] {
        let unigramCounts = Dictionary(
            grouping: slice.keywordTerms.isEmpty ? slice.tokens : slice.keywordTerms,
            by: canonicalKeyword
        )
        .mapValues(\.count)

        var weightedTerms: [(String, Double)] = []
        weightedTerms.reserveCapacity(unigramCounts.count)
        for (term, count) in unigramCounts {
            weightedTerms.append((term, log1p(Double(count))))
        }
        return weightedTerms
    }

    func deduplicatedKeywordCandidates(_ candidates: [TopicKeywordCandidate]) -> [TopicKeywordCandidate] {
        var seen = Set<String>()
        var deduplicated: [TopicKeywordCandidate] = []
        for candidate in candidates {
            let canonical = canonicalKeyword(candidate.term)
            guard !seen.contains(canonical) else { continue }
            seen.insert(canonical)
            deduplicated.append(candidate)
        }
        return deduplicated
    }

    func canonicalKeyword(_ term: String) -> String {
        term
            .split(separator: " ")
            .map { token in
                let lowered = token.lowercased()
                if lowered.hasSuffix("ies"), lowered.count > 3 {
                    return String(lowered.dropLast(3)) + "y"
                }
                if lowered.hasSuffix("s"), !lowered.hasSuffix("ss"), lowered.count > 3 {
                    return String(lowered.dropLast())
                }
                return lowered
            }
            .joined(separator: " ")
    }

    func representativeSegmentIDs(
        cluster: ClusterState,
        slices: [TopicTextSlice],
        embeddings: [[Double]],
        similarityMatrix: [[Double]]
    ) -> [String] {
        guard !cluster.memberIndices.isEmpty else { return [] }
        if cluster.memberIndices.count == 1 {
            return cluster.memberIndices.map { slices[$0].id }
        }

        let medoid = cluster.memberIndices.max { lhs, rhs in
            let lhsScore = averageSimilarityToCluster(
                memberIndex: lhs,
                clusterMembers: cluster.memberIndices,
                embeddings: embeddings,
                similarityMatrix: similarityMatrix
            )
            let rhsScore = averageSimilarityToCluster(
                memberIndex: rhs,
                clusterMembers: cluster.memberIndices,
                embeddings: embeddings,
                similarityMatrix: similarityMatrix
            )
            if lhsScore == rhsScore {
                return slices[lhs].paragraphIndex > slices[rhs].paragraphIndex
            }
            return lhsScore < rhsScore
        } ?? cluster.memberIndices[0]

        var selected = [medoid]
        let relevanceByMember = Dictionary(uniqueKeysWithValues: cluster.memberIndices.map {
            ($0, cosineSimilarity(embeddings[$0], cluster.centroid))
        })

        while selected.count < min(3, cluster.memberIndices.count) {
            let candidate = cluster.memberIndices
                .filter { !selected.contains($0) }
                .max { lhs, rhs in
                    let lhsScore = mmrScore(
                        memberIndex: lhs,
                        selected: selected,
                        relevanceByMember: relevanceByMember,
                        embeddings: embeddings,
                        similarityMatrix: similarityMatrix
                    )
                    let rhsScore = mmrScore(
                        memberIndex: rhs,
                        selected: selected,
                        relevanceByMember: relevanceByMember,
                        embeddings: embeddings,
                        similarityMatrix: similarityMatrix
                    )
                    if lhsScore == rhsScore {
                        return slices[lhs].paragraphIndex > slices[rhs].paragraphIndex
                    }
                    return lhsScore < rhsScore
                }

            guard let candidate else { break }
            selected.append(candidate)
        }

        return selected.map { slices[$0].id }
    }

    func averageSimilarityToCluster(
        memberIndex: Int,
        clusterMembers: [Int],
        embeddings: [[Double]],
        similarityMatrix: [[Double]]
    ) -> Double {
        let peers = clusterMembers.filter { $0 != memberIndex }
        guard !peers.isEmpty else { return 1 }
        let total = peers.reduce(0.0) { partialResult, peer in
            partialResult + pairwiseMemberSimilarity(
                lhs: memberIndex,
                rhs: peer,
                embeddings: embeddings,
                similarityMatrix: similarityMatrix
            )
        }
        return total / Double(peers.count)
    }

    func mmrScore(
        memberIndex: Int,
        selected: [Int],
        relevanceByMember: [Int: Double],
        embeddings: [[Double]],
        similarityMatrix: [[Double]],
        lambda: Double = 0.72
    ) -> Double {
        let relevance = relevanceByMember[memberIndex] ?? 0
        let redundancy = selected.map { selectedIndex in
            pairwiseMemberSimilarity(
                lhs: memberIndex,
                rhs: selectedIndex,
                embeddings: embeddings,
                similarityMatrix: similarityMatrix
            )
        }.max() ?? 0
        return (lambda * relevance) - ((1 - lambda) * redundancy)
    }

    func pairwiseMemberSimilarity(
        lhs: Int,
        rhs: Int,
        embeddings: [[Double]],
        similarityMatrix: [[Double]]
    ) -> Double {
        if lhs < similarityMatrix.count, rhs < similarityMatrix.count, rhs < similarityMatrix[lhs].count {
            return similarityMatrix[lhs][rhs]
        }
        guard lhs < embeddings.count, rhs < embeddings.count else { return 0 }
        return cosineSimilarity(embeddings[lhs], embeddings[rhs])
    }

    func deduplicatedWarnings(_ warnings: [String]) -> [String] {
        var seen = Set<String>()
        return warnings.filter { warning in
            guard !seen.contains(warning) else { return false }
            seen.insert(warning)
            return true
        }
    }
}
