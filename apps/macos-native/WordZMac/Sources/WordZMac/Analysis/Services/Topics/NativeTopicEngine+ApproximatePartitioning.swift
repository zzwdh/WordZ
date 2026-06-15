import Foundation

extension NativeTopicEngine {
    func approximatePartition(
        _ vectors: [[Double]],
        normalizedMatrix: TopicNormalizedVectorMatrix? = nil,
        clusterCount: Int,
        minTopicSize: Int,
        seedVariant: Int,
        iterationLimit: Int? = nil
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

        var centroids = seedApproximateCentroids(
            for: vectors,
            clusterCount: boundedClusterCount,
            seedVariant: seedVariant
        )
        var assignments = Array(repeating: 0, count: vectors.count)
        var assignmentSimilarities = Array(repeating: -Double.infinity, count: vectors.count)
        var latestClusters: [ClusterState] = []
        let iterationLimit = max(1, iterationLimit ?? runtimeTuning.topicApproximateClusteringIterationLimit)

        for iteration in 0..<iterationLimit {
            var members = Array(
                repeating: [Int](),
                count: centroids.count
            )
            var changed = false
            let centroidAssignments = bestCentroidAssignments(
                for: vectors,
                normalizedMatrix: normalizedMatrix,
                centroids: centroids
            )

            for index in vectors.indices {
                let assignment = centroidAssignments[index]
                if assignments[index] != assignment.index {
                    changed = true
                    assignments[index] = assignment.index
                }
                assignmentSimilarities[index] = assignment.similarity
                members[assignment.index].append(index)
            }

            if members.contains(where: \.isEmpty) {
                changed = true
                for clusterIndex in members.indices where members[clusterIndex].isEmpty {
                    let donorIndex = assignments.indices
                        .filter { members[assignments[$0]].count > max(1, minTopicSize) }
                        .min { assignmentSimilarities[$0] < assignmentSimilarities[$1] }
                        ?? assignments.indices.min { assignmentSimilarities[$0] < assignmentSimilarities[$1] }

                    guard let donorIndex else { continue }
                    let previousClusterIndex = assignments[donorIndex]
                    members[previousClusterIndex].removeAll(where: { $0 == donorIndex })
                    members[clusterIndex] = [donorIndex]
                    assignments[donorIndex] = clusterIndex
                    assignmentSimilarities[donorIndex] = 1
                    centroids[clusterIndex] = vectors[donorIndex]
                }
            }

            latestClusters = members.enumerated().compactMap { _, memberIndices in
                guard !memberIndices.isEmpty else { return nil }
                return ClusterState(
                    memberIndices: memberIndices,
                    centroid: centroid(for: memberIndices, vectors: vectors)
                )
            }
            centroids = latestClusters.map(\.centroid)

            if !changed && iteration > 0 {
                break
            }
        }

        if latestClusters.isEmpty {
            latestClusters = [
                ClusterState(
                    memberIndices: Array(vectors.indices),
                    centroid: centroid(for: Array(vectors.indices), vectors: vectors)
                )
            ]
        }

        return latestClusters
    }

    func seedApproximateCentroids(
        for vectors: [[Double]],
        clusterCount: Int,
        seedVariant: Int
    ) -> [[Double]] {
        guard !vectors.isEmpty else { return [] }

        let startIndex = min(
            vectors.count - 1,
            max(0, (seedVariant * max(1, vectors.count / max(1, clusterCount))) % vectors.count)
        )
        var centroids = [normalize(vectors[startIndex])]
        while centroids.count < clusterCount {
            guard let nextIndex = vectors.indices.max(by: { lhs, rhs in
                nearestCentroidSimilarity(
                    for: vectors[lhs],
                    centroids: centroids
                ) < nearestCentroidSimilarity(
                    for: vectors[rhs],
                    centroids: centroids
                )
            }) else {
                break
            }
            centroids.append(normalize(vectors[nextIndex]))
        }
        return centroids
    }

    func nearestCentroidSimilarity(
        for vector: [Double],
        centroids: [[Double]]
    ) -> Double {
        centroids.map { normalizedCosineSimilarity(vector, $0) }.max() ?? -Double.infinity
    }

    func bestCentroidAssignment(
        for vector: [Double],
        centroids: [[Double]]
    ) -> (index: Int, similarity: Double) {
        var bestIndex = 0
        var bestSimilarity = -Double.infinity
        for (index, centroid) in centroids.enumerated() {
            let similarity = normalizedCosineSimilarity(vector, centroid)
            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestIndex = index
            }
        }
        return (bestIndex, bestSimilarity)
    }

    func refineApproximatePartition(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        normalizedMatrix: TopicNormalizedVectorMatrix? = nil,
        minTopicSize: Int
    ) -> [ClusterState] {
        let reassigned = refinedApproximateReassignment(
            clusters,
            vectors: vectors,
            normalizedMatrix: normalizedMatrix,
            minTopicSize: minTopicSize
        )
        return peelApproximateOutliers(
            reassigned,
            vectors: vectors,
            minTopicSize: minTopicSize
        )
    }

    func refinedApproximateReassignment(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        normalizedMatrix: TopicNormalizedVectorMatrix? = nil,
        minTopicSize: Int
    ) -> [ClusterState] {
        guard !clusters.isEmpty else { return [] }

        let centroids = clusters.map(\.centroid)
        var members = Array(repeating: [Int](), count: centroids.count)
        var assignmentSimilarities = Array(repeating: -Double.infinity, count: vectors.count)
        let centroidAssignments = bestCentroidAssignments(
            for: vectors,
            normalizedMatrix: normalizedMatrix,
            centroids: centroids
        )

        for index in vectors.indices {
            let assignment = centroidAssignments[index]
            members[assignment.index].append(index)
            assignmentSimilarities[index] = assignment.similarity
        }

        if members.contains(where: \.isEmpty) {
            for clusterIndex in members.indices where members[clusterIndex].isEmpty {
                let donorIndex = members.indices
                    .filter { !members[$0].isEmpty }
                    .max { lhs, rhs in
                        members[lhs].count < members[rhs].count
                    }
                guard let donorIndex,
                      let displaced = members[donorIndex].min(by: {
                          assignmentSimilarities[$0] < assignmentSimilarities[$1]
                      }) else {
                    continue
                }
                members[donorIndex].removeAll(where: { $0 == displaced })
                members[clusterIndex] = [displaced]
            }
        }

        return members.enumerated().compactMap { _, memberIndices in
            guard !memberIndices.isEmpty else { return nil }
            return ClusterState(
                memberIndices: memberIndices.sorted(),
                centroid: centroid(for: memberIndices, vectors: vectors)
            )
        }
    }

    func peelApproximateOutliers(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        minTopicSize: Int
    ) -> [ClusterState] {
        var refined: [ClusterState] = []
        refined.reserveCapacity(clusters.count)

        for cluster in clusters {
            guard cluster.memberIndices.count > minTopicSize + 1 else {
                refined.append(cluster)
                continue
            }

            let memberSimilarities = cluster.memberIndices.map { memberIndex in
                (
                    memberIndex,
                    normalizedCosineSimilarity(vectors[memberIndex], cluster.centroid)
                )
            }
            let sortedSimilarities = memberSimilarities.map(\.1).sorted()
            let median = sortedSimilarities[sortedSimilarities.count / 2]
            let threshold = max(
                Self.approximateOutlierSimilarityFloor,
                median - Self.approximateOutlierMedianOffset
            )

            let keptMembers = memberSimilarities
                .filter { $0.1 >= threshold }
                .map(\.0)
                .sorted()
            let outliers = memberSimilarities
                .filter { $0.1 < threshold }
                .map(\.0)
                .sorted()

            guard !outliers.isEmpty, keptMembers.count >= minTopicSize else {
                refined.append(cluster)
                continue
            }

            refined.append(
                ClusterState(
                    memberIndices: keptMembers,
                    centroid: centroid(for: keptMembers, vectors: vectors)
                )
            )
            refined.append(
                contentsOf: outliers.map { memberIndex in
                    ClusterState(
                        memberIndices: [memberIndex],
                        centroid: vectors[memberIndex]
                    )
                }
            )
        }

        return refined
    }

    func clustersWithSortedMembers(_ clusters: [ClusterState]) -> [ClusterState] {
        clusters.map { cluster in
            ClusterState(
                memberIndices: cluster.memberIndices.sorted(),
                centroid: cluster.centroid
            )
        }
    }
}
