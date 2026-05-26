import Foundation

extension NativeTopicEngine {
    func exactMedoidPartition(
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        clusterCount: Int,
        minTopicSize: Int,
        seedVariant: Int
    ) -> [ClusterState] {
        let boundedClusterCount = max(1, min(clusterCount, vectors.count))
        guard boundedClusterCount > 1 else {
            return [
                ClusterState(
                    memberIndices: Array(vectors.indices),
                    centroid: centroid(for: Array(vectors.indices), vectors: vectors)
                )
            ]
        }

        var medoids = seedExactMedoids(
            similarityMatrix: similarityMatrix,
            clusterCount: boundedClusterCount,
            seedVariant: seedVariant
        )
        var latestMembers = Array(repeating: [Int](), count: boundedClusterCount)

        for _ in 0..<Self.exactSmallCorpusIterationLimit {
            var members = Array(repeating: [Int](), count: boundedClusterCount)
            for memberIndex in vectors.indices {
                let assignment = bestMedoidAssignment(
                    for: memberIndex,
                    medoids: medoids,
                    similarityMatrix: similarityMatrix
                )
                members[assignment].append(memberIndex)
            }

            if members.contains(where: \.isEmpty) {
                stabilizeExactMembers(
                    &members,
                    medoids: medoids,
                    similarityMatrix: similarityMatrix,
                    minTopicSize: minTopicSize
                )
            }

            let updatedMedoids = members.enumerated().map { clusterIndex, memberIndices in
                bestMedoid(
                    members: memberIndices,
                    fallback: medoids[clusterIndex],
                    similarityMatrix: similarityMatrix
                )
            }

            latestMembers = members
            if updatedMedoids == medoids {
                break
            }
            medoids = updatedMedoids
        }

        if latestMembers.allSatisfy(\.isEmpty) {
            latestMembers = medoids.map { [$0] }
        }

        return latestMembers.enumerated().compactMap { _, memberIndices in
            guard !memberIndices.isEmpty else { return nil }
            let sortedMembers = memberIndices.sorted()
            return ClusterState(
                memberIndices: sortedMembers,
                centroid: centroid(for: sortedMembers, vectors: vectors)
            )
        }
    }

    func seedExactMedoids(
        similarityMatrix: [[Double]],
        clusterCount: Int,
        seedVariant: Int
    ) -> [Int] {
        guard !similarityMatrix.isEmpty else { return [] }

        let indices = Array(similarityMatrix.indices)
        let rankedByDistinctiveness = indices.sorted { lhs, rhs in
            let lhsAverage = averageSimilarityToAll(memberIndex: lhs, similarityMatrix: similarityMatrix)
            let rhsAverage = averageSimilarityToAll(memberIndex: rhs, similarityMatrix: similarityMatrix)
            if lhsAverage == rhsAverage {
                return lhs < rhs
            }
            return lhsAverage < rhsAverage
        }

        let startOffset = min(seedVariant, max(0, rankedByDistinctiveness.count - 1))
        var medoids = [rankedByDistinctiveness[startOffset]]
        while medoids.count < clusterCount {
            guard let candidate = indices
                .filter({ !medoids.contains($0) })
                .max(by: { lhs, rhs in
                    nearestMedoidDistance(
                        memberIndex: lhs,
                        medoids: medoids,
                        similarityMatrix: similarityMatrix
                    ) < nearestMedoidDistance(
                        memberIndex: rhs,
                        medoids: medoids,
                        similarityMatrix: similarityMatrix
                    )
                }) else {
                break
            }
            medoids.append(candidate)
        }
        return medoids
    }

    func averageSimilarityToAll(
        memberIndex: Int,
        similarityMatrix: [[Double]]
    ) -> Double {
        guard similarityMatrix.indices.contains(memberIndex), similarityMatrix.count > 1 else {
            return 0
        }
        let total = similarityMatrix[memberIndex]
            .enumerated()
            .filter { $0.offset != memberIndex }
            .reduce(0.0) { $0 + $1.element }
        return total / Double(max(1, similarityMatrix.count - 1))
    }

    func nearestMedoidDistance(
        memberIndex: Int,
        medoids: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        let bestSimilarity = medoids.map { similarityMatrix[memberIndex][$0] }.max() ?? 0
        return 1 - bestSimilarity
    }

    func bestMedoidAssignment(
        for memberIndex: Int,
        medoids: [Int],
        similarityMatrix: [[Double]]
    ) -> Int {
        var bestCluster = 0
        var bestSimilarity = -Double.infinity
        for (clusterIndex, medoidIndex) in medoids.enumerated() {
            let similarity = similarityMatrix[memberIndex][medoidIndex]
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestCluster = clusterIndex
            }
        }
        return bestCluster
    }

    func stabilizeExactMembers(
        _ members: inout [[Int]],
        medoids: [Int],
        similarityMatrix: [[Double]],
        minTopicSize: Int
    ) {
        for clusterIndex in members.indices where members[clusterIndex].isEmpty {
            let donorCluster = members.indices
                .filter { members[$0].count > max(1, minTopicSize) }
                .max(by: { members[$0].count < members[$1].count })
                ?? members.indices.max(by: { members[$0].count < members[$1].count })

            guard let donorCluster,
                  let displaced = members[donorCluster].min(by: { lhs, rhs in
                      similarityMatrix[lhs][medoids[donorCluster]] < similarityMatrix[rhs][medoids[donorCluster]]
                  }) else {
                continue
            }
            members[donorCluster].removeAll(where: { $0 == displaced })
            members[clusterIndex] = [displaced]
        }
    }

    func bestMedoid(
        members: [Int],
        fallback: Int,
        similarityMatrix: [[Double]]
    ) -> Int {
        guard !members.isEmpty else { return fallback }
        return members.max { lhs, rhs in
            averageSimilarity(
                from: lhs,
                to: members.filter { $0 != lhs },
                similarityMatrix: similarityMatrix
            ) < averageSimilarity(
                from: rhs,
                to: members.filter { $0 != rhs },
                similarityMatrix: similarityMatrix
            )
        } ?? fallback
    }

}
