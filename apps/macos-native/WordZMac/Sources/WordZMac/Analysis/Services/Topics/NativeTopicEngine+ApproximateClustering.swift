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
}
