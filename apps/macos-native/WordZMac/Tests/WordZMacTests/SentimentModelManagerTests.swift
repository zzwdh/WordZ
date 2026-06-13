import XCTest
@testable import WordZWorkspaceCore

final class SentimentModelManagerTests: XCTestCase {
    func testBundledSentimentModelLoadsWhenAvailable() throws {
        let manager = SentimentModelManager()

        guard manager.isModelAvailable else {
            throw XCTSkip("Bundled sentiment model is not available in resources yet.")
        }

        let availability = manager.availability()
        let model = try manager.loadModel()
        XCTAssertTrue(availability.isAvailable)
        XCTAssertEqual(availability.defaultProviderID, "bundled-coreml-sentiment")
        XCTAssertFalse(model.inputFeatureName.isEmpty)
        XCTAssertEqual(model.providerID, "bundled-coreml-sentiment")
        XCTAssertEqual(model.providerFamily, .embeddingLogReg)
        XCTAssertEqual(model.inputSchemaKind, .denseFeatures)
        XCTAssertEqual(model.defaultConfidenceFloor, 0.55, accuracy: 0.0001)
        XCTAssertEqual(model.defaultMarginFloor, 0.12, accuracy: 0.0001)
        XCTAssertEqual(model.maxCharactersPerUnit, 1600)
        XCTAssertTrue(model.supportsSentenceLevelAggregation)
        XCTAssertNotNil(model.predictedProbabilitiesName)
    }

    func testCoreMLSentimentAnalyzerCanScoreSimpleExamplesWhenModelIsAvailable() throws {
        let manager = SentimentModelManager()

        guard manager.isModelAvailable else {
            throw XCTSkip("Bundled sentiment model is not available in resources yet.")
        }

        let analyzer = CoreMLSentimentAnalyzer(
            modelManager: manager,
            indexDocument: { text, _ in
                ParsedDocumentIndex(text: text)
            }
        )
        let request = SentimentRunRequest(
            source: .pastedText,
            unit: .document,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: [
                SentimentInputText(id: "positive", sourceTitle: "manual", text: "The update is excellent and very helpful."),
                SentimentInputText(id: "negative", sourceTitle: "manual", text: "The workflow is problematic and risky.")
            ],
            backend: .coreML
        )

        let result = try analyzer.analyze(request)
        XCTAssertEqual(result.backendKind, .coreML)
        XCTAssertEqual(result.providerID, "bundled-coreml-sentiment")
        XCTAssertEqual(result.providerFamily, .embeddingLogReg)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertTrue(result.rows.allSatisfy { $0.diagnostics.providerID == "bundled-coreml-sentiment" })
        XCTAssertTrue(result.rows.allSatisfy { $0.diagnostics.providerFamily == .embeddingLogReg })
        XCTAssertTrue(result.rows.allSatisfy { $0.diagnostics.inferencePath == .model })
        XCTAssertTrue(result.rows.allSatisfy { $0.diagnostics.modelInputKind == .denseFeatures })
        XCTAssertTrue(result.rows.allSatisfy { $0.diagnostics.coreMLComputeUnits?.isEmpty == false })
    }

    func testProviderCatalogSeparatesEmbeddingAndTransformerCoreMLProviders() throws {
        let manager = SentimentModelManager(
            manifestProvider: {
                Self.layeredProviderManifestData
            }
        )

        let catalog = try manager.providerCatalog(
            profile: makeProfile(hardwareClass: .appleSilicon)
        )

        XCTAssertEqual(catalog.revision, "sentiment-model-pack-p3")
        XCTAssertEqual(catalog.defaultProviderID, "dense-provider")

        let denseProvider = try XCTUnwrap(
            catalog.providers.first { $0.providerID == "dense-provider" }
        )
        XCTAssertEqual(denseProvider.providerFamily, .embeddingLogReg)
        XCTAssertEqual(denseProvider.inputSchemaKind, .denseFeatures)
        XCTAssertEqual(denseProvider.coreMLComputeUnits, "cpuAndNeuralEngine")
        XCTAssertEqual(denseProvider.sizeHintMB, 0.5)

        let transformerProvider = try XCTUnwrap(
            catalog.providers.first { $0.providerID == "transformer-provider" }
        )
        XCTAssertEqual(transformerProvider.providerFamily, .transformerCoreML)
        XCTAssertEqual(transformerProvider.inputSchemaKind, .tokenizedText)
        XCTAssertEqual(transformerProvider.tokenizerResource, "sentiment-transformer-tokenizer-v1")
        XCTAssertEqual(transformerProvider.benchmarkFixtureResource, "sentiment-transformer-benchmark-v1")
        XCTAssertEqual(transformerProvider.sizeHintMB, 242.0)
        XCTAssertEqual(transformerProvider.maxSequenceLength, 192)
        XCTAssertEqual(transformerProvider.coreMLComputeUnits, "all")
    }

    func testTransformerProviderContractRequiresTokenizerSizeAndBenchmarkFixture() {
        let manager = SentimentModelManager(
            manifestProvider: {
                Self.invalidTransformerProviderManifestData
            }
        )

        XCTAssertThrowsError(try manager.providerCatalog()) { error in
            guard case SentimentModelError.invalidProviderContract = error else {
                return XCTFail("Expected invalidProviderContract, received \(error)")
            }
        }

        let availability = manager.availability()
        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.reason, .invalidProviderContract)
        XCTAssertEqual(availability.defaultProviderID, "transformer-provider")
    }

    private static var layeredProviderManifestData: Data {
        Data(
            """
            {
              "revision": "sentiment-model-pack-p3",
              "defaultProviderID": "dense-provider",
              "language": "en",
              "labels": ["positive", "neutral", "negative"],
              "providers": [
                {
                  "id": "dense-provider",
                  "type": "bundled-coreml",
                  "revision": "dense-v1",
                  "modelResource": "DenseSentiment",
                  "providerFamily": "embeddingLogReg",
                  "inputSchema": {
                    "kind": "denseFeatures"
                  },
                  "sizeHintMB": 0.5
                },
                {
                  "id": "transformer-provider",
                  "type": "bundled-coreml",
                  "revision": "transformer-v1",
                  "modelResource": "TransformerSentiment",
                  "providerFamily": "transformerCoreML",
                  "inputSchema": {
                    "kind": "tokenizedText",
                    "inputIDsFeatureName": "input_ids",
                    "attentionMaskFeatureName": "attention_mask",
                    "tokenTypeIDsFeatureName": "token_type_ids",
                    "maxSequenceLength": 192
                  },
                  "tokenizerResource": "sentiment-transformer-tokenizer-v1",
                  "benchmarkFixtureResource": "sentiment-transformer-benchmark-v1",
                  "sizeHintMB": 242.0
                }
              ]
            }
            """.utf8
        )
    }

    private static var invalidTransformerProviderManifestData: Data {
        Data(
            """
            {
              "revision": "sentiment-model-pack-p3",
              "defaultProviderID": "transformer-provider",
              "language": "en",
              "labels": ["positive", "neutral", "negative"],
              "providers": [
                {
                  "id": "transformer-provider",
                  "type": "bundled-coreml",
                  "revision": "transformer-v1",
                  "modelResource": "TransformerSentiment",
                  "providerFamily": "transformerCoreML",
                  "inputSchema": {
                    "kind": "tokenizedText",
                    "inputIDsFeatureName": "input_ids",
                    "attentionMaskFeatureName": "attention_mask",
                    "maxSequenceLength": 192
                  }
                }
              ]
            }
            """.utf8
        )
    }

    private func makeProfile(
        hardwareClass: NativeHardwareClass,
        hasMetalGPU: Bool? = nil
    ) -> NativeHardwareProfile {
        NativeHardwareProfile(
            acceleration: HardwareAccelerationSnapshot(
                hardwareClass: hardwareClass,
                hasMetalGPU: hasMetalGPU ?? (hardwareClass == .appleSilicon),
                hasAppleNeuralEngine: hardwareClass == .appleSilicon
            ),
            processorCount: 8,
            activeProcessorCount: 8,
            physicalMemoryBytes: UInt64(16_384) * 1_048_576,
            lowPowerModeEnabled: false,
            thermalProfile: .nominal,
            operatingSystem: NativeOperatingSystemProfile(
                majorVersion: 14,
                minorVersion: 0,
                patchVersion: 0
            )
        )
    }
}
