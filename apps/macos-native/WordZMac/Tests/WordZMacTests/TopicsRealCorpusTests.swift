import Foundation
import XCTest
@testable import WordZWorkspaceCore

final class TopicsRealCorpusTests: XCTestCase {
    func testNativeTopicEngineBuildsUsableTopicsFromRepositoryEnglishCorpus() async throws {
        let engine = NativeTopicEngine()
        let text = try makeRepositoryEnglishCorpus()

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(),
            progress: nil
        )

        XCTAssertGreaterThanOrEqual(result.totalSegments, 5)
        XCTAssertFalse(result.clusters.isEmpty)
        XCTAssertGreaterThan(result.clusteredSegments, 0)
        XCTAssertTrue(
            result.clusters.contains(where: { !$0.isOutlier && !$0.keywordCandidates.isEmpty }),
            "Expected at least one non-outlier topic with keywords for a real English corpus sample."
        )

        if let firstCluster = result.clusters.first(where: { !$0.isOutlier }) {
            XCTAssertFalse(result.representativeSegments(for: firstCluster.id).isEmpty)
        }
    }

    func testNativeTopicEngineSeparatesThreeClearThemesFromMixedCorpus() async throws {
        let engine = NativeTopicEngine()
        let text = """
        Security researchers mapped botnet infrastructure, coordinated disclosure timelines, and shared mitigation guidance for patched gateways.

        Incident responders traced malware loaders through rotating command servers and collected forensic evidence from compromised endpoints.

        Vulnerability analysts compared exploit chains, browser patches, and sandbox telemetry to isolate recurring intrusion tactics.

        Climate scientists measured glacier melt rates, carbon emissions, and regional temperature anomalies during recent summer seasons.

        Environmental agencies tracked renewable energy adoption, methane reductions, and decarbonization policy targets across several cities.

        Researchers modeled ocean warming, drought risk, and atmospheric circulation shifts to forecast future climate pressure.

        Equity analysts reviewed earnings guidance, cash flow, and margin expansion after the company released quarterly results.

        Investors rebalanced bond holdings, monitored inflation expectations, and reassessed credit spreads after the central bank meeting.

        Market strategists compared valuation multiples, dividend outlooks, and sector rotation signals across large-cap portfolios.

        A short unrelated note about coffee beans cooling on the desk.
        """

        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: 2),
            progress: nil
        )

        let keywordUniverse = Set(
            result.clusters
                .filter { !$0.isOutlier }
                .flatMap(\.keywordTerms)
        )

        XCTAssertGreaterThanOrEqual(result.clusters.filter { !$0.isOutlier }.count, 3)
        XCTAssertTrue(
            keywordUniverse.contains(where: {
                $0.contains("security")
                    || $0.contains("vulnerability")
                    || $0.contains("malware")
                    || $0.contains("incident")
                    || $0.contains("intrusion")
                    || $0.contains("exploit")
                    || $0.contains("patch")
            })
        )
        XCTAssertTrue(
            keywordUniverse.contains(where: {
                $0.contains("climate")
                    || $0.contains("carbon")
                    || $0.contains("glacier")
                    || $0.contains("renewable")
                    || $0.contains("methane")
            })
        )
        XCTAssertTrue(
            keywordUniverse.contains(where: {
                $0.contains("market")
                    || $0.contains("equity")
                    || $0.contains("valuation")
                    || $0.contains("cash flow")
                    || $0.contains("inflation")
            })
        )
    }

    private func makeRepositoryEnglishCorpus(filePath: StaticString = #filePath) throws -> String {
        let repositoryRoot = repositoryRootURL(from: filePath)
        let samplePaths = [
            "build/license_en.txt",
            "apps/macos-native/WordZMac/README.md",
            "packages/wordz-engine-js/README.md"
        ]

        let documents = try samplePaths.map { relativePath -> String in
            let url = repositoryRoot.appendingPathComponent(relativePath)
            return try String(contentsOf: url, encoding: .utf8)
        }

        return documents.joined(separator: "\n\n")
    }

    private func repositoryRootURL(from filePath: StaticString) -> URL {
        var url = URL(fileURLWithPath: "\(filePath)")
        for _ in 0..<6 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
