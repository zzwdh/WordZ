import Foundation
@testable import WordZWorkspaceCore

enum TopicBenchmarkCorpusKind: String, Codable {
    case exact
    case approximate
}

struct TopicBenchmarkFixtureBundle: Decodable {
    let corpora: [TopicBenchmarkCorpus]
}

struct TopicBenchmarkCorpus: Decodable {
    let id: String
    let kind: TopicBenchmarkCorpusKind
    let minTopicSize: Int
    let expectedThemes: [String]
    let baselinePurity: Double
    let requiredPurityLift: Double
    let baselineThemeRecall: Double
    let maxDurationMs: Double
    let documents: [TopicBenchmarkDocument]
}

struct TopicBenchmarkDocument: Decodable {
    let label: String
    let text: String
    let repeatCount: Int?
}

struct TopicBenchmarkExpandedDocument {
    let paragraphIndex: Int
    let label: String
    let text: String
}

struct TopicBenchmarkReport {
    let corpusID: String
    let strategy: TopicClusteringStrategy
    let purity: Double
    let themeRecall: Double
    let nonOutlierClusterCount: Int
    let durationMs: Double
    let warnings: [String]

    var summaryLine: String {
        String(
            format: "%@ strategy=%@ purity=%.3f recall=%.3f clusters=%d durationMs=%.1f",
            corpusID,
            strategy.rawValue,
            purity,
            themeRecall,
            nonOutlierClusterCount,
            durationMs
        )
    }
}

enum TopicBenchmarkCatalog {
    static func load(
        filePath: StaticString = #filePath
    ) throws -> [TopicBenchmarkCorpus] {
        let fixtureURL = Bundle.module.url(
            forResource: "topic-benchmark-v2-baselines",
            withExtension: "json",
            subdirectory: "Fixtures/Topics"
        ) ?? URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Topics", isDirectory: true)
            .appendingPathComponent("topic-benchmark-v2-baselines.json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(TopicBenchmarkFixtureBundle.self, from: data).corpora
    }
}

enum TopicBenchmarkHarness {
    static func expandedDocuments(
        for corpus: TopicBenchmarkCorpus
    ) -> [TopicBenchmarkExpandedDocument] {
        var expanded: [TopicBenchmarkExpandedDocument] = []
        expanded.reserveCapacity(corpus.documents.reduce(0) { $0 + max(1, $1.repeatCount ?? 1) })

        var paragraphIndex = 1
        for document in corpus.documents {
            for _ in 0..<max(1, document.repeatCount ?? 1) {
                expanded.append(
                    TopicBenchmarkExpandedDocument(
                        paragraphIndex: paragraphIndex,
                        label: document.label,
                        text: document.text
                    )
                )
                paragraphIndex += 1
            }
        }
        return expanded
    }

    static func analyze(
        corpus: TopicBenchmarkCorpus,
        engine: NativeTopicEngine = NativeTopicEngine()
    ) async throws -> TopicBenchmarkReport {
        let documents = expandedDocuments(for: corpus)
        let text = documents.map(\.text).joined(separator: "\n\n")
        let clock = ContinuousClock()
        let start = clock.now
        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(minTopicSize: corpus.minTopicSize),
            progress: nil
        )
        let elapsed = start.duration(to: clock.now)
        let durationMs = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000

        let labelByParagraph = Dictionary(uniqueKeysWithValues: documents.map { ($0.paragraphIndex, $0.label) })
        let nonOutlierClusters = result.clusters.filter { !$0.isOutlier }
        let segmentsByTopicID = Dictionary(grouping: result.segments.filter { !$0.isOutlier }, by: \.topicID)

        var totalClusteredSegments = 0
        var totalMajoritySegments = 0
        var representedThemes = Set<String>()

        for cluster in nonOutlierClusters {
            let segments = segmentsByTopicID[cluster.id] ?? []
            let labelCounts = Dictionary(grouping: segments, by: { labelByParagraph[$0.paragraphIndex] ?? "unknown" })
                .mapValues(\.count)
            guard let majority = labelCounts.max(by: { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key > rhs.key
                }
                return lhs.value < rhs.value
            }) else {
                continue
            }
            totalClusteredSegments += segments.count
            totalMajoritySegments += majority.value
            if corpus.expectedThemes.contains(majority.key) {
                representedThemes.insert(majority.key)
            }
        }

        let purity = totalClusteredSegments == 0
            ? 0
            : Double(totalMajoritySegments) / Double(totalClusteredSegments)
        let themeRecall = corpus.expectedThemes.isEmpty
            ? 0
            : Double(representedThemes.count) / Double(corpus.expectedThemes.count)

        return TopicBenchmarkReport(
            corpusID: corpus.id,
            strategy: result.diagnostics.clusteringStrategy,
            purity: purity,
            themeRecall: themeRecall,
            nonOutlierClusterCount: nonOutlierClusters.count,
            durationMs: durationMs,
            warnings: result.warnings
        )
    }
}
