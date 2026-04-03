import Foundation
import XCTest
@testable import WordZMac

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
