import Foundation
import XCTest
@testable import WordZWorkspaceCore

final class SentimentBenchmarkReportTests: XCTestCase {
    private let regressionTolerance = 0.0001

    func testBenchmarkProfilesStayAtOrAboveSavedBaselinesAndCanWriteJSONReport() throws {
        let savedBaselines = try SentimentBenchmarkBaselineStore.load()
        let executions = try SentimentBenchmarkProfile.allCases.map {
            try SentimentBenchmarkReporter.execute(
                profile: $0,
                savedBaselines: savedBaselines
            )
        }

        for execution in executions {
            let report = execution.report
            let profile = execution.profile
            let savedBaseline = try XCTUnwrap(
                execution.savedBaseline,
                "Missing saved baseline for \(profile.rawValue)"
            )

            XCTAssertEqual(savedBaseline.datasetVersion, execution.datasetVersion)
            XCTAssertEqual(savedBaseline.exampleCount, report.exampleCount)
            XCTAssertGreaterThanOrEqual(
                report.accuracy + regressionTolerance,
                savedBaseline.accuracy,
                "\(profile.rawValue) accuracy regressed: current=\(report.summaryLine) saved=\(savedBaseline.accuracy)"
            )
            XCTAssertGreaterThanOrEqual(
                report.macroF1 + regressionTolerance,
                savedBaseline.macroF1,
                "\(profile.rawValue) macroF1 regressed: current=\(report.summaryLine) saved=\(savedBaseline.macroF1)"
            )

            if !savedBaseline.requiredSliceKeys.isEmpty {
                XCTAssertEqual(
                    Set(report.slices.keys),
                    Set(savedBaseline.requiredSliceKeys),
                    "\(profile.rawValue) slice coverage changed."
                )
            }
        }

        let snapshots = executions.map(SentimentBenchmarkReporter.snapshot(for:))
        try SentimentBenchmarkReporter.writeSnapshots(
            snapshots,
            to: defaultReportOutputURL
        )
    }

    private var defaultReportOutputURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("reports", isDirectory: true)
            .appendingPathComponent("sentiment-benchmark-report.generated.json")
    }
}
