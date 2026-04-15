import XCTest
@testable import WordZWorkspaceCore

final class NativeTopicEngineTests: XCTestCase {
    func testMakeSlicesSplitsLongParagraphsAndMergesTrailingShortSentence() async throws {
        let engine = NativeTopicEngine()
        let text = """
        Cybersecurity analysts documented phishing infrastructure across multiple campaigns while tracking domains, sandbox artifacts, and incident-response handoffs between partner teams. The report also compared credential theft patterns across several intrusion sets to isolate repeatable delivery tactics. Incident responders preserved forensic evidence in synchronized timelines so engineers could reconstruct the first compromised endpoint with confidence. Malware reverse engineers mapped loader behavior to command-and-control changes and correlated the samples with recent disclosure notes. Brief note.
        """

        let slices = try await engine.makeSlices(
            for: text,
            cacheKey: "slice-merge-test"
        )

        XCTAssertGreaterThanOrEqual(slices.count, 2)
        XCTAssertTrue(slices.contains(where: { $0.text == "Brief note." }))
        XCTAssertTrue(slices.allSatisfy { !$0.tokens.isEmpty })
    }

    func testMakeSlicesKeepsRepeatedChunkIDsUnique() async throws {
        let engine = NativeTopicEngine()
        let repeatedParagraph = "Threat hunters mapped credential phishing kits to repeated operator infrastructure and documented the same incident pattern across vendors."
        let text = Array(repeating: repeatedParagraph, count: 3).joined(separator: "\n\n")

        let slices = try await engine.makeSlices(
            for: text,
            cacheKey: "slice-duplicate-id-test"
        )

        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(Set(slices.map(\.id)).count, slices.count)
    }

    func testMakeSlicesSplitsVeryLongSentenceByClausesBeforeChunkAssembly() async throws {
        let engine = NativeTopicEngine()
        let text = """
        Security analysts coordinated disclosure timelines, browser patch validation, exploit telemetry review, vendor remediation windows, incident messaging, customer guidance, rollout checkpoints, sandbox verification, regression triage, gateway testing, mitigation summaries, partner updates, advisory drafts, release notes, postmortem edits, and escalation tracking; climate scientists measured glacier retreat, carbon emissions, drought pressure, warming oceans, methane budgets, rainfall deficits, atmospheric circulation, coastal flooding, agricultural stress, seasonal anomalies, wildfire smoke, adaptation budgets, utility demand, flood planning, habitat decline, and regional heat exposure; market analysts reviewed earnings guidance, valuation pressure, cash flow revisions, inflation expectations, bond spreads, dividend outlooks, sector rotation, central bank commentary, credit risk, portfolio hedging, funding costs, liquidity planning, rate sensitivity, margin forecasts, revenue durability, and capital allocation.
        """

        let slices = try await engine.makeSlices(
            for: text,
            cacheKey: "slice-clause-split-test"
        )

        XCTAssertGreaterThanOrEqual(slices.count, 3)
        XCTAssertTrue(slices.allSatisfy { TopicFilterSupport.tokenize($0.text).count <= 56 })
        XCTAssertTrue(slices.contains(where: { $0.text.contains("browser patch validation") }))
        XCTAssertTrue(slices.contains(where: { $0.text.contains("carbon emissions") }))
        XCTAssertTrue(slices.contains(where: { $0.text.contains("earnings guidance") }))
    }

    func testAnalyzeEmitsHashedFallbackWarningWhenAllEmbeddingsAreUnavailable() async throws {
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
        let engine = NativeTopicEngine(modelManager: manager)
        let text = """
        Security teams coordinated vulnerability disclosure timelines with browser vendors and infrastructure maintainers.

        Attackers reused credential phishing templates across several campaigns targeting remote access gateways.
        """

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: 1),
            progress: nil
        )

        XCTAssertEqual(result.modelProvider, "hashed-fallback")
        XCTAssertTrue(result.usesFallbackProvider)
        XCTAssertEqual(result.diagnostics.providerTier, .hashedFallback)
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("当前 provider 非 bundled") }))
    }

    func testBuildKeywordCandidatesReturnsUnigramOnlyTermsCappedAtTwelve() async throws {
        let engine = NativeTopicEngine()
        let slices = [
            TopicTextSlice(
                id: "segment-1",
                paragraphIndex: 1,
                text: "Security vulnerability response analysts tracked actor campaigns.",
                tokens: [
                    "security", "security", "security",
                    "vulnerability", "vulnerability",
                    "response", "analyst", "actor", "campaign",
                    "vendor", "patch", "defense", "risk", "telemetry", "intel"
                ],
                keywordTerms: [
                    "security", "security", "security",
                    "vulnerability", "vulnerability",
                    "response", "analyst", "actor", "campaign",
                    "vendor", "patch", "defense", "risk", "telemetry", "intel"
                ],
                keywordBigrams: [
                    "security vulnerability",
                    "vulnerability response",
                    "actor campaign"
                ]
            )
        ]
        let restSlices = [
            TopicTextSlice(
                id: "segment-2",
                paragraphIndex: 2,
                text: "Generic analysts tracked responses across multiple reports.",
                tokens: ["analyst", "response", "generic", "report", "campaign"],
                keywordTerms: ["analyst", "response", "report", "campaign"],
                keywordBigrams: ["generic report"]
            )
        ]
        let clusterDocumentFrequency = Dictionary(
            uniqueKeysWithValues: [
                "security", "vulnerability", "response", "analyst", "actor", "campaign",
                "vendor", "patch", "defense", "risk", "telemetry", "intel"
            ]
            .map { ($0, 1) }
        )

        let candidates = await engine.buildKeywordCandidates(
            slices: slices,
            restSlices: restSlices,
            clusteredSliceDocumentFrequency: clusterDocumentFrequency,
            clusteredSliceCount: 2
        )

        XCTAssertEqual(candidates.count, 12)
        XCTAssertEqual(candidates.first?.term, "security")
        XCTAssertTrue(candidates.allSatisfy { !$0.term.contains(" ") })
        XCTAssertFalse(candidates.map(\.term).contains("security vulnerability"))
    }

    func testRepresentativeSegmentsPreferDistinctPreviewExamples() async throws {
        let engine = NativeTopicEngine()
        let slices = [
            TopicTextSlice(
                id: "segment-1",
                paragraphIndex: 1,
                text: "Security teams coordinated vulnerability disclosure across vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure"]
            ),
            TopicTextSlice(
                id: "segment-2",
                paragraphIndex: 2,
                text: "Security teams coordinated vulnerability disclosure across browser vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "browser", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "browser", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure", "browser vendor"]
            ),
            TopicTextSlice(
                id: "segment-3",
                paragraphIndex: 3,
                text: "Security teams coordinated vulnerability disclosure across platform vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "platform", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "platform", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure", "platform vendor"]
            ),
            TopicTextSlice(
                id: "segment-4",
                paragraphIndex: 4,
                text: "Incident responders traced malware loaders through rotating command servers.",
                tokens: ["incident", "responder", "trace", "malware", "loader", "rotate", "command", "server"],
                keywordTerms: ["incident", "malware", "loader", "command", "server"],
                keywordBigrams: ["malware loader", "command server"]
            )
        ]
        let embeddings = [
            [1.0, 0.0],
            [0.99, 0.01],
            [0.98, 0.02],
            [0.75, 0.45]
        ].map { vector in
            let magnitude = sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
            return vector.map { $0 / magnitude }
        }
        let similarityMatrix = await engine.pairwiseSimilarityMatrix(for: embeddings)
        let representativeIDs = await engine.representativeSegmentIDs(
            cluster: ClusterState(
                memberIndices: Array(slices.indices),
                centroid: [0.94, 0.18]
            ),
            slices: slices,
            embeddings: embeddings,
            similarityMatrix: similarityMatrix
        )

        XCTAssertEqual(representativeIDs.count, 3)
        XCTAssertTrue(representativeIDs.contains("segment-4"))
    }

    func testRepresentativeSegmentsFallBackToEmbeddingsWhenSimilarityMatrixMissing() async throws {
        let engine = NativeTopicEngine()
        let slices = [
            TopicTextSlice(
                id: "segment-1",
                paragraphIndex: 1,
                text: "Security teams coordinated vulnerability disclosure across vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure"]
            ),
            TopicTextSlice(
                id: "segment-2",
                paragraphIndex: 2,
                text: "Security teams coordinated vulnerability disclosure across browser vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "browser", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "browser", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure", "browser vendor"]
            ),
            TopicTextSlice(
                id: "segment-3",
                paragraphIndex: 3,
                text: "Security teams coordinated vulnerability disclosure across platform vendors.",
                tokens: ["security", "team", "coordinate", "vulnerability", "disclosure", "platform", "vendor"],
                keywordTerms: ["security", "vulnerability", "disclosure", "platform", "vendor"],
                keywordBigrams: ["security vulnerability", "vulnerability disclosure", "platform vendor"]
            ),
            TopicTextSlice(
                id: "segment-4",
                paragraphIndex: 4,
                text: "Incident responders traced malware loaders through rotating command servers.",
                tokens: ["incident", "responder", "trace", "malware", "loader", "rotate", "command", "server"],
                keywordTerms: ["incident", "malware", "loader", "command", "server"],
                keywordBigrams: ["malware loader", "command server"]
            )
        ]
        let embeddings = [
            [1.0, 0.0],
            [0.99, 0.01],
            [0.98, 0.02],
            [0.75, 0.45]
        ].map { vector in
            let magnitude = sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
            return vector.map { $0 / magnitude }
        }
        let representativeIDs = await engine.representativeSegmentIDs(
            cluster: ClusterState(
                memberIndices: Array(slices.indices),
                centroid: [0.94, 0.18]
            ),
            slices: slices,
            embeddings: embeddings,
            similarityMatrix: []
        )

        XCTAssertEqual(representativeIDs.count, 3)
        XCTAssertTrue(representativeIDs.contains("segment-4"))
    }

    func testAnalyzeEmitsSystemFallbackWarningWhenBundledModelIsUnavailable() async throws {
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
                      "localEmbeddingResource": "MissingLocalModel"
                    }
                    """.utf8
                )
            },
            localEmbeddingProvider: { _ in
                throw TopicAnalysisError.missingModelManifest
            },
            systemEmbeddingProvider: { nil },
            systemSentenceVectorProvider: { text in
                let tokens = TopicFilterSupport.tokenize(text)
                return [
                    Double(tokens.count),
                    Double(tokens.filter { $0.contains("security") || $0.contains("incident") }.count),
                    Double(tokens.filter { $0.contains("climate") || $0.contains("carbon") }.count),
                    Double(tokens.filter { $0.contains("market") || $0.contains("equity") }.count)
                ]
            }
        )
        let engine = NativeTopicEngine(modelManager: manager)
        let text = """
        Security teams coordinated vulnerability disclosure timelines across vendors.

        Incident responders traced command servers through rotated malware infrastructure.
        """

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: 1),
            progress: nil
        )

        XCTAssertEqual(result.modelProvider, "system-sentence-embedding")
        XCTAssertFalse(result.usesFallbackProvider)
        XCTAssertEqual(result.diagnostics.providerTier, .systemFallback)
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("当前 provider 非 bundled") }))
    }

    func testReduceEmbeddingsAppliesPCAForHighDimensionalLargeSampleInputs() async throws {
        let engine = NativeTopicEngine()
        let model = TopicEmbeddingModel(
            manifest: .fallback,
            providerLabel: "bundled-local-embedding",
            providerRevision: "wordz-topics-english::3::bundled-local-embedding::test",
            isPrimaryProvider: true,
            expectedDimensions: 384
        ) { _ in nil }

        let vectors: [[Double]] = (0..<64).map { index in
            let alpha = Double(index % 5) * 0.4
            let beta = Double((index / 5) % 4) * 0.35
            let gamma = Double(index % 3) * 0.28
            return (0..<384).map { component in
                let bucket = component / 48
                let latent: Double
                switch bucket % 3 {
                case 0:
                    latent = alpha
                case 1:
                    latent = beta
                default:
                    latent = gamma
                }
                let noise = Double((index + component) % 7) * 0.0008
                return latent + noise
            }
        }

        let reduced = await engine.reduceEmbeddingsIfNeeded(
            vectors,
            contentHash: "pca-large-sample",
            model: model,
            allowReduction: true
        )

        XCTAssertTrue(reduced.applied)
        XCTAssertNotNil(reduced.reducedDimensions)
        XCTAssertEqual(reduced.originalDimensions, 384)
        XCTAssertLessThan(reduced.reducedDimensions ?? 384, 384)
        XCTAssertGreaterThan(reduced.explainedVariance ?? 0, 0.97)
    }

    func testReduceEmbeddingsSkipsPCAForSmallSampleInputs() async throws {
        let engine = NativeTopicEngine()
        let model = TopicEmbeddingModel(
            manifest: .fallback,
            providerLabel: "bundled-local-embedding",
            providerRevision: "wordz-topics-english::3::bundled-local-embedding::test",
            isPrimaryProvider: true,
            expectedDimensions: 384
        ) { _ in nil }

        let vectors: [[Double]] = (0..<16).map { index in
            (0..<384).map { component in
                Double((index + component) % 11) * 0.1
            }
        }

        let reduced = await engine.reduceEmbeddingsIfNeeded(
            vectors,
            contentHash: "pca-small-sample",
            model: model,
            allowReduction: true
        )

        XCTAssertFalse(reduced.applied)
        XCTAssertEqual(reduced.originalDimensions, 384)
        XCTAssertNil(reduced.reducedDimensions)
        XCTAssertNil(reduced.explainedVariance)
        XCTAssertEqual(reduced.vectors.count, vectors.count)
        XCTAssertEqual(reduced.vectors.first?.count, 384)
    }

    func testNativeTopicEngineProcessesThreeHundredSliceBenchmarkCorpus() async throws {
        let engine = NativeTopicEngine()
        let securityParagraphs = (0..<100).map { index in
            "Security analysts correlated vulnerability disclosures, malware infrastructure, and incident timelines for gateway cluster \(index)."
        }
        let climateParagraphs = (0..<100).map { index in
            "Climate researchers measured carbon emissions, renewable adoption, and drought pressure across regional basin \(index)."
        }
        let financeParagraphs = (0..<100).map { index in
            "Market analysts reviewed earnings guidance, cash flow, inflation expectations, and valuation shifts for portfolio \(index)."
        }
        let text = (securityParagraphs + climateParagraphs + financeParagraphs).joined(separator: "\n\n")

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: 4),
            progress: nil
        )

        XCTAssertEqual(result.modelProvider, "bundled-local-embedding")
        XCTAssertGreaterThanOrEqual(result.totalSegments, 300)
        XCTAssertGreaterThanOrEqual(result.clusters.filter { !$0.isOutlier }.count, 3)
        XCTAssertEqual(result.diagnostics.clusteringStrategy, .exact)
        XCTAssertFalse(result.warnings.contains(where: { $0.contains("近似聚类") }))
        XCTAssertFalse(result.diagnostics.embeddingReduction.applied)
    }

    func testNativeTopicEngineProcessesFourHundredFiftySliceBenchmarkCorpusWithApproximateStrategy() async throws {
        let engine = NativeTopicEngine()
        let securityParagraphs = (0..<150).map { index in
            "Security analysts correlated vulnerability disclosures, malware infrastructure, and incident timelines for gateway cluster \(index)."
        }
        let climateParagraphs = (0..<150).map { index in
            "Climate researchers measured carbon emissions, renewable adoption, and drought pressure across regional basin \(index)."
        }
        let financeParagraphs = (0..<150).map { index in
            "Market analysts reviewed earnings guidance, cash flow, inflation expectations, and valuation shifts for portfolio \(index)."
        }
        let text = (securityParagraphs + climateParagraphs + financeParagraphs).joined(separator: "\n\n")

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: 4),
            progress: nil
        )

        XCTAssertEqual(result.modelProvider, "bundled-local-embedding")
        XCTAssertGreaterThanOrEqual(result.totalSegments, 450)
        XCTAssertGreaterThanOrEqual(result.clusters.filter { !$0.isOutlier }.count, 3)
        XCTAssertEqual(result.diagnostics.clusteringStrategy, .approximateRefined)
        XCTAssertTrue(result.warnings.contains(where: { $0.contains("近似聚类") }))
    }

    func testApproximateClusterVectorsSkipsFullSimilarityMatrixForLargeInputs() async throws {
        let engine = NativeTopicEngine()
        let vectors = (0..<360).map { index -> [Double] in
            let bucket = index / 120
            let anchor: [Double]
            switch bucket {
            case 0:
                anchor = [1.0, 0.05, 0.02]
            case 1:
                anchor = [0.04, 1.0, 0.03]
            default:
                anchor = [0.03, 0.06, 1.0]
            }
            let jitter = Double(index % 11) * 0.0025
            let vector = [
                anchor[0] + jitter,
                anchor[1] + Double((index + 3) % 7) * 0.002,
                anchor[2] + Double((index + 5) % 5) * 0.0015
            ]
            let magnitude = sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
            return vector.map { $0 / magnitude }
        }

        let clustered = await engine.clusterVectors(vectors, minTopicSize: 6)

        XCTAssertTrue(clustered.similarityMatrix.isEmpty)
        XCTAssertGreaterThanOrEqual(clustered.validClusters.count, 2)
        XCTAssertEqual(clustered.strategy, .approximateRefined)
        XCTAssertTrue(clustered.warnings.contains(where: { $0.contains("近似聚类") }))
    }
}
