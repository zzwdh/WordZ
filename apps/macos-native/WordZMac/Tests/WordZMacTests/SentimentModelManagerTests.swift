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
    }
}
