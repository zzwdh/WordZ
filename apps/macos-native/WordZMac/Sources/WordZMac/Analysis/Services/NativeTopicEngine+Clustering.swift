import Foundation

private struct TopicPartitionEvaluation {
    let validClusters: [ClusterState]
    let outlierIndices: [Int]
    let silhouetteScore: Double
    let averageWithinClusterSimilarity: Double
    let score: Double
}

extension NativeTopicEngine {
    static let exactClusteringVectorLimit = 320
    private static let approximateClusteringIterationLimit = 32
    private static let approximateClusteringClusterLimit = 12
    private static let approximateClusteringSeedVariants = 5
    private static let approximateOutlierSimilarityFloor = 0.18
    private static let approximateOutlierMedianOffset = 0.22

    func clusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> TopicClusteringResult {
        guard !vectors.isEmpty else {
            return TopicClusteringResult(
                validClusters: [],
                outlierIndices: [],
                similarityMatrix: [],
                silhouetteScore: 0,
                strategy: .exact,
                warnings: []
            )
        }

        if vectors.count > Self.exactClusteringVectorLimit {
            return approximateClusterVectors(
                vectors,
                minTopicSize: minTopicSize
            )
        }

        let similarityMatrix = pairwiseSimilarityMatrix(for: vectors)
        var partitions: [[ClusterState]] = [vectors.enumerated().map { index, vector in
            ClusterState(memberIndices: [index], centroid: normalize(vector))
        }]

        while let next = nextAverageLinkagePartition(
            from: partitions.last ?? [],
            vectors: vectors,
            similarityMatrix: similarityMatrix
        ) {
            partitions.append(next)
            if next.count == 1 {
                break
            }
        }

        let bestPartition = partitions
            .compactMap { evaluatePartition($0, similarityMatrix: similarityMatrix, totalCount: vectors.count, minTopicSize: minTopicSize) }
            .max(by: comparePartitions)

        let conservativePartition = conservativeFallbackPartition(
            vectors: vectors,
            similarityMatrix: similarityMatrix,
            minTopicSize: minTopicSize
        )

        guard let bestPartition else {
            return TopicClusteringResult(
                validClusters: sortedClusters(conservativePartition.validClusters),
                outlierIndices: conservativePartition.outlierIndices.sorted(),
                similarityMatrix: similarityMatrix,
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .exact,
                warnings: []
            )
        }

        let lowQuality = bestPartition.validClusters.count > 1
            ? bestPartition.silhouetteScore < 0.08
            : bestPartition.averageWithinClusterSimilarity < 0.22

        if lowQuality && conservativePartition.score >= bestPartition.score - 0.03 {
            return TopicClusteringResult(
                validClusters: sortedClusters(conservativePartition.validClusters),
                outlierIndices: conservativePartition.outlierIndices.sorted(),
                similarityMatrix: similarityMatrix,
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .exact,
                warnings: [conservativeFallbackWarning()]
            )
        }

        return TopicClusteringResult(
            validClusters: sortedClusters(bestPartition.validClusters),
            outlierIndices: bestPartition.outlierIndices.sorted(),
            similarityMatrix: similarityMatrix,
            silhouetteScore: bestPartition.silhouetteScore,
            strategy: .exact,
            warnings: []
        )
    }

    func approximateClusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> TopicClusteringResult {
        let normalizedVectors = vectors.map(normalize)
        let conservativePartition = approximateConservativeFallbackPartition(
            vectors: normalizedVectors,
            minTopicSize: minTopicSize
        )

        let bestPartition = candidateApproximateClusterCounts(
            for: normalizedVectors.count,
            minTopicSize: minTopicSize
        )
        .flatMap { clusterCount in
            (0..<Self.approximateClusteringSeedVariants).compactMap { seedVariant -> TopicPartitionEvaluation? in
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
                    minTopicSize: minTopicSize
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

        let lowQuality = bestPartition.validClusters.count > 1
            ? bestPartition.silhouetteScore < 0.12
            : bestPartition.averageWithinClusterSimilarity < 0.26

        if lowQuality && conservativePartition.score >= bestPartition.score - 0.02 {
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

    func pairwiseSimilarityMatrix(for vectors: [[Double]]) -> [[Double]] {
        guard !vectors.isEmpty else { return [] }

        var matrix = Array(
            repeating: Array(repeating: 0.0, count: vectors.count),
            count: vectors.count
        )
        for lhs in vectors.indices {
            matrix[lhs][lhs] = 1
            for rhs in (lhs + 1)..<vectors.count {
                let similarity = cosineSimilarity(vectors[lhs], vectors[rhs])
                matrix[lhs][rhs] = similarity
                matrix[rhs][lhs] = similarity
            }
        }
        return matrix
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
            Self.approximateClusteringClusterLimit,
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

        for iteration in 0..<Self.approximateClusteringIterationLimit {
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

    func centroid(for memberIndices: [Int], vectors: [[Double]]) -> [Double] {
        guard let firstIndex = memberIndices.first else { return [] }

        var centroid = Array(repeating: 0.0, count: vectors[firstIndex].count)
        for memberIndex in memberIndices {
            let vector = vectors[memberIndex]
            for component in vector.indices {
                centroid[component] += vector[component]
            }
        }

        let count = Double(max(1, memberIndices.count))
        centroid = centroid.map { $0 / count }
        return normalize(centroid)
    }

    fileprivate func evaluatePartition(
        _ clusters: [ClusterState],
        similarityMatrix: [[Double]],
        totalCount: Int,
        minTopicSize: Int
    ) -> TopicPartitionEvaluation? {
        guard !clusters.isEmpty else { return nil }

        let validClusters = clusters.filter { $0.memberIndices.count >= minTopicSize }
        let outlierIndices = clusters
            .filter { $0.memberIndices.count < minTopicSize }
            .flatMap(\.memberIndices)
            .sorted()
        guard !validClusters.isEmpty else { return nil }

        let outlierPenalty = totalCount == 0
            ? 0
            : Double(outlierIndices.count) / Double(totalCount) * 0.25
        let clusteredCoverage = totalCount == 0
            ? 0
            : Double(validClusters.reduce(0) { $0 + $1.memberIndices.count }) / Double(totalCount)
        let coverageBonus = clusteredCoverage * 0.1
        let averageWithin = averageWithinClusterSimilarity(
            validClusters,
            similarityMatrix: similarityMatrix
        )

        if validClusters.count < 2 {
            let score = averageWithin + coverageBonus - outlierPenalty - 0.1
            return TopicPartitionEvaluation(
                validClusters: validClusters,
                outlierIndices: outlierIndices,
                silhouetteScore: 0,
                averageWithinClusterSimilarity: averageWithin,
                score: score
            )
        }

        let silhouette = meanSilhouetteScore(
            validClusters,
            similarityMatrix: similarityMatrix
        )
        let score = silhouette
            + min(0.06, Double(validClusters.count - 2) * 0.015)
            + coverageBonus
            - outlierPenalty
        return TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: silhouette,
            averageWithinClusterSimilarity: averageWithin,
            score: score
        )
    }

    fileprivate func evaluateApproximatePartition(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        totalCount: Int,
        minTopicSize: Int
    ) -> TopicPartitionEvaluation? {
        guard !clusters.isEmpty else { return nil }

        let validClusters = clusters.filter { $0.memberIndices.count >= minTopicSize }
        let outlierIndices = clusters
            .filter { $0.memberIndices.count < minTopicSize }
            .flatMap(\.memberIndices)
            .sorted()
        guard !validClusters.isEmpty else { return nil }

        let outlierPenalty = totalCount == 0
            ? 0
            : Double(outlierIndices.count) / Double(totalCount) * 0.25
        let clusteredCoverage = totalCount == 0
            ? 0
            : Double(validClusters.reduce(0) { $0 + $1.memberIndices.count }) / Double(totalCount)
        let coverageBonus = clusteredCoverage * 0.1
        let averageWithin = approximateAverageWithinClusterSimilarity(
            validClusters,
            vectors: vectors
        )

        if validClusters.count < 2 {
            let score = averageWithin + coverageBonus - outlierPenalty - 0.08
            return TopicPartitionEvaluation(
                validClusters: validClusters,
                outlierIndices: outlierIndices,
                silhouetteScore: 0,
                averageWithinClusterSimilarity: averageWithin,
                score: score
            )
        }

        let separation = approximateClusterSeparation(validClusters)
        let silhouetteProxy = max(-1, min(1, averageWithin - (1 - separation)))
        let score = (averageWithin * 0.62)
            + (separation * 0.32)
            + min(0.04, Double(validClusters.count - 1) * 0.01)
            + coverageBonus
            - outlierPenalty
        return TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: silhouetteProxy,
            averageWithinClusterSimilarity: averageWithin,
            score: score
        )
    }

    fileprivate func comparePartitions(_ lhs: TopicPartitionEvaluation, _ rhs: TopicPartitionEvaluation) -> Bool {
        if lhs.score == rhs.score {
            if lhs.validClusters.count == rhs.validClusters.count {
                return lhs.outlierIndices.count > rhs.outlierIndices.count
            }
            return lhs.validClusters.count < rhs.validClusters.count
        }
        return lhs.score < rhs.score
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
                partialResult + cosineSimilarity(vectors[memberIndex], cluster.centroid)
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
                total += cosineDistance(
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

    fileprivate func conservativeFallbackPartition(
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        minTopicSize: Int
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
        return evaluatePartition(
            validClusters + outlierIndices.map {
                ClusterState(memberIndices: [$0], centroid: vectors[$0])
            },
            similarityMatrix: similarityMatrix,
            totalCount: vectors.count,
            minTopicSize: minTopicSize
        ) ?? TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: 0,
            averageWithinClusterSimilarity: averageSimilarity(
                within: clusterMembers,
                similarityMatrix: similarityMatrix
            ),
            score: 0
        )
    }

    fileprivate func approximateConservativeFallbackPartition(
        vectors: [[Double]],
        minTopicSize: Int
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
            minTopicSize: minTopicSize
        ) ?? TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: 0,
            averageWithinClusterSimilarity: approximateAverageWithinClusterSimilarity(
                validClusters,
                vectors: vectors
            ),
            score: 0
        )
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

    func cosineDistance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        let boundedSimilarity = max(-1, min(1, cosineSimilarity(lhs, rhs)))
        return (1 - boundedSimilarity) / 2
    }

    func normalize(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else { return [] }
        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}
