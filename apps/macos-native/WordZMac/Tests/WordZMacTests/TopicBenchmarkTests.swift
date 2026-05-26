import XCTest
@testable import WordZWorkspaceCore

final class TopicBenchmarkTests: XCTestCase {
    func testExactBenchmarkCorporaImprovePurityAndPreserveThemeRecall() async throws {
        let monitoredIDs = Set(["security-overlap-exact", "three-theme-exact-300"])
        let corpora = try TopicBenchmarkCatalog.load()
            .filter { monitoredIDs.contains($0.id) }

        for corpus in corpora {
            let report = try await TopicBenchmarkHarness.analyze(corpus: corpus)

            XCTAssertEqual(report.strategy, .exact, report.summaryLine)
            XCTAssertGreaterThanOrEqual(
                report.purity,
                corpus.baselinePurity + corpus.requiredPurityLift,
                report.summaryLine
            )
            XCTAssertGreaterThanOrEqual(
                report.themeRecall,
                corpus.baselineThemeRecall,
                report.summaryLine
            )
            if corpus.id == "three-theme-exact-300" {
                XCTAssertGreaterThanOrEqual(report.nonOutlierClusterCount, 3, report.summaryLine)
            }
        }
    }

    func testApproximateBenchmarkCorpusImprovesPurityAndSignalsApproximateStrategy() async throws {
        let corpus = try XCTUnwrap(
            TopicBenchmarkCatalog.load().first(where: { $0.id == "three-theme-approx-450" })
        )

        let report = try await TopicBenchmarkHarness.analyze(corpus: corpus)

        XCTAssertEqual(report.strategy, .approximateRefined, report.summaryLine)
        XCTAssertTrue(report.warnings.contains(where: { $0.contains("近似聚类") }), report.summaryLine)
        XCTAssertGreaterThanOrEqual(
            report.purity,
            corpus.baselinePurity + corpus.requiredPurityLift,
            report.summaryLine
        )
        XCTAssertGreaterThanOrEqual(
            report.themeRecall,
            corpus.baselineThemeRecall,
            report.summaryLine
        )
    }

    func testTopicBenchmarkSmokeDurationsStayWithinConfiguredBudget() async throws {
        let monitoredIDs = Set(["three-theme-exact-300", "three-theme-approx-450"])
        let corpora = try TopicBenchmarkCatalog.load().filter { monitoredIDs.contains($0.id) }
        var snapshots: [TopicBenchmarkReportSnapshot] = []

        for corpus in corpora {
            let report = try await TopicBenchmarkHarness.analyze(corpus: corpus)
            XCTAssertLessThanOrEqual(
                report.durationMs,
                corpus.maxDurationMs * 2,
                report.summaryLine
            )
            snapshots.append(
                TopicBenchmarkReporter.snapshot(
                    corpus: corpus,
                    report: report
                )
            )
        }

        let hardware = TopicBenchmarkHardwareProfile.current()
        XCTAssertFalse(hardware.summaryLine.isEmpty)
        XCTAssertEqual(
            Set(hardware.coreMLComputeUnits.keys),
            Set(SentimentModelProviderFamily.allCases.map(\.rawValue))
        )
        try TopicBenchmarkReporter.writeSnapshots(
            snapshots,
            hardware: hardware,
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
            .appendingPathComponent("topic-benchmark-report.generated.json")
    }
}
