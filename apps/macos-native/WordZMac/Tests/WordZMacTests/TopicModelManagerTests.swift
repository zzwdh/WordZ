import XCTest
@testable import WordZWorkspaceCore

final class TopicModelManagerTests: XCTestCase {
    func testFallbackManifestDefaultsToBundledLocalV3() {
        XCTAssertEqual(TopicModelManifest.fallback.version, "3")
        XCTAssertEqual(TopicModelManifest.fallback.dimensions, 384)
        XCTAssertEqual(TopicModelManifest.fallback.revision, "2026-04-local-v3")
        XCTAssertEqual(TopicModelManifest.fallback.providers?.first?.dimensions, 384)
    }

    func testHashedFallbackVectorIsStableAndDeterministic() throws {
        let vector = try XCTUnwrap(
            TopicModelManager.hashedFallbackVector(for: "alpha beta alpha", dimensions: 8)
        )

        XCTAssertEqual(vector.count, 32)
        XCTAssertEqual(vector[13], 2, accuracy: 0.0001)
        XCTAssertEqual(vector[7], -1, accuracy: 0.0001)
        XCTAssertEqual(vector.filter { $0 != 0 }.count, 2)
    }

    func testLoadModelReturnsInvalidManifestForMalformedJSON() {
        let manager = TopicModelManager(
            manifestProvider: {
                Data("{\"modelID\":true}".utf8)
            },
            systemEmbeddingProvider: { nil }
        )

        XCTAssertThrowsError(try manager.loadModel()) { error in
            guard case TopicAnalysisError.invalidModelManifest = error else {
                return XCTFail("Expected invalidModelManifest, received \(error)")
            }
        }
    }

    func testLoadModelPrefersBundledLocalEmbeddingProvider() throws {
        let manager = TopicModelManager(
            manifestProvider: {
                Data(
                    """
                    {
                      "modelID": "wordz-topics-english",
                      "version": "2",
                      "language": "english",
                      "provider": "bundled-lexical-embedding",
                      "dimensions": 256,
                      "providers": [
                        {
                          "id": "bundled-lexical-embedding",
                          "type": "bundled-lexical-embedding",
                          "dimensions": 256,
                          "revision": "local-test"
                        },
                        {
                          "id": "hashed-fallback",
                          "type": "hashed-fallback",
                          "dimensions": 256,
                          "revision": "hash-test"
                        }
                      ],
                      "localEmbeddingResource": "TopicLocalEmbeddingModel"
                    }
                    """.utf8
                )
            },
            localEmbeddingProvider: { _ in
                Data(
                    """
                    {
                      "revision": "local-test",
                      "dimensions": 256,
                      "seed": "unit-test",
                      "hashesPerFeature": 4,
                      "unigramWeight": 0.9,
                      "keywordWeight": 1.35,
                      "bigramWeight": 1.6
                    }
                    """.utf8
                )
            },
            systemEmbeddingProvider: { nil }
        )

        let model = try manager.loadModel()
        let vector = try XCTUnwrap(
            model.vector(
                for: TopicEmbeddingInput(
                    text: "Network defenses blocked the intrusion.",
                    tokens: ["network", "defense", "block", "intrusion"],
                    keywordTerms: ["network", "defense", "intrusion"],
                    keywordBigrams: ["network defense"]
                )
            )
        )

        XCTAssertEqual(model.providerLabel, "bundled-lexical-embedding")
        XCTAssertEqual(model.expectedDimensions, 256)
        XCTAssertEqual(vector.count, 256)
    }

    func testLoadModelFallsBackToHashedProviderWhenBundledModelIsMissing() throws {
        let manager = TopicModelManager(
            manifestProvider: {
                Data(
                    """
                    {
                      "modelID": "wordz-topics-english",
                      "version": "2",
                      "language": "english",
                      "provider": "bundled-lexical-embedding",
                      "dimensions": 256,
                      "providers": [
                        {
                          "id": "bundled-lexical-embedding",
                          "type": "bundled-lexical-embedding",
                          "dimensions": 256,
                          "revision": "local-test"
                        },
                        {
                          "id": "hashed-fallback",
                          "type": "hashed-fallback",
                          "dimensions": 256,
                          "revision": "hash-test"
                        }
                      ],
                      "localEmbeddingResource": "MissingLocalModel"
                    }
                    """.utf8
                )
            },
            localEmbeddingProvider: { _ in
                throw TopicAnalysisError.missingModelManifest
            },
            systemEmbeddingProvider: { nil }
        )

        let model = try manager.loadModel()
        XCTAssertEqual(model.providerLabel, "hashed-fallback")
    }

    func testLoadModelFallsBackToSystemProviderWhenBundledResourceIsMalformed() throws {
        let manager = TopicModelManager(
            manifestProvider: {
                Data(
                    """
                    {
                      "modelID": "wordz-topics-english",
                      "version": "2",
                      "language": "english",
                      "provider": "bundled-local-embedding",
                      "dimensions": 256,
                      "providers": [
                        {
                          "id": "bundled-local-embedding",
                          "type": "bundled-local-embedding",
                          "dimensions": 256
                        },
                        {
                          "id": "system-sentence-embedding",
                          "type": "system-sentence-embedding",
                          "dimensions": 4,
                          "revision": "system-test"
                        },
                        {
                          "id": "hashed-fallback",
                          "type": "hashed-fallback",
                          "dimensions": 256,
                          "revision": "hash-test"
                        }
                      ],
                      "localEmbeddingResource": "BrokenLocalModel"
                    }
                    """.utf8
                )
            },
            localEmbeddingProvider: { _ in
                Data("{\"revision\":true}".utf8)
            },
            systemEmbeddingProvider: { nil },
            systemSentenceVectorProvider: { text in
                let length = Double(max(1, text.count))
                return [length, length / 2, 1, 0.5]
            }
        )

        let model = try manager.loadModel()
        XCTAssertEqual(model.providerLabel, "system-sentence-embedding")
        XCTAssertEqual(model.expectedDimensions, 4)
    }

    func testLoadModelProviderRevisionTracksBundledResourceRevision() throws {
        func makeManager(resourceRevision: String) -> TopicModelManager {
            TopicModelManager(
                manifestProvider: {
                    Data(
                        """
                        {
                          "modelID": "wordz-topics-english",
                          "version": "2",
                          "language": "english",
                          "provider": "bundled-local-embedding",
                          "dimensions": 256,
                          "providers": [
                            {
                              "id": "bundled-local-embedding",
                              "type": "bundled-local-embedding",
                              "dimensions": 256
                            }
                          ],
                          "localEmbeddingResource": "TopicLocalEmbeddingModel"
                        }
                        """.utf8
                    )
                },
                localEmbeddingProvider: { _ in
                    Data(
                        """
                        {
                          "revision": "\(resourceRevision)",
                          "dimensions": 256,
                          "seed": "unit-test",
                          "hashesPerFeature": 4,
                          "unigramWeight": 0.9,
                          "keywordWeight": 1.35,
                          "bigramWeight": 1.6,
                          "tokenEmbeddings": {
                            "security": { "0": 1.0, "1": 0.2 }
                          }
                        }
                        """.utf8
                    )
                },
                systemEmbeddingProvider: { nil }
            )
        }

        let first = try makeManager(resourceRevision: "local-v1").loadModel()
        let second = try makeManager(resourceRevision: "local-v2").loadModel()

        XCTAssertNotEqual(first.providerRevision, second.providerRevision)
        XCTAssertTrue(first.providerRevision.contains("local-v1"))
        XCTAssertTrue(second.providerRevision.contains("local-v2"))
    }
}
