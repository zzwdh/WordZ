import XCTest
@testable import WordZWorkspaceCore

final class SentimentModelManagerTests: XCTestCase {
    func testBundledSentimentModelLoadsWhenAvailable() throws {
        let manager = SentimentModelManager()

        guard manager.isModelAvailable else {
            throw XCTSkip("Bundled sentiment model is not available in resources yet.")
        }

        let model = try manager.loadModel()
        XCTAssertFalse(model.inputFeatureName.isEmpty)
        XCTAssertEqual(model.providerID, "bundled-coreml-sentiment")
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
        XCTAssertEqual(result.rows.count, 2)
    }
}
