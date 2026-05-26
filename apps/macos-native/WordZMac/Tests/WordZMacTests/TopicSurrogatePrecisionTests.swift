import XCTest
@testable import WordZWorkspaceCore

final class TopicSurrogatePrecisionTests: XCTestCase {
    func testNearNeighborSurrogatePrecisionKeepsCloseThemesSeparated() async throws {
        let corpus = try surrogateCorpus("near-neighbor-governance-privacy-labor")
        let report = try await TopicSurrogatePrecisionHarness.analyze(corpus: corpus)

        assertCoreSurrogateMetrics(report, satisfy: corpus)
        XCTAssertGreaterThanOrEqual(
            report.bridgeAssignmentProxy,
            corpus.minBridgeAssignmentProxy ?? 1,
            report.summaryLine
        )
    }

    func testBridgeAndNoiseDoNotCollapsePrimaryThemes() async throws {
        let corpus = try surrogateCorpus("bridge-noise-precision")
        let report = try await TopicSurrogatePrecisionHarness.analyze(corpus: corpus)

        assertCoreSurrogateMetrics(report, satisfy: corpus)
        XCTAssertGreaterThanOrEqual(
            report.bridgeAssignmentProxy,
            corpus.minBridgeAssignmentProxy ?? 1,
            report.summaryLine
        )
    }

    func testSurrogatePrecisionIsStableAcrossReorderingNoiseAndDuplication() async throws {
        let corpus = try surrogateCorpus("near-neighbor-governance-privacy-labor")
        let report = try await TopicSurrogatePrecisionHarness.analyzeWithStability(corpus: corpus)

        assertCoreSurrogateMetrics(report, satisfy: corpus)
        XCTAssertGreaterThanOrEqual(
            try XCTUnwrap(report.stabilityScore, report.summaryLine),
            try XCTUnwrap(corpus.minStabilityScore, report.summaryLine),
            report.summaryLine
        )
    }

    func testLongParagraphAndParaphraseSurrogateKeepsThemeCoverage() async throws {
        let corpus = try surrogateCorpus("long-paraphrase-mixed")
        let report = try await TopicSurrogatePrecisionHarness.analyze(corpus: corpus)

        assertCoreSurrogateMetrics(report, satisfy: corpus)
    }

    func testSurrogatePrecisionFixtureDoesNotLeakIntoTrainingScript() throws {
        let script = try String(
            contentsOf: repositoryRootURL()
                .appendingPathComponent("Scripts", isDirectory: true)
                .appendingPathComponent("train-topic-model.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(script.contains("topic-benchmark-v2-baselines.json"))
        XCTAssertFalse(script.contains("topic-surrogate-precision-v1.json"))
    }

    private func assertCoreSurrogateMetrics(
        _ report: TopicSurrogatePrecisionReport,
        satisfy corpus: TopicSurrogatePrecisionCorpus
    ) {
        XCTAssertEqual(report.strategy, .exact, report.summaryLine)
        XCTAssertGreaterThanOrEqual(
            report.clusterPurityProxy,
            corpus.minClusterPurityProxy,
            report.summaryLine
        )
        XCTAssertGreaterThanOrEqual(
            report.themeRecallProxy,
            corpus.minThemeRecallProxy,
            report.summaryLine
        )
        XCTAssertLessThanOrEqual(
            report.outlierRatio,
            corpus.maxOutlierRatio,
            report.summaryLine
        )
        XCTAssertGreaterThanOrEqual(
            report.keywordCoherenceProxy,
            corpus.minKeywordCoherenceProxy,
            report.summaryLine
        )
    }

    private func surrogateCorpus(_ id: String) throws -> TopicSurrogatePrecisionCorpus {
        try XCTUnwrap(
            TopicSurrogatePrecisionCatalog.load().first(where: { $0.id == id }),
            "Missing surrogate precision corpus \(id)."
        )
    }

    private func repositoryRootURL(filePath: StaticString = #filePath) -> URL {
        var url = URL(fileURLWithPath: "\(filePath)")
        for _ in 0..<3 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
