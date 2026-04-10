import Foundation

extension NativeTopicEngine {
    func buildResult(
        slices: [TopicTextSlice],
        embeddings: [[Double]],
        clustered: (validClusters: [ClusterState], outlierIndices: [Int]),
        model: TopicEmbeddingModel
    ) -> TopicAnalysisResult {
        let clusterDocumentFrequency = buildDocumentFrequency(
            slices: slices,
            clusters: clustered.validClusters,
            outlierIndices: clustered.outlierIndices
        )

        var summaries: [TopicClusterSummary] = []
        var segments: [TopicSegmentRow] = []

        for (clusterIndex, cluster) in clustered.validClusters.enumerated() {
            let clusterID = "topic-\(clusterIndex + 1)"
            let clusterSlices = cluster.memberIndices.map { slices[$0] }
            let candidates = buildKeywordCandidates(
                slices: clusterSlices,
                clusterDocumentFrequency: clusterDocumentFrequency,
                clusterCount: max(1, clustered.validClusters.count + (clustered.outlierIndices.isEmpty ? 0 : 1))
            )
            let representativeIDs = representativeSegmentIDs(
                cluster: cluster,
                slices: slices,
                embeddings: embeddings
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
            let outlierSlices = clustered.outlierIndices.map { slices[$0] }
            let candidates = buildKeywordCandidates(
                slices: outlierSlices,
                clusterDocumentFrequency: clusterDocumentFrequency,
                clusterCount: max(1, clustered.validClusters.count + 1)
            )
            let representativeIDs = clustered.outlierIndices.prefix(3).map { slices[$0].id }
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

        let sortedSegments = segments.sorted { lhs, rhs in
            if lhs.topicID == rhs.topicID {
                return lhs.paragraphIndex < rhs.paragraphIndex
            }
            return lhs.topicID < rhs.topicID
        }

        return TopicAnalysisResult(
            modelVersion: "\(model.manifest.modelID)-\(model.manifest.version)",
            modelProvider: model.providerLabel,
            usesFallbackProvider: model.providerLabel == "hashed-fallback",
            clusters: summaries,
            segments: sortedSegments,
            totalSegments: slices.count,
            clusteredSegments: clustered.validClusters.reduce(0) { $0 + $1.memberIndices.count },
            outlierCount: clustered.outlierIndices.count,
            warnings: []
        )
    }

    func buildDocumentFrequency(
        slices: [TopicTextSlice],
        clusters: [ClusterState],
        outlierIndices: [Int]
    ) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for cluster in clusters {
            let uniqueTerms = Set(cluster.memberIndices.flatMap { slices[$0].tokens })
            for term in uniqueTerms {
                frequency[term, default: 0] += 1
            }
        }
        if !outlierIndices.isEmpty {
            let uniqueTerms = Set(outlierIndices.flatMap { slices[$0].tokens })
            for term in uniqueTerms {
                frequency[term, default: 0] += 1
            }
        }
        return frequency
    }

    func buildKeywordCandidates(
        slices: [TopicTextSlice],
        clusterDocumentFrequency: [String: Int],
        clusterCount: Int
    ) -> [TopicKeywordCandidate] {
        var counts: [String: Int] = [:]
        var total = 0
        for slice in slices {
            for token in slice.tokens {
                counts[token, default: 0] += 1
                total += 1
            }
        }

        guard total > 0 else { return [] }

        return counts.map { term, count in
            let tf = Double(count) / Double(total)
            let df = Double(max(1, clusterDocumentFrequency[term] ?? 1))
            let idf = log(1 + (Double(clusterCount) / df))
            return TopicKeywordCandidate(term: term, score: tf * idf)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
        .prefix(12)
        .map { $0 }
    }

    func representativeSegmentIDs(
        cluster: ClusterState,
        slices: [TopicTextSlice],
        embeddings: [[Double]]
    ) -> [String] {
        cluster.memberIndices
            .sorted { lhs, rhs in
                let lhsScore = cosineSimilarity(embeddings[lhs], cluster.centroid)
                let rhsScore = cosineSimilarity(embeddings[rhs], cluster.centroid)
                if lhsScore == rhsScore {
                    return slices[lhs].paragraphIndex < slices[rhs].paragraphIndex
                }
                return lhsScore > rhsScore
            }
            .prefix(3)
            .map { slices[$0].id }
    }
}
