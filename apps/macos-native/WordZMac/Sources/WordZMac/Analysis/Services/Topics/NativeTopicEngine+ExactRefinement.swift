import Foundation

extension NativeTopicEngine {
    func refineExactPartitionIfNeeded(
        _ partition: TopicPartitionEvaluation,
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?,
        minTopicSize: Int,
        scoringProfile: TopicPartitionScoringProfile = .balanced
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
            lexicalContext: lexicalContext,
            scoringProfile: scoringProfile
        )
    }

    func exactClusterMembershipScore(
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

    func peelExactOutliers(
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
}
