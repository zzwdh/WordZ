import XCTest
@testable import WordZWorkspaceCore

final class SentimentBenchmarkTests: XCTestCase {
    func testLexiconBenchmarkOnHeldOutGoldSetExceedsStarterFloor() throws {
        let dataset = try SentimentGoldDataset.load()
        let testExamples = dataset.filter { $0.split == .test }

        let report = SentimentBenchmarkHarness.evaluate(
            examples: testExamples,
            thresholds: SentimentThresholdPreset.conservative.thresholds,
            backend: .lexicon
        )

        XCTAssertGreaterThanOrEqual(report.accuracy, 0.65, report.summaryLine)
        XCTAssertGreaterThanOrEqual(report.macroF1, 0.65, report.summaryLine)
    }

    func testLexiconCalibrationImprovesOrMatchesBalancedPresetOnValidationSet() throws {
        let dataset = try SentimentGoldDataset.load()
        let validationExamples = dataset.filter { $0.split == .validation }

        let baseline = SentimentBenchmarkHarness.evaluate(
            examples: validationExamples,
            thresholds: SentimentThresholdPreset.balanced.thresholds,
            backend: .lexicon
        )
        let calibrated = SentimentBenchmarkHarness.calibrateLexicon(
            validationExamples: validationExamples
        )

        XCTAssertGreaterThanOrEqual(calibrated.report.macroF1, baseline.macroF1, calibrated.report.summaryLine)
    }

    func testCoreMLBenchmarkOnHeldOutGoldSetWhenBundledModelIsAvailable() throws {
        guard SentimentModelManager().isModelAvailable else {
            throw XCTSkip("Bundled sentiment model is not available in resources yet.")
        }

        let dataset = try SentimentGoldDataset.load()
        let testExamples = dataset.filter { $0.split == .test }
        let lexiconReport = SentimentBenchmarkHarness.evaluate(
            examples: testExamples,
            thresholds: SentimentThresholdPreset.balanced.thresholds,
            backend: .lexicon
        )
        let report = SentimentBenchmarkHarness.evaluate(
            examples: testExamples,
            thresholds: SentimentThresholdPreset.balanced.thresholds,
            backend: .coreML
        )

        XCTAssertGreaterThanOrEqual(report.accuracy, 0.55, report.summaryLine)
        XCTAssertGreaterThanOrEqual(report.macroF1, 0.55, report.summaryLine)
        XCTAssertGreaterThanOrEqual(report.macroF1, lexiconReport.macroF1, "coreML=\(report.summaryLine) lexicon=\(lexiconReport.summaryLine)")
    }
}
