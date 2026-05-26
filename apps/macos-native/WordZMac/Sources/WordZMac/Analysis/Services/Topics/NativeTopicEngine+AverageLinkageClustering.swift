import Foundation

extension NativeTopicEngine {
    func nextAverageLinkagePartition(
        from clusters: [ClusterState],
        vectors: [[Double]],
        similarityMatrix: [[Double]]
    ) -> [ClusterState]? {
        guard clusters.count > 1 else { return nil }

        var bestPair: (Int, Int)?
        var bestSimilarity = -Double.infinity
        for lhs in 0..<clusters.count {
            for rhs in (lhs + 1)..<clusters.count {
                let similarity = averageLinkageSimilarity(
                    lhs: clusters[lhs].memberIndices,
                    rhs: clusters[rhs].memberIndices,
                    similarityMatrix: similarityMatrix
                )
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestPair = (lhs, rhs)
                }
            }
        }

        guard let bestPair else { return nil }

        var nextClusters = clusters
        let mergedIndices = (clusters[bestPair.0].memberIndices + clusters[bestPair.1].memberIndices).sorted()
        nextClusters[bestPair.0] = ClusterState(
            memberIndices: mergedIndices,
            centroid: centroid(for: mergedIndices, vectors: vectors)
        )
        nextClusters.remove(at: bestPair.1)
        return nextClusters
    }

    func averageLinkageSimilarity(
        lhs: [Int],
        rhs: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }

        var total = 0.0
        var pairCount = 0
        for leftIndex in lhs {
            for rightIndex in rhs {
                total += similarityMatrix[leftIndex][rightIndex]
                pairCount += 1
            }
        }
        return pairCount == 0 ? 0 : total / Double(pairCount)
    }

}
