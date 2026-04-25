import Foundation

struct TopicPartitionEvaluation {
    let validClusters: [ClusterState]
    let outlierIndices: [Int]
    let silhouetteScore: Double
    let averageWithinClusterSimilarity: Double
    let clusteredCoverage: Double
    let score: Double
}

struct TopicPartitionSelectionPolicy {
    let vectorCount: Int

    private let smallCorpusVectorLimit = 12
    private let smallCorpusMultiClusterScoreTolerance = 0.05
    private let smallCorpusCoverageFloor = 0.6
    private let protectedCoverageFloor = 0.75
    private let protectedWithinClusterFloor = 0.16
    private let protectedSilhouetteFloor = 0.01
    private let exactConservativeScoreTolerance = 0.03
    private let approximateConservativeScoreTolerance = 0.02
    private let exactLowQualitySilhouetteThreshold = 0.08
    private let exactLowQualityWithinClusterThreshold = 0.22
    private let approximateLowQualitySilhouetteThreshold = 0.12
    private let approximateLowQualityWithinClusterThreshold = 0.26

    func selectExactPartition(
        from evaluations: [TopicPartitionEvaluation],
        refined refinedCandidate: TopicPartitionEvaluation?,
        useLexicalRefinement: Bool,
        compare: (TopicPartitionEvaluation, TopicPartitionEvaluation) -> Bool,
        conservative conservativePartition: TopicPartitionEvaluation
    ) -> TopicPartitionEvaluation {
        guard let scoredBestPartition = evaluations.max(by: compare) else {
            return conservativePartition
        }

        let preferredScoredPartition = preferredSmallCorpusExactPartition(
            from: evaluations,
            fallback: scoredBestPartition,
            compare: compare
        ) ?? scoredBestPartition

        let selectedPartition = selectRefinedExactPartition(
            base: preferredScoredPartition,
            refined: refinedCandidate,
            useLexicalRefinement: useLexicalRefinement,
            compare: compare
        )

        guard shouldPreferConservativeFallback(
            for: selectedPartition,
            conservative: conservativePartition,
            scoreTolerance: exactConservativeScoreTolerance,
            silhouetteThreshold: exactLowQualitySilhouetteThreshold,
            withinClusterThreshold: exactLowQualityWithinClusterThreshold
        ) else {
            return selectedPartition
        }

        return conservativePartition
    }

    func shouldPreferApproximateConservativeFallback(
        current partition: TopicPartitionEvaluation,
        conservative conservativePartition: TopicPartitionEvaluation
    ) -> Bool {
        shouldPreferConservativeFallback(
            for: partition,
            conservative: conservativePartition,
            scoreTolerance: approximateConservativeScoreTolerance,
            silhouetteThreshold: approximateLowQualitySilhouetteThreshold,
            withinClusterThreshold: approximateLowQualityWithinClusterThreshold
        )
    }

    private func preferredSmallCorpusExactPartition(
        from evaluations: [TopicPartitionEvaluation],
        fallback fallbackPartition: TopicPartitionEvaluation,
        compare: (TopicPartitionEvaluation, TopicPartitionEvaluation) -> Bool
    ) -> TopicPartitionEvaluation? {
        guard vectorCount <= smallCorpusVectorLimit else {
            return nil
        }

        let candidatePartitions = evaluations.filter { partition in
            guard partition.validClusters.count >= max(3, fallbackPartition.validClusters.count) else {
                return false
            }

            guard partition.clusteredCoverage >= smallCorpusCoverageFloor else {
                return false
            }

            guard partition.score >= fallbackPartition.score - smallCorpusMultiClusterScoreTolerance else {
                return false
            }

            return partition.silhouetteScore >= protectedSilhouetteFloor
                || partition.averageWithinClusterSimilarity >= protectedWithinClusterFloor
        }

        return candidatePartitions.max(by: compare)
    }

    private func selectRefinedExactPartition(
        base basePartition: TopicPartitionEvaluation,
        refined refinedCandidate: TopicPartitionEvaluation?,
        useLexicalRefinement: Bool,
        compare: (TopicPartitionEvaluation, TopicPartitionEvaluation) -> Bool
    ) -> TopicPartitionEvaluation {
        guard let refinedCandidate else {
            return basePartition
        }

        if vectorCount <= smallCorpusVectorLimit {
            if refinedCandidate.validClusters.count < basePartition.validClusters.count,
               refinedCandidate.score < basePartition.score + 0.04 {
                return basePartition
            }

            if refinedCandidate.validClusters.count > basePartition.validClusters.count,
               refinedCandidate.clusteredCoverage >= smallCorpusCoverageFloor,
               refinedCandidate.score >= basePartition.score - 0.04 {
                return refinedCandidate
            }
        }

        let prefersPrecisionRefinement = useLexicalRefinement && vectorCount <= smallCorpusVectorLimit
        let refinedOutlierBudget = max(3, vectorCount / 4)
        if prefersPrecisionRefinement,
           refinedCandidate.validClusters.count >= basePartition.validClusters.count,
           refinedCandidate.outlierIndices.count <= refinedOutlierBudget {
            return refinedCandidate
        }

        if refinedCandidate.score >= basePartition.score - 0.02,
           refinedCandidate.validClusters.count >= basePartition.validClusters.count {
            return refinedCandidate
        }

        return compare(basePartition, refinedCandidate) ? refinedCandidate : basePartition
    }

    private func shouldPreferConservativeFallback(
        for partition: TopicPartitionEvaluation,
        conservative conservativePartition: TopicPartitionEvaluation,
        scoreTolerance: Double,
        silhouetteThreshold: Double,
        withinClusterThreshold: Double
    ) -> Bool {
        let lowQuality = partition.validClusters.count > 1
            ? partition.silhouetteScore < silhouetteThreshold
            : partition.averageWithinClusterSimilarity < withinClusterThreshold

        guard lowQuality else {
            return false
        }

        if vectorCount <= smallCorpusVectorLimit,
           partition.validClusters.count >= 3,
           partition.clusteredCoverage >= protectedCoverageFloor,
           (partition.silhouetteScore >= protectedSilhouetteFloor
               || partition.averageWithinClusterSimilarity >= protectedWithinClusterFloor) {
            return false
        }

        return conservativePartition.score >= partition.score - scoreTolerance
    }
}
