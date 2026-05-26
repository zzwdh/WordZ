import Foundation

extension NativeTopicEngine {
    func candidateExactClusterCounts(
        for vectorCount: Int,
        minTopicSize: Int
    ) -> [Int] {
        guard vectorCount > 1 else { return [1] }

        let minClusterSize = max(2, minTopicSize)
        let maxFeasibleClusters = max(2, vectorCount / minClusterSize)
        let upperBound = min(
            Self.exactSmallCorpusClusterLimit,
            maxFeasibleClusters
        )
        guard upperBound >= 2 else { return [2] }
        return Array(2...upperBound)
    }

    func exactRefinementPartitions(
        vectors: [[Double]],
        minTopicSize: Int
    ) -> [[ClusterState]] {
        let normalizedVectors = vectors.map(normalize)
        return candidateExactClusterCounts(
            for: vectors.count,
            minTopicSize: minTopicSize
        )
        .flatMap { clusterCount in
            (0..<Self.exactSmallCorpusSeedVariants).map { seedVariant in
                let partition = approximatePartition(
                    normalizedVectors,
                    clusterCount: clusterCount,
                    minTopicSize: minTopicSize,
                    seedVariant: seedVariant
                )
                let refined = refineApproximatePartition(
                    partition,
                    vectors: normalizedVectors,
                    minTopicSize: minTopicSize
                )
                return rehydratedExactClusters(
                    refined,
                    vectors: vectors
                )
            }
        }
    }

    func rehydratedExactClusters(
        _ clusters: [ClusterState],
        vectors: [[Double]]
    ) -> [ClusterState] {
        clusters.compactMap { cluster in
            guard !cluster.memberIndices.isEmpty else { return nil }
            let sortedMembers = cluster.memberIndices.sorted()
            return ClusterState(
                memberIndices: sortedMembers,
                centroid: centroid(for: sortedMembers, vectors: vectors)
            )
        }
    }
}
