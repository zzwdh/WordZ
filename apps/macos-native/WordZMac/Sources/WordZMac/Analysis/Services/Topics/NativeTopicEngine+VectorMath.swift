import Accelerate
import Foundation

extension NativeTopicEngine {
    func centroid(for memberIndices: [Int], vectors: [[Double]]) -> [Double] {
        guard let firstIndex = memberIndices.first else { return [] }

        var centroid = Array(repeating: 0.0, count: vectors[firstIndex].count)
        for memberIndex in memberIndices {
            let vector = vectors[memberIndex]
            vDSP_vaddD(
                centroid,
                1,
                vector,
                1,
                &centroid,
                1,
                vDSP_Length(centroid.count)
            )
        }

        var scale = 1.0 / Double(max(1, memberIndices.count))
        vDSP_vsmulD(
            centroid,
            1,
            &scale,
            &centroid,
            1,
            vDSP_Length(centroid.count)
        )
        return normalize(centroid)
    }


    func averageWithinClusterSimilarity(
        _ clusters: [ClusterState],
        similarityMatrix: [[Double]]
    ) -> Double {
        let similarities = clusters.map { cluster in
            averageSimilarity(within: cluster.memberIndices, similarityMatrix: similarityMatrix)
        }
        guard !similarities.isEmpty else { return 0 }
        return similarities.reduce(0, +) / Double(similarities.count)
    }

    func approximateAverageWithinClusterSimilarity(
        _ clusters: [ClusterState],
        vectors: [[Double]]
    ) -> Double {
        let similarities = clusters.map { cluster -> Double in
            guard !cluster.memberIndices.isEmpty else { return 0 }
            let total = cluster.memberIndices.reduce(0.0) { partialResult, memberIndex in
                partialResult + normalizedCosineSimilarity(vectors[memberIndex], cluster.centroid)
            }
            return total / Double(cluster.memberIndices.count)
        }
        guard !similarities.isEmpty else { return 0 }
        return similarities.reduce(0, +) / Double(similarities.count)
    }

    func approximateClusterSeparation(_ clusters: [ClusterState]) -> Double {
        guard clusters.count > 1 else { return 0 }

        var total = 0.0
        var comparisons = 0
        for lhs in 0..<clusters.count {
            for rhs in (lhs + 1)..<clusters.count {
                total += normalizedCosineDistance(
                    clusters[lhs].centroid,
                    clusters[rhs].centroid
                )
                comparisons += 1
            }
        }
        return comparisons == 0 ? 0 : total / Double(comparisons)
    }

    func averageSimilarity(
        within memberIndices: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        guard memberIndices.count > 1 else { return 1 }

        var total = 0.0
        var comparisons = 0
        for lhs in 0..<memberIndices.count {
            for rhs in (lhs + 1)..<memberIndices.count {
                total += similarityMatrix[memberIndices[lhs]][memberIndices[rhs]]
                comparisons += 1
            }
        }
        return comparisons == 0 ? 1 : total / Double(comparisons)
    }

    func meanSilhouetteScore(
        _ clusters: [ClusterState],
        similarityMatrix: [[Double]]
    ) -> Double {
        guard clusters.count > 1 else { return 0 }

        let membership = Dictionary(
            uniqueKeysWithValues: clusters.enumerated().flatMap { clusterIndex, cluster in
                cluster.memberIndices.map { ($0, clusterIndex) }
            }
        )

        var scores: [Double] = []
        scores.reserveCapacity(membership.count)
        for (memberIndex, clusterIndex) in membership.sorted(by: { $0.key < $1.key }) {
            let ownCluster = clusters[clusterIndex].memberIndices
            let a = averageDistance(
                from: memberIndex,
                to: ownCluster.filter { $0 != memberIndex },
                similarityMatrix: similarityMatrix
            )

            var b = Double.infinity
            for (candidateIndex, candidateCluster) in clusters.enumerated() where candidateIndex != clusterIndex {
                let candidateDistance = averageDistance(
                    from: memberIndex,
                    to: candidateCluster.memberIndices,
                    similarityMatrix: similarityMatrix
                )
                b = min(b, candidateDistance)
            }

            let denominator = max(a, b)
            let silhouette = denominator > 0 && b.isFinite
                ? (b - a) / denominator
                : 0
            scores.append(silhouette)
        }

        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    func averageDistance(
        from memberIndex: Int,
        to candidates: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        guard !candidates.isEmpty else { return 0 }

        let total = candidates.reduce(0.0) { partialResult, candidateIndex in
            partialResult + (1 - similarityMatrix[memberIndex][candidateIndex])
        }
        return total / Double(candidates.count)
    }

    func averageSimilarity(
        from memberIndex: Int,
        to candidates: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        guard !candidates.isEmpty else { return 1 }

        let total = candidates.reduce(0.0) { partialResult, candidateIndex in
            partialResult + similarityMatrix[memberIndex][candidateIndex]
        }
        return total / Double(candidates.count)
    }


    func sortedClusters(_ clusters: [ClusterState]) -> [ClusterState] {
        clusters.sorted {
            if $0.memberIndices.count == $1.memberIndices.count {
                return $0.memberIndices.min() ?? 0 < $1.memberIndices.min() ?? 0
            }
            return $0.memberIndices.count > $1.memberIndices.count
        }
    }

    func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        let dot = cblas_ddot(Int32(lhs.count), lhs, 1, rhs, 1)
        let lhsNorm = cblas_ddot(Int32(lhs.count), lhs, 1, lhs, 1)
        let rhsNorm = cblas_ddot(Int32(rhs.count), rhs, 1, rhs, 1)
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    func cosineDistance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let boundedSimilarity = max(-1, min(1, cosineSimilarity(lhs, rhs)))
        return (1 - boundedSimilarity) / 2
    }

    func normalizedCosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        return max(-1, min(1, cblas_ddot(Int32(lhs.count), lhs, 1, rhs, 1)))
    }

    func normalizedCosineDistance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        (1 - normalizedCosineSimilarity(lhs, rhs)) / 2
    }

    func normalize(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else { return [] }
        let magnitude = cblas_dnrm2(Int32(vector.count), vector, 1)
        guard magnitude > 0 else { return vector }
        var scale = 1.0 / magnitude
        var normalized = Array(repeating: 0.0, count: vector.count)
        vDSP_vsmulD(
            vector,
            1,
            &scale,
            &normalized,
            1,
            vDSP_Length(vector.count)
        )
        return normalized
    }

}
