import Foundation

extension NativeTopicEngine {
    func candidateApproximateClusterCounts(
        for vectorCount: Int,
        minTopicSize: Int
    ) -> [Int] {
        guard vectorCount > 1 else { return [1] }

        let minClusterSize = max(2, minTopicSize)
        let maxFeasibleClusters = max(1, vectorCount / minClusterSize)
        let sqrtBudget = max(2, Int(sqrt(Double(vectorCount)).rounded(.up)))
        let upperBound = min(
            runtimeTuning.topicApproximateClusteringClusterLimit,
            maxFeasibleClusters,
            sqrtBudget
        )
        return Array(1...max(1, upperBound))
    }

    func coarseApproximateClusterCounts(from candidateCounts: [Int]) -> [Int] {
        guard !candidateCounts.isEmpty else { return [] }

        let candidateSet = Set(candidateCounts)
        let configuredCounts = runtimeTuning.topicApproximateClusteringCoarseCandidateCounts
            .filter { candidateSet.contains($0) }
        if !configuredCounts.isEmpty {
            return Array(Set(configuredCounts + [candidateCounts.first!, candidateCounts.last!])).sorted()
        }

        let targetCount = min(6, candidateCounts.count)
        guard targetCount < candidateCounts.count else { return candidateCounts }

        let stride = max(1, Int(ceil(Double(candidateCounts.count) / Double(targetCount))))
        var selected = candidateCounts.enumerated()
            .compactMap { index, value in index % stride == 0 ? value : nil }
        if selected.last != candidateCounts.last {
            selected.append(candidateCounts.last!)
        }
        return Array(Set(selected)).sorted()
    }

    func approximateConservativeFallbackPartition(
        vectors: [[Double]],
        minTopicSize: Int,
        scoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicPartitionEvaluation {
        let allIndices = Array(vectors.indices)
        let globalCentroid = centroid(for: allIndices, vectors: vectors)
        let centroidSimilarities = allIndices.map { normalizedCosineSimilarity(vectors[$0], globalCentroid) }
        let mean = centroidSimilarities.reduce(0, +) / Double(max(1, centroidSimilarities.count))
        let variance = centroidSimilarities.reduce(0.0) { partialResult, similarity in
            let delta = similarity - mean
            return partialResult + (delta * delta)
        } / Double(max(1, centroidSimilarities.count))
        let threshold = mean - sqrt(max(0, variance))

        var clusterMembers: [Int] = []
        var outlierIndices: [Int] = []
        for (index, similarity) in centroidSimilarities.enumerated() {
            if similarity >= threshold || vectors.count <= minTopicSize {
                clusterMembers.append(index)
            } else {
                outlierIndices.append(index)
            }
        }

        if clusterMembers.count < minTopicSize {
            clusterMembers = allIndices
            outlierIndices = []
        }

        let validClusters = [
            ClusterState(
                memberIndices: clusterMembers,
                centroid: centroid(for: clusterMembers, vectors: vectors)
            )
        ]
        return evaluateApproximatePartition(
            validClusters + outlierIndices.map {
                ClusterState(memberIndices: [$0], centroid: vectors[$0])
            },
            vectors: vectors,
            totalCount: vectors.count,
            minTopicSize: minTopicSize,
            scoringProfile: scoringProfile
        ) ?? TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: 0,
            averageWithinClusterSimilarity: approximateAverageWithinClusterSimilarity(
                validClusters,
                vectors: vectors
            ),
            clusteredCoverage: vectors.isEmpty ? 0 : Double(clusterMembers.count) / Double(vectors.count),
            score: 0
        )
    }
}
