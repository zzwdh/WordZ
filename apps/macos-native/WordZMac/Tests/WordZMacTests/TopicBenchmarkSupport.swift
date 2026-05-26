import CoreML
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

struct TopicBenchmarkHardwareProfile: Codable, Equatable {
    let hardwareClass: String
    let hasMetalGPU: Bool
    let hasAppleNeuralEngine: Bool
    let coreMLComputeUnits: [String: String]
    let summaryLine: String

    static func current() -> Self {
        let snapshot = HardwareAccelerationPolicy.currentSnapshot()
        let providerFamilies: [SentimentModelProviderFamily] = [
            .bundledCoreML,
            .embeddingLogReg,
            .textMaxEnt,
            .transformerCoreML,
            .unknown
        ]
        let computeUnits = Dictionary(uniqueKeysWithValues: providerFamilies.map { family in
            (
                family.rawValue,
                computeUnitsLabel(
                    HardwareAccelerationPolicy.coreMLComputeUnits(
                        for: family,
                        snapshot: snapshot
                    )
                )
            )
        })
        let hardwareClass = snapshot.hardwareClass.rawValue
        return TopicBenchmarkHardwareProfile(
            hardwareClass: hardwareClass,
            hasMetalGPU: snapshot.hasMetalGPU,
            hasAppleNeuralEngine: snapshot.hasAppleNeuralEngine,
            coreMLComputeUnits: computeUnits,
            summaryLine: summaryLine(
                hardwareClass: hardwareClass,
                hasMetalGPU: snapshot.hasMetalGPU,
                hasAppleNeuralEngine: snapshot.hasAppleNeuralEngine,
                coreMLComputeUnits: computeUnits
            )
        )
    }

    private static func summaryLine(
        hardwareClass: String,
        hasMetalGPU: Bool,
        hasAppleNeuralEngine: Bool,
        coreMLComputeUnits: [String: String]
    ) -> String {
        let orderedFamilies = [
            SentimentModelProviderFamily.embeddingLogReg,
            SentimentModelProviderFamily.textMaxEnt,
            SentimentModelProviderFamily.transformerCoreML
        ]
        let computeSummary = orderedFamilies
            .compactMap { family -> String? in
                guard let units = coreMLComputeUnits[family.rawValue] else { return nil }
                return "\(family.rawValue)=\(units)"
            }
            .joined(separator: " ")
        return "hardware=\(hardwareClass) metal=\(hasMetalGPU) ane=\(hasAppleNeuralEngine) \(computeSummary)"
    }

    private static func computeUnitsLabel(_ units: MLComputeUnits) -> String {
        switch units {
        case .cpuOnly:
            return "cpuOnly"
        case .cpuAndGPU:
            return "cpuAndGPU"
        case .cpuAndNeuralEngine:
            return "cpuAndNeuralEngine"
        case .all:
            return "all"
        @unknown default:
            return "unknown"
        }
    }
}

struct TopicBenchmarkReportSnapshot: Codable {
    let corpusID: String
    let corpusKind: TopicBenchmarkCorpusKind
    let strategy: String
    let purity: Double
    let requiredPurity: Double
    let themeRecall: Double
    let baselineThemeRecall: Double
    let nonOutlierClusterCount: Int
    let durationMs: Double
    let maxDurationMs: Double
    let warnings: [String]
}

struct TopicBenchmarkSnapshotBundle: Codable {
    let generatedAt: String
    let hardware: TopicBenchmarkHardwareProfile
    let reports: [TopicBenchmarkReportSnapshot]
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

enum TopicBenchmarkReporter {
    static func snapshot(
        corpus: TopicBenchmarkCorpus,
        report: TopicBenchmarkReport
    ) -> TopicBenchmarkReportSnapshot {
        TopicBenchmarkReportSnapshot(
            corpusID: corpus.id,
            corpusKind: corpus.kind,
            strategy: report.strategy.rawValue,
            purity: report.purity,
            requiredPurity: corpus.baselinePurity + corpus.requiredPurityLift,
            themeRecall: report.themeRecall,
            baselineThemeRecall: corpus.baselineThemeRecall,
            nonOutlierClusterCount: report.nonOutlierClusterCount,
            durationMs: report.durationMs,
            maxDurationMs: corpus.maxDurationMs,
            warnings: report.warnings
        )
    }

    static func writeSnapshots(
        _ snapshots: [TopicBenchmarkReportSnapshot],
        hardware: TopicBenchmarkHardwareProfile = .current(),
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let formatter = ISO8601DateFormatter()
        let bundle = TopicBenchmarkSnapshotBundle(
            generatedAt: formatter.string(from: Date()),
            hardware: hardware,
            reports: snapshots
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }
}
