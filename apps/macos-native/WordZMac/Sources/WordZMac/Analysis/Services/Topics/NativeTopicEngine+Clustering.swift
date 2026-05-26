import Foundation

extension NativeTopicEngine {
    func clusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> TopicClusteringResult {
        clusterVectors(
            vectors,
            slices: [],
            model: nil,
            minTopicSize: minTopicSize,
            partitionScoringProfile: .balanced
        )
    }

    func clusterVectors(
        _ vectors: [[Double]],
        slices: [TopicTextSlice],
        model: TopicEmbeddingModel? = nil,
        minTopicSize: Int,
        partitionScoringProfile: TopicPartitionScoringProfile = .balanced
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
                minTopicSize: minTopicSize,
                partitionScoringProfile: partitionScoringProfile
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
                lexicalContext: useLexicalRefinement ? lexicalContext : nil,
                scoringProfile: partitionScoringProfile
            )
        }
        let selectionPolicy = TopicPartitionSelectionPolicy(
            vectorCount: vectors.count,
            scoringProfile: partitionScoringProfile
        )

        let conservativePartition = conservativeFallbackPartition(
            vectors: vectors,
            similarityMatrix: similarityMatrix,
            minTopicSize: minTopicSize,
            lexicalContext: useLexicalRefinement ? lexicalContext : nil,
            scoringProfile: partitionScoringProfile
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
            minTopicSize: minTopicSize,
            scoringProfile: partitionScoringProfile
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
}
