import Foundation

private struct TopicSliceLexicalProfile {
    let tokenCounts: [String: Int]
    let keywordSet: Set<String>
    let bigramSet: Set<String>
    let semanticKeywordVector: [Double]?
}

private struct TopicClusteringLexicalContext {
    let profiles: [TopicSliceLexicalProfile]
    let keywordDocumentFrequency: [String: Int]
    let bigramDocumentFrequency: [String: Int]
    let sliceCount: Int
}

extension NativeTopicEngine {
    static let exactClusteringVectorLimit = 320
    private static let exactLexicalRefinementSliceLimit = 48
    private static let exactSmallCorpusClusterLimit = 6
    private static let exactSmallCorpusSeedVariants = 4
    private static let exactSmallCorpusIterationLimit = 18
    private static let approximateClusteringIterationLimit = 32
    private static let approximateClusteringClusterLimit = 12
    private static let approximateClusteringSeedVariants = 5
    private static let approximateOutlierSimilarityFloor = 0.18
    private static let approximateOutlierMedianOffset = 0.22

    func clusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> TopicClusteringResult {
        clusterVectors(
            vectors,
            slices: [],
            model: nil,
            minTopicSize: minTopicSize
        )
    }

    func clusterVectors(
        _ vectors: [[Double]],
        slices: [TopicTextSlice],
        model: TopicEmbeddingModel? = nil,
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

        let lexicalContext = makeLexicalContext(
            for: slices,
            model: model
        )
        let useLexicalRefinement = shouldUseExactLexicalRefinement(
            vectors: vectors,
            lexicalContext: lexicalContext
        )
        let similarityMatrix = pairwiseSimilarityMatrix(
            for: vectors,
            lexicalContext: useLexicalRefinement ? lexicalContext : nil
        )
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

        if useLexicalRefinement {
            partitions.append(
                contentsOf: exactRefinementPartitions(
                    vectors: vectors,
                    minTopicSize: minTopicSize
                )
            )
        }

        let partitionEvaluations = partitions.compactMap {
            evaluatePartition(
                $0,
                similarityMatrix: similarityMatrix,
                totalCount: vectors.count,
                minTopicSize: minTopicSize,
                lexicalContext: useLexicalRefinement ? lexicalContext : nil
            )
        }
        let selectionPolicy = TopicPartitionSelectionPolicy(vectorCount: vectors.count)

        let conservativePartition = conservativeFallbackPartition(
            vectors: vectors,
            similarityMatrix: similarityMatrix,
            minTopicSize: minTopicSize,
            lexicalContext: useLexicalRefinement ? lexicalContext : nil
        )

        guard !partitionEvaluations.isEmpty else {
            return TopicClusteringResult(
                validClusters: sortedClusters(conservativePartition.validClusters),
                outlierIndices: conservativePartition.outlierIndices.sorted(),
                similarityMatrix: similarityMatrix,
                silhouetteScore: conservativePartition.silhouetteScore,
                strategy: .exact,
                warnings: []
            )
        }

        let scoredBestPartition = partitionEvaluations.max(by: comparePartitions)!

        let refinedBestPartition = refineExactPartitionIfNeeded(
            scoredBestPartition,
            vectors: vectors,
            similarityMatrix: similarityMatrix,
            lexicalContext: useLexicalRefinement ? lexicalContext : nil,
            minTopicSize: minTopicSize
        )
        let selectedBestPartition = selectionPolicy.selectExactPartition(
            from: partitionEvaluations,
            refined: refinedBestPartition,
            useLexicalRefinement: useLexicalRefinement,
            compare: comparePartitions,
            conservative: conservativePartition
        )
        let usedConservativeFallback = selectedBestPartition.validClusters == conservativePartition.validClusters
            && selectedBestPartition.outlierIndices == conservativePartition.outlierIndices

        return TopicClusteringResult(
            validClusters: sortedClusters(selectedBestPartition.validClusters),
            outlierIndices: selectedBestPartition.outlierIndices.sorted(),
            similarityMatrix: similarityMatrix,
            silhouetteScore: selectedBestPartition.silhouetteScore,
            strategy: .exact,
            warnings: usedConservativeFallback ? [conservativeFallbackWarning()] : []
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

        let selectionPolicy = TopicPartitionSelectionPolicy(vectorCount: normalizedVectors.count)
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

    func pairwiseSimilarityMatrix(for vectors: [[Double]]) -> [[Double]] {
        pairwiseSimilarityMatrix(for: vectors, lexicalContext: nil)
    }

    fileprivate func pairwiseSimilarityMatrix(
        for vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> [[Double]] {
        guard !vectors.isEmpty else { return [] }

        var matrix = Array(
            repeating: Array(repeating: 0.0, count: vectors.count),
            count: vectors.count
        )
        for lhs in vectors.indices {
            matrix[lhs][lhs] = 1
            for rhs in (lhs + 1)..<vectors.count {
                let similarity: Double
                if let lexicalContext {
                    similarity = exactHybridSimilarity(
                        lhsIndex: lhs,
                        rhsIndex: rhs,
                        vectors: vectors,
                        lexicalContext: lexicalContext
                    )
                } else {
                    similarity = cosineSimilarity(vectors[lhs], vectors[rhs])
                }
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

    fileprivate func candidateExactClusterCounts(
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

    fileprivate func exactRefinementPartitions(
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

    fileprivate func rehydratedExactClusters(
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

    fileprivate func refineExactPartitionIfNeeded(
        _ partition: TopicPartitionEvaluation,
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?,
        minTopicSize: Int
    ) -> TopicPartitionEvaluation? {
        guard let lexicalContext, partition.validClusters.count > 1 else {
            return nil
        }

        var clusters = partition.validClusters
        var changed = false

        for _ in 0..<3 {
            var passChanged = false
            let orderedMembers = clusters.flatMap { $0.memberIndices }.sorted()
            for memberIndex in orderedMembers {
                let membership: [Int: Int] = Dictionary(
                    uniqueKeysWithValues: clusters.enumerated().flatMap { clusterIndex, cluster in
                        cluster.memberIndices.map { ($0, clusterIndex) }
                    }
                )
                guard let sourceClusterIndex = membership[memberIndex],
                      clusters[sourceClusterIndex].memberIndices.count > minTopicSize else {
                    continue
                }

                let currentScore = exactClusterMembershipScore(
                    memberIndex: memberIndex,
                    cluster: clusters[sourceClusterIndex],
                    vectors: vectors,
                    similarityMatrix: similarityMatrix,
                    lexicalContext: lexicalContext
                )

                var bestCandidateIndex = sourceClusterIndex
                var bestCandidateScore = currentScore
                for clusterIndex in clusters.indices where clusterIndex != sourceClusterIndex {
                    let candidateScore = exactClusterMembershipScore(
                        memberIndex: memberIndex,
                        cluster: clusters[clusterIndex],
                        vectors: vectors,
                        similarityMatrix: similarityMatrix,
                        lexicalContext: lexicalContext
                    )
                    if candidateScore > bestCandidateScore {
                        bestCandidateScore = candidateScore
                        bestCandidateIndex = clusterIndex
                    }
                }

                guard bestCandidateIndex != sourceClusterIndex,
                      bestCandidateScore > currentScore + 0.06 else {
                    continue
                }

                clusters[sourceClusterIndex].memberIndices.removeAll(where: { $0 == memberIndex })
                clusters[bestCandidateIndex].memberIndices.append(memberIndex)
                clusters[sourceClusterIndex].memberIndices.sort()
                clusters[bestCandidateIndex].memberIndices.sort()
                clusters[sourceClusterIndex].centroid = centroid(
                    for: clusters[sourceClusterIndex].memberIndices,
                    vectors: vectors
                )
                clusters[bestCandidateIndex].centroid = centroid(
                    for: clusters[bestCandidateIndex].memberIndices,
                    vectors: vectors
                )
                passChanged = true
                changed = true
            }

            if !passChanged {
                break
            }
        }

        let peeled = peelExactOutliers(
            clusters,
            vectors: vectors,
            similarityMatrix: similarityMatrix,
            lexicalContext: lexicalContext,
            minTopicSize: minTopicSize
        )

        let refinedOutliers = (partition.outlierIndices + peeled.outlierIndices).sorted()
        guard changed || !peeled.outlierIndices.isEmpty else { return nil }

        return evaluatePartition(
            peeled.clusters + refinedOutliers.map {
                ClusterState(memberIndices: [$0], centroid: vectors[$0])
            },
            similarityMatrix: similarityMatrix,
            totalCount: vectors.count,
            minTopicSize: minTopicSize,
            lexicalContext: lexicalContext
        )
    }

    fileprivate func exactClusterMembershipScore(
        memberIndex: Int,
        cluster: ClusterState,
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        lexicalContext: TopicClusteringLexicalContext
    ) -> Double {
        let memberProfile = lexicalContext.profiles[memberIndex]
        let otherMembers = cluster.memberIndices.filter { $0 != memberIndex }
        let withinClusterSimilarity = averageSimilarity(
            from: memberIndex,
            to: otherMembers,
            similarityMatrix: similarityMatrix
        )
        let centroidSimilarity = max(0, cosineSimilarity(vectors[memberIndex], cluster.centroid))

        let clusterKeywordSet = otherMembers.reduce(into: Set<String>()) { partialResult, member in
            partialResult.formUnion(lexicalContext.profiles[member].keywordSet)
        }
        let clusterBigramSet = otherMembers.reduce(into: Set<String>()) { partialResult, member in
            partialResult.formUnion(lexicalContext.profiles[member].bigramSet)
        }
        let keywordAffinity = weightedSetSimilarity(
            memberProfile.keywordSet,
            clusterKeywordSet,
            documentFrequency: lexicalContext.keywordDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )
        let bigramAffinity = weightedSetSimilarity(
            memberProfile.bigramSet,
            clusterBigramSet,
            documentFrequency: lexicalContext.bigramDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )

        return (centroidSimilarity * 0.42)
            + (withinClusterSimilarity * 0.38)
            + (keywordAffinity * 0.16)
            + (bigramAffinity * 0.04)
    }

    fileprivate func peelExactOutliers(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        lexicalContext: TopicClusteringLexicalContext,
        minTopicSize: Int
    ) -> (clusters: [ClusterState], outlierIndices: [Int]) {
        var refinedClusters: [ClusterState] = []
        var outlierIndices: [Int] = []

        for cluster in clusters {
            guard cluster.memberIndices.count > minTopicSize else {
                refinedClusters.append(cluster)
                continue
            }

            let rankedMembers = cluster.memberIndices.sorted { lhs, rhs in
                let lhsScore = averageSimilarity(
                    from: lhs,
                    to: cluster.memberIndices.filter { $0 != lhs },
                    similarityMatrix: similarityMatrix
                )
                let rhsScore = averageSimilarity(
                    from: rhs,
                    to: cluster.memberIndices.filter { $0 != rhs },
                    similarityMatrix: similarityMatrix
                )
                if lhsScore == rhsScore {
                    return lhs < rhs
                }
                return lhsScore > rhsScore
            }
            let coreMembers = Array(rankedMembers.prefix(minTopicSize))
            let coreBaseline = coreMembers.isEmpty
                ? 0
                : coreMembers.reduce(0.0) { partialResult, memberIndex in
                    partialResult + averageSimilarity(
                        from: memberIndex,
                        to: coreMembers.filter { $0 != memberIndex },
                        similarityMatrix: similarityMatrix
                    )
                } / Double(coreMembers.count)
            let threshold = max(0.26, coreBaseline - 0.08)

            let peeledMembers = cluster.memberIndices.filter { memberIndex in
                guard !coreMembers.contains(memberIndex) else { return false }
                let affinityToCore = averageSimilarity(
                    from: memberIndex,
                    to: coreMembers,
                    similarityMatrix: similarityMatrix
                )
                let membershipScore = exactClusterMembershipScore(
                    memberIndex: memberIndex,
                    cluster: cluster,
                    vectors: vectors,
                    similarityMatrix: similarityMatrix,
                    lexicalContext: lexicalContext
                )
                return affinityToCore < threshold && membershipScore < 0.62
            }
            let keptMembers = cluster.memberIndices
                .filter { !peeledMembers.contains($0) }
                .sorted()

            guard !peeledMembers.isEmpty, keptMembers.count >= minTopicSize else {
                refinedClusters.append(cluster)
                continue
            }

            refinedClusters.append(
                ClusterState(
                    memberIndices: keptMembers,
                    centroid: centroid(for: keptMembers, vectors: vectors)
                )
            )
            outlierIndices.append(contentsOf: peeledMembers)
        }

        return (refinedClusters, outlierIndices.sorted())
    }

    fileprivate func exactMedoidPartition(
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

    fileprivate func seedExactMedoids(
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

    fileprivate func averageSimilarityToAll(
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

    fileprivate func nearestMedoidDistance(
        memberIndex: Int,
        medoids: [Int],
        similarityMatrix: [[Double]]
    ) -> Double {
        let bestSimilarity = medoids.map { similarityMatrix[memberIndex][$0] }.max() ?? 0
        return 1 - bestSimilarity
    }

    fileprivate func bestMedoidAssignment(
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

    fileprivate func stabilizeExactMembers(
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

    fileprivate func bestMedoid(
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
        minTopicSize: Int,
        lexicalContext: TopicClusteringLexicalContext? = nil
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
        let lexicalContrast = lexicalClusterContrastScore(
            validClusters,
            lexicalContext: lexicalContext
        )
        let lexicalCohesion = lexicalWithinClusterCohesion(
            validClusters,
            lexicalContext: lexicalContext
        )
        let smallCorpusPurityBonus = lexicalContext.map { $0.sliceCount <= 12 ? 1.0 : 0.0 } ?? 0

        if validClusters.count < 2 {
            let score = averageWithin
                + coverageBonus
                + (lexicalContrast * 0.14)
                + (lexicalCohesion * (0.12 + (0.12 * smallCorpusPurityBonus)))
                - outlierPenalty
                - 0.1
            return TopicPartitionEvaluation(
                validClusters: validClusters,
                outlierIndices: outlierIndices,
                silhouetteScore: 0,
                averageWithinClusterSimilarity: averageWithin,
                clusteredCoverage: clusteredCoverage,
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
            + (lexicalContrast * 0.18)
            + (lexicalCohesion * (0.16 + (0.16 * smallCorpusPurityBonus)))
            - outlierPenalty
        return TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: silhouette,
            averageWithinClusterSimilarity: averageWithin,
            clusteredCoverage: clusteredCoverage,
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
                clusteredCoverage: clusteredCoverage,
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
            clusteredCoverage: clusteredCoverage,
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

    fileprivate func averageSimilarity(
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

    fileprivate func conservativeFallbackPartition(
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        minTopicSize: Int,
        lexicalContext: TopicClusteringLexicalContext? = nil
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
            minTopicSize: minTopicSize,
            lexicalContext: lexicalContext
        ) ?? TopicPartitionEvaluation(
            validClusters: validClusters,
            outlierIndices: outlierIndices,
            silhouetteScore: 0,
            averageWithinClusterSimilarity: averageSimilarity(
                within: clusterMembers,
                similarityMatrix: similarityMatrix
            ),
            clusteredCoverage: vectors.isEmpty ? 0 : Double(clusterMembers.count) / Double(vectors.count),
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
            clusteredCoverage: vectors.isEmpty ? 0 : Double(clusterMembers.count) / Double(vectors.count),
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

    fileprivate func shouldUseExactLexicalRefinement(
        vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Bool {
        guard let lexicalContext else { return false }
        return lexicalContext.sliceCount == vectors.count
            && vectors.count <= Self.exactLexicalRefinementSliceLimit
    }

    fileprivate func makeLexicalContext(
        for slices: [TopicTextSlice],
        model: TopicEmbeddingModel?
    ) -> TopicClusteringLexicalContext? {
        guard !slices.isEmpty else { return nil }

        let profiles = slices.map { slice in
            TopicSliceLexicalProfile(
                tokenCounts: Dictionary(
                    grouping: slice.tokens.map(canonicalKeyword),
                    by: { $0 }
                )
                .mapValues(\.count),
                keywordSet: Set(candidateTerms(for: slice).map(canonicalKeyword)),
                bigramSet: Set(slice.keywordBigrams.map(canonicalKeyword)),
                semanticKeywordVector: makeSemanticKeywordVector(
                    for: slice,
                    model: model
                )
            )
        }

        var keywordDocumentFrequency: [String: Int] = [:]
        var bigramDocumentFrequency: [String: Int] = [:]
        for profile in profiles {
            for term in profile.keywordSet {
                keywordDocumentFrequency[term, default: 0] += 1
            }
            for bigram in profile.bigramSet {
                bigramDocumentFrequency[bigram, default: 0] += 1
            }
        }

        return TopicClusteringLexicalContext(
            profiles: profiles,
            keywordDocumentFrequency: keywordDocumentFrequency,
            bigramDocumentFrequency: bigramDocumentFrequency,
            sliceCount: slices.count
        )
    }

    fileprivate func exactHybridSimilarity(
        lhsIndex: Int,
        rhsIndex: Int,
        vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext
    ) -> Double {
        let embeddingSimilarity = max(0, cosineSimilarity(vectors[lhsIndex], vectors[rhsIndex]))
        let lhsProfile = lexicalContext.profiles[lhsIndex]
        let rhsProfile = lexicalContext.profiles[rhsIndex]
        let keywordOverlap = weightedSetSimilarity(
            lhsProfile.keywordSet,
            rhsProfile.keywordSet,
            documentFrequency: lexicalContext.keywordDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )
        let bigramOverlap = weightedSetSimilarity(
            lhsProfile.bigramSet,
            rhsProfile.bigramSet,
            documentFrequency: lexicalContext.bigramDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )
        let semanticKeywordSimilarity = semanticKeywordSimilarity(
            lhsProfile.semanticKeywordVector,
            rhsProfile.semanticKeywordVector
        )
        let tokenOverlap = weightedTokenCosineSimilarity(
            lhsProfile.tokenCounts,
            rhsProfile.tokenCounts,
            keywordDocumentFrequency: lexicalContext.keywordDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )

        let semanticSupport = max(
            semanticKeywordSimilarity,
            max(keywordOverlap, max(tokenOverlap * 0.85, bigramOverlap))
        )
        let embeddingCarry = embeddingSimilarity * max(0.18, semanticSupport)
        let blended = (semanticKeywordSimilarity * 0.42)
            + (embeddingCarry * 0.28)
            + (keywordOverlap * 0.18)
            + (tokenOverlap * 0.08)
            + (bigramOverlap * 0.04)

        return max(0, min(1, blended))
    }

    fileprivate func weightedSetSimilarity(
        _ lhs: Set<String>,
        _ rhs: Set<String>,
        documentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }

        let weightedIntersection = lhs.intersection(rhs).reduce(0.0) { partialResult, term in
            partialResult + lexicalIDF(
                for: term,
                documentFrequency: documentFrequency,
                totalDocuments: totalDocuments
            )
        }
        let weightedUnion = union.reduce(0.0) { partialResult, term in
            partialResult + lexicalIDF(
                for: term,
                documentFrequency: documentFrequency,
                totalDocuments: totalDocuments
            )
        }
        guard weightedUnion > 0 else { return 0 }
        return weightedIntersection / weightedUnion
    }

    fileprivate func weightedTokenCosineSimilarity(
        _ lhsCounts: [String: Int],
        _ rhsCounts: [String: Int],
        keywordDocumentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        guard !lhsCounts.isEmpty, !rhsCounts.isEmpty else { return 0 }

        let sharedTerms = Set(lhsCounts.keys).intersection(rhsCounts.keys)
        let numerator = sharedTerms.reduce(0.0) { partialResult, term in
            let weight = lexicalIDF(
                for: term,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double((lhsCounts[term] ?? 0) * (rhsCounts[term] ?? 0)) * weight
        }

        let lhsMagnitude = sqrt(lhsCounts.reduce(0.0) { partialResult, entry in
            let weight = lexicalIDF(
                for: entry.key,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double(entry.value * entry.value) * weight
        })
        let rhsMagnitude = sqrt(rhsCounts.reduce(0.0) { partialResult, entry in
            let weight = lexicalIDF(
                for: entry.key,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double(entry.value * entry.value) * weight
        })

        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return numerator / (lhsMagnitude * rhsMagnitude)
    }

    fileprivate func lexicalIDF(
        for term: String,
        documentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        let df = Double(max(1, documentFrequency[term] ?? 1))
        return log(1 + (Double(max(1, totalDocuments)) / df))
    }

    fileprivate func makeSemanticKeywordVector(
        for slice: TopicTextSlice,
        model: TopicEmbeddingModel?
    ) -> [Double]? {
        guard let model else { return nil }
        let terms = Array(
            Set((slice.keywordTerms.isEmpty ? slice.tokens : slice.keywordTerms).map(canonicalKeyword))
        )
        .sorted()
        .prefix(8)

        var vectors: [[Double]] = []
        vectors.reserveCapacity(terms.count)
        for term in terms {
            guard let vector = model.vector(
                for: TopicEmbeddingInput(
                    text: term,
                    tokens: [term],
                    keywordTerms: [term],
                    keywordBigrams: []
                )
            ) else {
                continue
            }
            vectors.append(normalize(vector))
        }

        guard let first = vectors.first else { return nil }
        var aggregate = Array(repeating: 0.0, count: first.count)
        for vector in vectors {
            for index in aggregate.indices where vector.indices.contains(index) {
                aggregate[index] += vector[index]
            }
        }
        let count = Double(max(1, vectors.count))
        return normalize(aggregate.map { $0 / count })
    }

    fileprivate func semanticKeywordSimilarity(
        _ lhs: [Double]?,
        _ rhs: [Double]?
    ) -> Double {
        guard let lhs, let rhs else { return 0 }
        return max(0, cosineSimilarity(lhs, rhs))
    }

    fileprivate func lexicalClusterContrastScore(
        _ clusters: [ClusterState],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Double {
        guard let lexicalContext, clusters.count > 1 else { return 0 }

        let allIndices = Set(0..<lexicalContext.sliceCount)
        let clusterScores = clusters.map { cluster -> Double in
            let clusterIndexSet = Set(cluster.memberIndices)
            let restIndices = allIndices.subtracting(clusterIndexSet)

            let insidePresence = keywordPresence(
                for: cluster.memberIndices,
                lexicalContext: lexicalContext
            )
            let outsidePresence = keywordPresence(
                for: Array(restIndices),
                lexicalContext: lexicalContext
            )

            let insideCount = Double(max(1, cluster.memberIndices.count))
            let outsideCount = Double(max(1, restIndices.count))
            let distinctiveness = insidePresence.compactMap { term, presenceCount -> Double? in
                let insideShare = Double(presenceCount) / insideCount
                let outsideShare = Double(outsidePresence[term] ?? 0) / outsideCount
                let contrast = insideShare - outsideShare
                let globalShare = Double(lexicalContext.keywordDocumentFrequency[term] ?? 0)
                    / Double(max(1, lexicalContext.sliceCount))
                guard insideShare >= 0.34, contrast > 0.12, globalShare < 0.8 else {
                    return nil
                }
                let rarity = max(0.18, 1 - globalShare)
                return contrast * rarity
            }
            .sorted(by: >)

            let topSignals = distinctiveness.prefix(3)
            guard !topSignals.isEmpty else { return 0 }
            return topSignals.reduce(0, +) / Double(topSignals.count)
        }

        guard !clusterScores.isEmpty else { return 0 }
        return clusterScores.reduce(0, +) / Double(clusterScores.count)
    }

    fileprivate func lexicalWithinClusterCohesion(
        _ clusters: [ClusterState],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Double {
        guard let lexicalContext else { return 0 }

        let clusterScores = clusters.map { cluster -> Double in
            guard cluster.memberIndices.count > 1 else { return 1 }

            var total = 0.0
            var pairs = 0
            for lhsOffset in 0..<cluster.memberIndices.count {
                for rhsOffset in (lhsOffset + 1)..<cluster.memberIndices.count {
                    let lhsProfile = lexicalContext.profiles[cluster.memberIndices[lhsOffset]]
                    let rhsProfile = lexicalContext.profiles[cluster.memberIndices[rhsOffset]]
                    let keywordOverlap = weightedSetSimilarity(
                        lhsProfile.keywordSet,
                        rhsProfile.keywordSet,
                        documentFrequency: lexicalContext.keywordDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let bigramOverlap = weightedSetSimilarity(
                        lhsProfile.bigramSet,
                        rhsProfile.bigramSet,
                        documentFrequency: lexicalContext.bigramDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let tokenOverlap = weightedTokenCosineSimilarity(
                        lhsProfile.tokenCounts,
                        rhsProfile.tokenCounts,
                        keywordDocumentFrequency: lexicalContext.keywordDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let semanticSimilarity = semanticKeywordSimilarity(
                        lhsProfile.semanticKeywordVector,
                        rhsProfile.semanticKeywordVector
                    )
                    total += (semanticSimilarity * 0.55)
                        + (keywordOverlap * 0.22)
                        + (tokenOverlap * 0.18)
                        + (bigramOverlap * 0.05)
                    pairs += 1
                }
            }
            return pairs == 0 ? 1 : total / Double(pairs)
        }

        guard !clusterScores.isEmpty else { return 0 }
        return clusterScores.reduce(0, +) / Double(clusterScores.count)
    }

    fileprivate func keywordPresence(
        for memberIndices: [Int],
        lexicalContext: TopicClusteringLexicalContext
    ) -> [String: Int] {
        var presence: [String: Int] = [:]
        for memberIndex in memberIndices where lexicalContext.profiles.indices.contains(memberIndex) {
            for term in lexicalContext.profiles[memberIndex].keywordSet {
                presence[term, default: 0] += 1
            }
        }
        return presence
    }
}
