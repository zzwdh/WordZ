import Foundation

extension NativeTopicEngine {
    func approximateClusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int,
        partitionScoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicClusteringResult {
        let normalizedVectors = vectors.map(normalize)
        let conservativePartition = approximateConservativeFallbackPartition(
            vectors: normalizedVectors,
            minTopicSize: minTopicSize,
            scoringProfile: partitionScoringProfile
        )

        let bestPartition = candidateApproximateClusterCounts(
            for: normalizedVectors.count,
            minTopicSize: minTopicSize
        )
        .flatMap { clusterCount in
            (0..<runtimeTuning.topicApproximateClusteringSeedVariants).compactMap { seedVariant -> TopicPartitionEvaluation? in
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
                return evaluateApproximatePartition(
                    refined,
                    vectors: normalizedVectors,
                    totalCount: normalizedVectors.count,
                    minTopicSize: minTopicSize,
                    scoringProfile: partitionScoringProfile
                )
            }
        }
        .max(by: comparePartitions)

        var warnings = [
            approximateClusteringWarning()
        ]

        guard let bestPartition else {
            return TopicClusteringResult(
                validClusters: sortedClusters(conservativePartition.validClusters),
                outlierIndices: conservativePartition.outlierIndices.sorted(),
                similarityMatrix: [],
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .approximateRefined,
                warnings: warnings
            )
        }

        let selectionPolicy = TopicPartitionSelectionPolicy(
            vectorCount: normalizedVectors.count,
            scoringProfile: partitionScoringProfile
        )
        if selectionPolicy.shouldPreferApproximateConservativeFallback(
            current: bestPartition,
            conservative: conservativePartition
        ) {
            warnings.append(conservativeFallbackWarning())
            return TopicClusteringResult(
                validClusters: sortedClusters(conservativePartition.validClusters),
                outlierIndices: conservativePartition.outlierIndices.sorted(),
                similarityMatrix: [],
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .approximateRefined,
                warnings: warnings
            )
        }

        return TopicClusteringResult(
            validClusters: sortedClusters(bestPartition.validClusters),
            outlierIndices: bestPartition.outlierIndices.sorted(),
            similarityMatrix: [],
            silhouetteScore: bestPartition.silhouetteScore,
            strategy: .approximateRefined,
            warnings: warnings
        )
    }


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


    func approximatePartition(
        _ vectors: [[Double]],
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

        var centroids = seedApproximateCentroids(
            for: vectors,
            clusterCount: boundedClusterCount,
            seedVariant: seedVariant
        )
        var assignments = Array(repeating: 0, count: vectors.count)
        var assignmentSimilarities = Array(repeating: -Double.infinity, count: vectors.count)
        var latestClusters: [ClusterState] = []

        for iteration in 0..<runtimeTuning.topicApproximateClusteringIterationLimit {
            var members = Array(
                repeating: [Int](),
                count: centroids.count
            )
            var changed = false

            for index in vectors.indices {
                let assignment = bestCentroidAssignment(
                    for: vectors[index],
                    centroids: centroids
                )
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

            latestClusters = members.enumerated().compactMap { clusterIndex, memberIndices in
                guard !memberIndices.isEmpty else { return nil }
                return ClusterState(
                    memberIndices: memberIndices.sorted(),
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
        centroids.map { cosineSimilarity(vector, $0) }.max() ?? -Double.infinity
    }

    func bestCentroidAssignment(
        for vector: [Double],
        centroids: [[Double]]
    ) -> (index: Int, similarity: Double) {
        var bestIndex = 0
        var bestSimilarity = -Double.infinity
        for (index, centroid) in centroids.enumerated() {
            let similarity = cosineSimilarity(vector, centroid)
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
        minTopicSize: Int
    ) -> [ClusterState] {
        let reassigned = refinedApproximateReassignment(
            clusters,
            vectors: vectors,
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
        minTopicSize: Int
    ) -> [ClusterState] {
        guard !clusters.isEmpty else { return [] }

        var centroids = clusters.map(\.centroid)
        var members = Array(repeating: [Int](), count: centroids.count)
        var assignmentSimilarities = Array(repeating: -Double.infinity, count: vectors.count)

        for index in vectors.indices {
            let assignment = bestCentroidAssignment(
                for: vectors[index],
                centroids: centroids
            )
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

        centroids = members.map { memberIndices in
            centroid(for: memberIndices, vectors: vectors)
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
                    cosineSimilarity(vectors[memberIndex], cluster.centroid)
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


    func approximateConservativeFallbackPartition(
        vectors: [[Double]],
        minTopicSize: Int,
        scoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicPartitionEvaluation {
        let allIndices = Array(vectors.indices)
        let globalCentroid = centroid(for: allIndices, vectors: vectors)
        let centroidSimilarities = allIndices.map { cosineSimilarity(vectors[$0], globalCentroid) }
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
