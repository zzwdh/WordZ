import Foundation

extension NativeTopicEngine {
    func clusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> (validClusters: [ClusterState], outlierIndices: [Int]) {
        guard !vectors.isEmpty else {
            return ([], [])
        }

        var clusters = vectors.enumerated().map { index, vector in
            ClusterState(memberIndices: [index], centroid: normalize(vector))
        }
        let mergeThreshold = similarityThreshold(for: vectors.count)

        while clusters.count > 1 {
            var bestPair: (Int, Int)?
            var bestSimilarity = -1.0

            for lhs in 0..<clusters.count {
                for rhs in (lhs + 1)..<clusters.count {
                    let similarity = cosineSimilarity(clusters[lhs].centroid, clusters[rhs].centroid)
                    if similarity > bestSimilarity {
                        bestSimilarity = similarity
                        bestPair = (lhs, rhs)
                    }
                }
            }

            guard let bestPair, bestSimilarity >= mergeThreshold else {
                break
            }

            let merged = mergeClusters(clusters[bestPair.0], clusters[bestPair.1], vectors: vectors)
            clusters[bestPair.0] = merged
            clusters.remove(at: bestPair.1)
        }

        let sortedClusters = clusters.sorted {
            if $0.memberIndices.count == $1.memberIndices.count {
                return $0.memberIndices.min() ?? 0 < $1.memberIndices.min() ?? 0
            }
            return $0.memberIndices.count > $1.memberIndices.count
        }

        var valid: [ClusterState] = []
        var outliers: [Int] = []
        for cluster in sortedClusters {
            if cluster.memberIndices.count >= minTopicSize {
                valid.append(cluster)
            } else {
                outliers.append(contentsOf: cluster.memberIndices)
            }
        }

        return (valid, outliers.sorted())
    }

    func mergeClusters(
        _ lhs: ClusterState,
        _ rhs: ClusterState,
        vectors: [[Double]]
    ) -> ClusterState {
        let mergedIndices = (lhs.memberIndices + rhs.memberIndices).sorted()
        let dimension = lhs.centroid.count
        guard dimension > 0 else {
            return ClusterState(memberIndices: mergedIndices, centroid: [])
        }

        var centroid = Array(repeating: 0.0, count: dimension)
        for index in mergedIndices {
            let vector = vectors[index]
            for component in 0..<dimension {
                centroid[component] += vector[component]
            }
        }
        let count = Double(max(1, mergedIndices.count))
        centroid = centroid.map { $0 / count }
        return ClusterState(memberIndices: mergedIndices, centroid: normalize(centroid))
    }

    func similarityThreshold(for segmentCount: Int) -> Double {
        switch segmentCount {
        case ..<10:
            return 0.82
        case ..<30:
            return 0.78
        default:
            return 0.74
        }
    }

    func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    func normalize(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else { return [] }
        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}
