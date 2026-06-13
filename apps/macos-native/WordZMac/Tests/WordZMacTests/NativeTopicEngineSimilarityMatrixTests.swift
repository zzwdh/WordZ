import XCTest
@testable import WordZWorkspaceCore

final class NativeTopicEngineSimilarityMatrixTests: XCTestCase {
    func testAcceleratedSimilarityMatrixMatchesScalarPairwiseCosine() async throws {
        let engine = NativeTopicEngine(runtimeTuning: makeTuning(matrixMinVectors: 2))
        let vectors = [
            [3.0, 4.0, 0.0, 0.0],
            [6.0, 8.0, 0.0, 0.0],
            [0.0, 5.0, 12.0, 0.0],
            [-3.0, 0.0, 4.0, 1.0],
            [0.5, 1.5, -2.0, 3.0]
        ]

        let acceleratedOptional = await engine.acceleratedSimilarityMatrix(for: vectors)
        let accelerated = try XCTUnwrap(acceleratedOptional)
        let scalar = await engine.scalarPairwiseSimilarityMatrix(
            for: vectors,
            lexicalContext: nil
        )

        assertEqualMatrix(accelerated, scalar, accuracy: 1e-12)
    }

    func testPairwiseSimilarityMatrixUsesAcceleratedPathAboveThreshold() async {
        let engine = NativeTopicEngine(runtimeTuning: makeTuning(matrixMinVectors: 2))
        let vectors = [
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [1.0, 1.0, 0.0]
        ]

        let matrix = await engine.pairwiseSimilarityMatrix(for: vectors)
        let accelerated = await engine.acceleratedSimilarityMatrix(for: vectors)

        assertEqualMatrix(matrix, accelerated ?? [], accuracy: 1e-12)
    }

    func testPairwiseSimilarityMatrixKeepsLexicalHybridOnScalarPath() async {
        let engine = NativeTopicEngine(runtimeTuning: makeTuning(matrixMinVectors: 2))
        let vectors = [
            [1.0, 0.0],
            [1.0, 0.0]
        ]
        let lexicalContext = TopicClusteringLexicalContext(
            profiles: [
                TopicSliceLexicalProfile(
                    tokenCounts: ["policy": 1],
                    keywordSet: ["policy"],
                    bigramSet: [],
                    semanticKeywordVector: nil
                ),
                TopicSliceLexicalProfile(
                    tokenCounts: ["weather": 1],
                    keywordSet: ["weather"],
                    bigramSet: [],
                    semanticKeywordVector: nil
                )
            ],
            keywordDocumentFrequency: [
                "policy": 1,
                "weather": 1
            ],
            bigramDocumentFrequency: [:],
            sliceCount: 2
        )

        let matrix = await engine.pairwiseSimilarityMatrix(
            for: vectors,
            lexicalContext: lexicalContext
        )
        let hybrid = await engine.exactHybridSimilarity(
            lhsIndex: 0,
            rhsIndex: 1,
            vectors: vectors,
            lexicalContext: lexicalContext
        )

        XCTAssertEqual(matrix[0][1], hybrid, accuracy: 1e-12)
        XCTAssertLessThan(matrix[0][1], 0.5)
    }

    func testAcceleratedSimilarityMatrixFallsBackForMismatchedDimensions() async {
        let engine = NativeTopicEngine(runtimeTuning: makeTuning(matrixMinVectors: 2))

        let accelerated = await engine.acceleratedSimilarityMatrix(
            for: [
                [1.0, 0.0],
                [1.0, 0.0, 0.0]
            ]
        )
        let matrix = await engine.pairwiseSimilarityMatrix(
            for: [
                [1.0, 0.0],
                [1.0, 0.0, 0.0]
            ]
        )

        XCTAssertNil(accelerated)
        XCTAssertEqual(matrix[0][1], 0)
    }

    private func makeTuning(matrixMinVectors: Int) -> NativeAnalysisRuntimeTuning {
        NativeAnalysisRuntimeTuning(
            topicExactClusteringVectorLimit: 320,
            topicApproximateClusteringIterationLimit: 32,
            topicApproximateClusteringClusterLimit: 12,
            topicApproximateClusteringSeedVariants: 5,
            topicApproximateClusteringLargeCorpusVectorThreshold: 5_000,
            topicApproximateClusteringCoarseCandidateCounts: [2, 4, 6, 8, 10, 12],
            topicApproximateClusteringCoarseIterationLimit: 8,
            topicApproximateClusteringRefineCandidateLimit: 3,
            topicSimilarityMatrixMultiplicationMinVectors: matrixMinVectors,
            topicEmbeddingBatchSize: 320,
            topicEmbeddingCacheEntries: 2_048,
            topicReductionCacheEntries: 32,
            shouldConserveResources: false,
            hardwareSummary: "test"
        )
    }

    private func assertEqualMatrix(
        _ lhs: [[Double]],
        _ rhs: [[Double]],
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.count, rhs.count, file: file, line: line)
        for rowIndex in lhs.indices {
            XCTAssertEqual(lhs[rowIndex].count, rhs[rowIndex].count, file: file, line: line)
            for columnIndex in lhs[rowIndex].indices {
                XCTAssertEqual(
                    lhs[rowIndex][columnIndex],
                    rhs[rowIndex][columnIndex],
                    accuracy: accuracy,
                    file: file,
                    line: line
                )
            }
        }
    }
}
