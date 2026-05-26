import Foundation

extension NativeTopicEngine {
    func evaluatePartition(
        _ clusters: [ClusterState],
        similarityMatrix: [[Double]],
        totalCount: Int,
        minTopicSize: Int,
        lexicalContext: TopicClusteringLexicalContext? = nil,
        scoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicPartitionEvaluation? {
        guard !clusters.isEmpty else { return nil }

        let validClusters = clusters.filter { $0.memberIndices.count >= minTopicSize }
        let outlierIndices = clusters
            .filter { $0.memberIndices.count < minTopicSize }
            .flatMap(\.memberIndices)
            .sorted()
        guard !validClusters.isEmpty else { return nil }

        let outlierRatio = totalCount == 0
            ? 0
            : Double(outlierIndices.count) / Double(totalCount)
        let outlierPenalty = outlierRatio * scoringProfile.outlierPenaltyWeight
        let clusteredCoverage = totalCount == 0
            ? 0
            : Double(validClusters.reduce(0) { $0 + $1.memberIndices.count }) / Double(totalCount)
        let coverageBonus = clusteredCoverage * scoringProfile.coverageBonusWeight
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
                + (lexicalContrast * scoringProfile.singleClusterLexicalContrastWeight)
                + (lexicalCohesion * scoringProfile.singleClusterLexicalCohesionWeight(smallCorpusPurityBonus))
                - outlierPenalty
                - scoringProfile.singleClusterPenalty
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
            + min(scoringProfile.clusterCountBonusCap, Double(validClusters.count - 2) * scoringProfile.clusterCountBonusStep)
            + (averageWithin * scoringProfile.averageWithinBonusWeight)
            + coverageBonus
            + (lexicalContrast * scoringProfile.multiClusterLexicalContrastWeight)
            + (lexicalCohesion * scoringProfile.multiClusterLexicalCohesionWeight(smallCorpusPurityBonus))
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

    func evaluateApproximatePartition(
        _ clusters: [ClusterState],
        vectors: [[Double]],
        totalCount: Int,
        minTopicSize: Int,
        scoringProfile: TopicPartitionScoringProfile = .balanced
    ) -> TopicPartitionEvaluation? {
        guard !clusters.isEmpty else { return nil }

        let validClusters = clusters.filter { $0.memberIndices.count >= minTopicSize }
        let outlierIndices = clusters
            .filter { $0.memberIndices.count < minTopicSize }
            .flatMap(\.memberIndices)
            .sorted()
        guard !validClusters.isEmpty else { return nil }

        let outlierRatio = totalCount == 0
            ? 0
            : Double(outlierIndices.count) / Double(totalCount)
        let outlierPenalty = outlierRatio * scoringProfile.outlierPenaltyWeight
        let clusteredCoverage = totalCount == 0
            ? 0
            : Double(validClusters.reduce(0) { $0 + $1.memberIndices.count }) / Double(totalCount)
        let coverageBonus = clusteredCoverage * scoringProfile.coverageBonusWeight
        let averageWithin = approximateAverageWithinClusterSimilarity(
            validClusters,
            vectors: vectors
        )

        if validClusters.count < 2 {
            let score = averageWithin + coverageBonus - outlierPenalty - scoringProfile.approximateSingleClusterPenalty
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
        let score = (averageWithin * scoringProfile.approximateAverageWithinWeight)
            + (separation * scoringProfile.approximateSeparationWeight)
            + min(scoringProfile.approximateClusterCountBonusCap, Double(validClusters.count - 1) * scoringProfile.approximateClusterCountBonusStep)
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

    func comparePartitions(_ lhs: TopicPartitionEvaluation, _ rhs: TopicPartitionEvaluation) -> Bool {
        if lhs.score == rhs.score {
            if lhs.validClusters.count == rhs.validClusters.count {
                return lhs.outlierIndices.count > rhs.outlierIndices.count
            }
            return lhs.validClusters.count < rhs.validClusters.count
        }
        return lhs.score < rhs.score
    }


    func conservativeFallbackPartition(
        vectors: [[Double]],
        similarityMatrix: [[Double]],
        minTopicSize: Int,
        lexicalContext: TopicClusteringLexicalContext? = nil,
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
        return evaluatePartition(
            validClusters + outlierIndices.map {
                ClusterState(memberIndices: [$0], centroid: vectors[$0])
            },
            similarityMatrix: similarityMatrix,
            totalCount: vectors.count,
            minTopicSize: minTopicSize,
            lexicalContext: lexicalContext,
            scoringProfile: scoringProfile
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
}
