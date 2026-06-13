import Accelerate
import Foundation

extension NativeTopicEngine {
    func approximateClusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int,
        partitionScoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicClusteringResult {
        let diagnostics = TopicApproximateClusteringDiagnosticsBuilder()
        let normalizedVectors = diagnostics.measure("normalizing") {
            vectors.map(normalize)
        }
        let normalizedMatrix = diagnostics.measure("matrixBuild") {
            normalizedVectorMatrix(for: normalizedVectors)
        }
        let conservativePartition = diagnostics.measure("candidateSearch") {
            approximateConservativeFallbackPartition(
                vectors: normalizedVectors,
                minTopicSize: minTopicSize,
                scoringProfile: partitionScoringProfile
            )
        }

        func evaluateCandidate(
            clusterCount: Int,
            seedVariant: Int,
            iterationLimit: Int
        ) -> TopicPartitionEvaluation? {
            diagnostics.recordCandidateEvaluation()
            let partition = diagnostics.measure("assignment") {
                approximatePartition(
                    normalizedVectors,
                    normalizedMatrix: normalizedMatrix,
                    clusterCount: clusterCount,
                    minTopicSize: minTopicSize,
                    seedVariant: seedVariant,
                    iterationLimit: iterationLimit
                )
            }
            let refined = diagnostics.measure("refinement") {
                refineApproximatePartition(
                    partition,
                    vectors: normalizedVectors,
                    normalizedMatrix: normalizedMatrix,
                    minTopicSize: minTopicSize
                )
            }
            return diagnostics.measure("evaluation") {
                evaluateApproximatePartition(
                    refined,
                    vectors: normalizedVectors,
                    totalCount: normalizedVectors.count,
                    minTopicSize: minTopicSize,
                    scoringProfile: partitionScoringProfile
                )
            }
        }

        let candidateCounts = diagnostics.measure("candidateSearch") {
            candidateApproximateClusterCounts(
                for: normalizedVectors.count,
                minTopicSize: minTopicSize
            )
        }
        let usesTwoStageSearch = normalizedVectors.count >= runtimeTuning.topicApproximateClusteringLargeCorpusVectorThreshold
        let bestPartition: TopicPartitionEvaluation?
        if usesTwoStageSearch {
            diagnostics.setUsedTwoStageSearch(true)
            let coarseCounts = diagnostics.measure("candidateSearch") {
                coarseApproximateClusterCounts(from: candidateCounts)
            }
            diagnostics.setCoarseCandidateCounts(coarseCounts)
            let coarseEvaluations: [(clusterCount: Int, evaluation: TopicPartitionEvaluation)] = coarseCounts.compactMap { clusterCount in
                evaluateCandidate(
                    clusterCount: clusterCount,
                    seedVariant: 0,
                    iterationLimit: runtimeTuning.topicApproximateClusteringCoarseIterationLimit
                ).map { (clusterCount, $0) }
            }
            let refinedCounts = diagnostics.measure("candidateSearch") {
                Array(
                    coarseEvaluations
                        .sorted { lhs, rhs in
                            comparePartitions(rhs.evaluation, lhs.evaluation)
                        }
                        .prefix(max(1, runtimeTuning.topicApproximateClusteringRefineCandidateLimit))
                        .map(\.clusterCount)
                )
            }
            diagnostics.setRefinedCandidateCounts(refinedCounts)
            let refinedEvaluations: [(clusterCount: Int, evaluation: TopicPartitionEvaluation)] = refinedCounts.flatMap { clusterCount in
                (0..<runtimeTuning.topicApproximateClusteringSeedVariants).compactMap { seedVariant -> (clusterCount: Int, evaluation: TopicPartitionEvaluation)? in
                    evaluateCandidate(
                        clusterCount: clusterCount,
                        seedVariant: seedVariant,
                        iterationLimit: runtimeTuning.topicApproximateClusteringIterationLimit
                    ).map { (clusterCount, $0) }
                }
            }
            let eligibleEvaluations = refinedEvaluations.isEmpty ? coarseEvaluations : refinedEvaluations
            bestPartition = eligibleEvaluations
                .map(\.evaluation)
                .max(by: comparePartitions)
        } else {
            diagnostics.setRefinedCandidateCounts(candidateCounts)
            bestPartition = candidateCounts
                .flatMap { clusterCount in
                    (0..<runtimeTuning.topicApproximateClusteringSeedVariants).compactMap { seedVariant -> TopicPartitionEvaluation? in
                        evaluateCandidate(
                            clusterCount: clusterCount,
                            seedVariant: seedVariant,
                            iterationLimit: runtimeTuning.topicApproximateClusteringIterationLimit
                        )
                    }
                }
                .max(by: comparePartitions)
        }

        let approximateDiagnostics = diagnostics.build()
        let sortedConservativeClusters = clustersWithSortedMembers(conservativePartition.validClusters)
        let sortedConservativeOutliers = conservativePartition.outlierIndices.sorted()

        var warnings = [
            approximateClusteringWarning()
        ]

        guard let bestPartition else {
            return TopicClusteringResult(
                validClusters: sortedClusters(sortedConservativeClusters),
                outlierIndices: sortedConservativeOutliers,
                similarityMatrix: [],
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .approximateRefined,
                warnings: warnings,
                approximateDiagnostics: approximateDiagnostics
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
                validClusters: sortedClusters(sortedConservativeClusters),
                outlierIndices: sortedConservativeOutliers,
                similarityMatrix: [],
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .approximateRefined,
                warnings: warnings,
                approximateDiagnostics: approximateDiagnostics
            )
        }

        return TopicClusteringResult(
            validClusters: sortedClusters(clustersWithSortedMembers(bestPartition.validClusters)),
            outlierIndices: bestPartition.outlierIndices.sorted(),
            similarityMatrix: [],
            silhouetteScore: bestPartition.silhouetteScore,
            strategy: .approximateRefined,
            warnings: warnings,
            approximateDiagnostics: approximateDiagnostics
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

            latestClusters = members.enumerated().compactMap { clusterIndex, memberIndices in
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

    func normalizedVectorMatrix(for vectors: [[Double]]) -> TopicNormalizedVectorMatrix? {
        guard let columnCount = vectors.first?.count, columnCount > 0 else { return nil }
        guard vectors.allSatisfy({ $0.count == columnCount }) else { return nil }

        var storage: [Double] = []
        storage.reserveCapacity(vectors.count * columnCount)
        for vector in vectors {
            storage.append(contentsOf: vector)
        }
        return TopicNormalizedVectorMatrix(
            rowCount: vectors.count,
            columnCount: columnCount,
            storage: storage
        )
    }

    func bestCentroidAssignments(
        for vectors: [[Double]],
        normalizedMatrix: TopicNormalizedVectorMatrix?,
        centroids: [[Double]]
    ) -> [(index: Int, similarity: Double)] {
        if let normalizedMatrix,
           let accelerated = acceleratedBestCentroidAssignments(
               matrix: normalizedMatrix,
               centroids: centroids
           ) {
            return accelerated
        }

        return vectors.map { vector in
            bestCentroidAssignment(for: vector, centroids: centroids)
        }
    }

    func acceleratedBestCentroidAssignments(
        matrix: TopicNormalizedVectorMatrix,
        centroids: [[Double]]
    ) -> [(index: Int, similarity: Double)]? {
        guard !centroids.isEmpty,
              centroids.allSatisfy({ $0.count == matrix.columnCount }) else {
            return nil
        }

        let clusterCount = centroids.count
        let centroidStorage = centroids.flatMap { $0 }
        var scores = Array(repeating: 0.0, count: matrix.rowCount * clusterCount)
        matrix.storage.withUnsafeBufferPointer { matrixPointer in
            centroidStorage.withUnsafeBufferPointer { centroidPointer in
                scores.withUnsafeMutableBufferPointer { scorePointer in
                    guard let matrixBaseAddress = matrixPointer.baseAddress,
                          let centroidBaseAddress = centroidPointer.baseAddress,
                          let scoreBaseAddress = scorePointer.baseAddress else {
                        return
                    }
                    cblas_dgemm(
                        CblasRowMajor,
                        CblasNoTrans,
                        CblasTrans,
                        Int32(matrix.rowCount),
                        Int32(clusterCount),
                        Int32(matrix.columnCount),
                        1.0,
                        matrixBaseAddress,
                        Int32(matrix.columnCount),
                        centroidBaseAddress,
                        Int32(matrix.columnCount),
                        0.0,
                        scoreBaseAddress,
                        Int32(clusterCount)
                    )
                }
            }
        }

        var assignments: [(index: Int, similarity: Double)] = []
        assignments.reserveCapacity(matrix.rowCount)
        for rowIndex in 0..<matrix.rowCount {
            let rowOffset = rowIndex * clusterCount
            var bestIndex = 0
            var bestSimilarity = -Double.infinity
            for clusterIndex in 0..<clusterCount {
                let similarity = scores[rowOffset + clusterIndex]
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestIndex = clusterIndex
                }
            }
            assignments.append((bestIndex, max(-1, min(1, bestSimilarity))))
        }
        return assignments
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
