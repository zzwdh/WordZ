import CryptoKit
import Foundation
import XCTest
@testable import WordZWorkspaceCore

final class UserBenchmarkTests: XCTestCase {
    func testRunFixedFixtureBenchmarkForRoadmapBaseline() async throws {
        let runner = UserBenchmarkRunner()
        let report = try await runner.runRepeated(
            inputURL: fixedFixtureBenchmarkURL,
            options: UserBenchmarkOptions(
                buildConfiguration: roadmapBaselineBuildConfiguration,
                minTopicSize: 2,
                runTopics: true,
                runSentiment: true,
                runKWIC: true,
                sentimentUnit: .sentence,
                sentimentBackend: .lexicon,
                repeatCount: 3
            ),
            checkpointURL: fixedFixtureBenchmarkOutputURL
        )
        try report.write(to: fixedFixtureBenchmarkOutputURL)

        XCTAssertEqual(report.status, "ok")
        XCTAssertEqual(report.summary?.runCount, 3)
        XCTAssertEqual(report.summary?.successfulRunCount, 3)
        XCTAssertNotNil(report.summary?.totalDurationMs?.p50)
        XCTAssertNotNil(report.summary?.totalDurationMs?.p95)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixedFixtureBenchmarkOutputURL.path))
    }

    func testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline() async throws {
        let inputURL = try prepareReferenceCorpusBenchmarkInput(maxFileCount: 12)
        let runner = UserBenchmarkRunner()
        let report = try await runner.runRepeated(
            inputURL: inputURL,
            options: UserBenchmarkOptions(
                buildConfiguration: roadmapBaselineBuildConfiguration,
                minTopicSize: 2,
                runTopics: true,
                runSentiment: true,
                runKWIC: true,
                sentimentUnit: .sentence,
                sentimentBackend: .lexicon,
                repeatCount: 3
            ),
            checkpointURL: referenceCorpusBenchmarkOutputURL
        )
        try report.write(to: referenceCorpusBenchmarkOutputURL)

        XCTAssertEqual(report.status, "ok")
        XCTAssertEqual(report.summary?.runCount, 3)
        XCTAssertEqual(report.summary?.successfulRunCount, 3)
        XCTAssertGreaterThan(report.input.characterCount, 30_000)
        XCTAssertNotNil(report.summary?.totalDurationMs?.p50)
        XCTAssertNotNil(report.summary?.totalDurationMs?.p95)
        XCTAssertNotNil(report.summary?.topicsDurationMs?.p95)
        XCTAssertNotNil(report.summary?.sentimentDurationMs?.p95)
        XCTAssertNotNil(report.summary?.kwicDurationMs?.p95)
        XCTAssertTrue(FileManager.default.fileExists(atPath: referenceCorpusBenchmarkOutputURL.path))
    }

    func testRunUserProvidedBenchmark() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let filePath = environment["WORDZ_USER_BENCHMARK_FILE"],
              !filePath.isEmpty else {
            throw XCTSkip("Set WORDZ_USER_BENCHMARK_FILE to run the manual user benchmark.")
        }

        let outputPath = environment["WORDZ_USER_BENCHMARK_OUTPUT"]
            ?? defaultOutputPath
        let minTopicSize = max(
            1,
            Int(environment["WORDZ_USER_BENCHMARK_MIN_TOPIC_SIZE"] ?? "") ?? 2
        )
        let sentimentUnit = try Self.sentimentUnit(
            rawValue: environment["WORDZ_USER_BENCHMARK_SENTIMENT_UNIT"]
        )
        let sentimentBackend = try Self.sentimentBackend(
            rawValue: environment["WORDZ_USER_BENCHMARK_SENTIMENT_BACKEND"]
        )
        let repeatCount = max(
            1,
            Int(environment["WORDZ_USER_BENCHMARK_REPEAT_COUNT"] ?? "") ?? 1
        )
        let options = UserBenchmarkOptions(
            buildConfiguration: environment["WORDZ_USER_BENCHMARK_BUILD_CONFIGURATION"] ?? "debug",
            minTopicSize: minTopicSize,
            runTopics: environment["WORDZ_USER_BENCHMARK_RUN_TOPICS"] != "0",
            runSentiment: environment["WORDZ_USER_BENCHMARK_RUN_SENTIMENT"] != "0",
            runKWIC: environment["WORDZ_USER_BENCHMARK_RUN_KWIC"] != "0",
            sentimentUnit: sentimentUnit,
            sentimentBackend: sentimentBackend,
            repeatCount: repeatCount
        )

        let runner = UserBenchmarkRunner()
        let outputURL = URL(fileURLWithPath: outputPath)
        let report = try await runner.runRepeated(
            inputURL: URL(fileURLWithPath: filePath),
            options: options,
            checkpointURL: outputURL
        )
        try report.write(to: outputURL)
    }

    private var defaultOutputPath: String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("reports", isDirectory: true)
            .appendingPathComponent("user-benchmark.json")
            .path
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var roadmapBaselineOutputDirectoryURL: URL {
        let environment = ProcessInfo.processInfo.environment
        if let outputPath = environment["WORDZ_1_4_BASELINE_OUTPUT_DIR"],
           !outputPath.isEmpty {
            return URL(fileURLWithPath: outputPath, isDirectory: true)
        }
        return repositoryRootURL
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("reports", isDirectory: true)
            .appendingPathComponent("1.4.0", isDirectory: true)
    }

    private var roadmapBaselineBuildConfiguration: String {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["WORDZ_1_4_BASELINE_BUILD_CONFIGURATION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
           !value.isEmpty {
            return value
        }
        return "debug"
    }

    private var fixedFixtureBenchmarkURL: URL {
        repositoryRootURL
            .appendingPathComponent("Tests", isDirectory: true)
            .appendingPathComponent("WordZMacTests", isDirectory: true)
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("UserBenchmark", isDirectory: true)
            .appendingPathComponent("user-benchmark-sample.txt")
    }

    private var fixedFixtureBenchmarkOutputURL: URL {
        roadmapBaselineOutputDirectoryURL
            .appendingPathComponent("user-benchmark.json")
    }

    private var bundledReferenceCorpusDirectoryURL: URL {
        repositoryRootURL
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("WordZAnalysis", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("ReferenceCorpora", isDirectory: true)
            .appendingPathComponent("ToRCH2014_SEG_UTF-8", isDirectory: true)
    }

    private var referenceCorpusBenchmarkInputURL: URL {
        roadmapBaselineOutputDirectoryURL
            .appendingPathComponent("reference-benchmark-corpus.txt")
    }

    private var referenceCorpusBenchmarkOutputURL: URL {
        roadmapBaselineOutputDirectoryURL
            .appendingPathComponent("user-benchmark-reference.json")
    }

    private func prepareReferenceCorpusBenchmarkInput(maxFileCount: Int) throws -> URL {
        let fileManager = FileManager.default
        let fileURLs = try fileManager.contentsOfDirectory(
            at: bundledReferenceCorpusDirectoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "txt" }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        .prefix(maxFileCount)

        guard !fileURLs.isEmpty else {
            throw NSError(
                domain: "UserBenchmarkTests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "No bundled reference corpus files were found."]
            )
        }

        let text = try fileURLs
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .enumerated()
            .map { index, content in
                "# Reference segment \(index + 1)\n\(content.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
            .joined(separator: "\n\n")

        try fileManager.createDirectory(
            at: referenceCorpusBenchmarkInputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: referenceCorpusBenchmarkInputURL, atomically: true, encoding: .utf8)
        return referenceCorpusBenchmarkInputURL
    }

    private static func sentimentUnit(rawValue: String?) throws -> SentimentAnalysisUnit {
        let rawValue = rawValue ?? SentimentAnalysisUnit.sentence.rawValue
        guard let unit = SentimentAnalysisUnit(rawValue: rawValue),
              unit == .document || unit == .sentence else {
            throw NSError(
                domain: "UserBenchmarkTests",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "WORDZ_USER_BENCHMARK_SENTIMENT_UNIT must be document or sentence."
                ]
            )
        }
        return unit
    }

    private static func sentimentBackend(rawValue: String?) throws -> SentimentBackendKind {
        let rawValue = rawValue ?? SentimentBackendKind.lexicon.rawValue
        guard let backend = SentimentBackendKind(rawValue: rawValue) else {
            throw NSError(
                domain: "UserBenchmarkTests",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "WORDZ_USER_BENCHMARK_SENTIMENT_BACKEND must be lexicon or coreML."
                ]
            )
        }
        return backend
    }
}

private struct UserBenchmarkOptions: Codable, Equatable {
    let buildConfiguration: String
    let minTopicSize: Int
    let runTopics: Bool
    let runSentiment: Bool
    let runKWIC: Bool
    let sentimentUnit: SentimentAnalysisUnit
    let sentimentBackend: SentimentBackendKind
    let repeatCount: Int
}

private struct UserBenchmarkReport: Codable {
    let status: String
    let generatedAt: String
    let input: UserBenchmarkInputReport
    let options: UserBenchmarkOptions
    let hardware: UserBenchmarkHardwareReport
    let sentimentModelProviderCatalog: SentimentModelProviderCatalog?
    let stages: [UserBenchmarkStageReport]
    let stats: UserBenchmarkStatsReport?
    let topics: UserBenchmarkTopicsReport?
    let sentiment: UserBenchmarkSentimentReport?
    let kwic: UserBenchmarkKWICReport?
    let totalDurationMs: Double
    let runs: [UserBenchmarkRunReport]?
    let summary: UserBenchmarkSummaryReport?

    func write(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

private struct UserBenchmarkRunReport: Codable {
    let index: Int
    let status: String
    let stages: [UserBenchmarkStageReport]
    let stats: UserBenchmarkStatsReport?
    let topics: UserBenchmarkTopicsReport?
    let sentiment: UserBenchmarkSentimentReport?
    let kwic: UserBenchmarkKWICReport?
    let totalDurationMs: Double
}

private struct UserBenchmarkSummaryReport: Codable {
    let runCount: Int
    let successfulRunCount: Int
    let totalDurationMs: UserBenchmarkDurationSummary?
    let topicsDurationMs: UserBenchmarkDurationSummary?
    let sentimentDurationMs: UserBenchmarkDurationSummary?
    let kwicDurationMs: UserBenchmarkDurationSummary?
}

private struct UserBenchmarkDurationSummary: Codable {
    let median: Double
    let p50: Double
    let p95: Double
    let min: Double
    let max: Double
}

private struct UserBenchmarkInputReport: Codable {
    let fileName: String
    let fileExtension: String
    let byteCount: Int
    let characterCount: Int
    let lineCount: Int
    let sha256: String
}

private struct UserBenchmarkHardwareReport: Codable {
    let summaryLine: String
    let hardwareClass: String
    let hasMetalGPU: Bool
    let hasAppleNeuralEngine: Bool
    let processorCount: Int
    let activeProcessorCount: Int
    let physicalMemoryMB: Int
    let lowPowerModeEnabled: Bool
    let thermalProfile: String
    let operatingSystem: String
    let coreMLComputeUnits: [String: String]
}

private struct UserBenchmarkStageReport: Codable {
    let name: String
    let durationMs: Double
    let status: String
    let detail: String?
}

private struct UserBenchmarkStatsReport: Codable {
    let tokenCount: Int
    let typeCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let ttr: Double
    let sttr: Double
}

private struct UserBenchmarkTopicsReport: Codable {
    let status: String
    let durationMs: Double
    let progressStageDurationsMs: [String: Double]
    let clusteringStageDurationsMs: [String: Double]?
    let approximateCandidateEvaluationCount: Int?
    let approximateCoarseCandidateCounts: [Int]?
    let approximateRefinedCandidateCounts: [Int]?
    let approximateUsedTwoStageSearch: Bool?
    let provider: String?
    let providerTier: String?
    let strategy: String?
    let totalSegments: Int?
    let clusteredSegments: Int?
    let outlierCount: Int?
    let clusterCount: Int?
    let embeddingReductionApplied: Bool?
    let originalDimensions: Int?
    let reducedDimensions: Int?
    let explainedVariance: Double?
    let warningCount: Int?
    let error: String?

    static func running(
        durationMs: Double,
        progressStageDurationsMs: [String: Double]
    ) -> Self {
        Self(
            status: "running",
            durationMs: durationMs,
            progressStageDurationsMs: progressStageDurationsMs,
            clusteringStageDurationsMs: nil,
            approximateCandidateEvaluationCount: nil,
            approximateCoarseCandidateCounts: nil,
            approximateRefinedCandidateCounts: nil,
            approximateUsedTwoStageSearch: nil,
            provider: nil,
            providerTier: nil,
            strategy: nil,
            totalSegments: nil,
            clusteredSegments: nil,
            outlierCount: nil,
            clusterCount: nil,
            embeddingReductionApplied: nil,
            originalDimensions: nil,
            reducedDimensions: nil,
            explainedVariance: nil,
            warningCount: nil,
            error: nil
        )
    }
}

private struct UserBenchmarkSentimentReport: Codable {
    let status: String
    let durationMs: Double
    let backendKind: String?
    let providerID: String?
    let providerFamily: String?
    let modelInputKind: String?
    let coreMLComputeUnits: String?
    let rowCount: Int?
    let positiveCount: Int?
    let neutralCount: Int?
    let negativeCount: Int?
    let averageNetScore: Double?
    let inferencePaths: [String: Int]
    let error: String?
}

private struct UserBenchmarkKWICReport: Codable {
    let status: String
    let durationMs: Double
    let keywordRank: Int?
    let keywordCount: Int?
    let keywordSHA256: String?
    let rowCount: Int?
    let error: String?
}

private final class UserBenchmarkTopicProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stageStartedAt: Date?
    private var currentStage: TopicAnalysisProgress.Stage?
    private var stageDurations: [String: Double] = [:]

    func record(_ progress: TopicAnalysisProgress) {
        lock.lock()
        defer { lock.unlock() }

        let now = Date()
        if currentStage != progress.stage {
            closeCurrentStage(at: now)
            currentStage = progress.stage
            stageStartedAt = now
        }
    }

    func finish() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }

        closeCurrentStage(at: Date())
        return stageDurations
    }

    func snapshot() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = stageDurations
        if let currentStage, let stageStartedAt {
            snapshot[currentStage.rawValue, default: 0] += Date().timeIntervalSince(stageStartedAt) * 1000
        }
        return snapshot
    }

    private func closeCurrentStage(at now: Date) {
        guard let currentStage, let stageStartedAt else { return }
        stageDurations[currentStage.rawValue, default: 0] += now.timeIntervalSince(stageStartedAt) * 1000
    }
}

private final class UserBenchmarkProgressCheckpointWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL?
    private let totalStartedAt: Date
    private let input: UserBenchmarkInputReport
    private let options: UserBenchmarkOptions
    private let hardware: UserBenchmarkHardwareReport
    private let sentimentModelProviderCatalog: SentimentModelProviderCatalog?

    init(
        url: URL?,
        totalStartedAt: Date,
        input: UserBenchmarkInputReport,
        options: UserBenchmarkOptions,
        hardware: UserBenchmarkHardwareReport,
        sentimentModelProviderCatalog: SentimentModelProviderCatalog?
    ) {
        self.url = url
        self.totalStartedAt = totalStartedAt
        self.input = input
        self.options = options
        self.hardware = hardware
        self.sentimentModelProviderCatalog = sentimentModelProviderCatalog
    }

    func write(
        status: String,
        stages: [UserBenchmarkStageReport],
        stats: UserBenchmarkStatsReport?,
        topics: UserBenchmarkTopicsReport?,
        sentiment: UserBenchmarkSentimentReport?,
        kwic: UserBenchmarkKWICReport?
    ) {
        guard let url else { return }

        lock.lock()
        defer { lock.unlock() }
        let report = UserBenchmarkReport(
            status: status,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            input: input,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: sentimentModelProviderCatalog,
            stages: stages,
            stats: stats,
            topics: topics,
            sentiment: sentiment,
            kwic: kwic,
            totalDurationMs: Date().timeIntervalSince(totalStartedAt) * 1000,
            runs: nil,
            summary: nil
        )
        try? report.write(to: url)
    }
}

private final class UserBenchmarkRunner {
    func runRepeated(
        inputURL: URL,
        options: UserBenchmarkOptions,
        checkpointURL: URL? = nil
    ) async throws -> UserBenchmarkReport {
        guard options.repeatCount > 1 else {
            return try await run(
                inputURL: inputURL,
                options: options,
                checkpointURL: checkpointURL
            )
        }

        var runs: [UserBenchmarkRunReport] = []
        var latestReport: UserBenchmarkReport?
        for index in 1...options.repeatCount {
            let report = try await run(
                inputURL: inputURL,
                options: options,
                checkpointURL: checkpointURL
            )
            latestReport = report
            runs.append(
                UserBenchmarkRunReport(
                    index: index,
                    status: report.status,
                    stages: report.stages,
                    stats: report.stats,
                    topics: report.topics,
                    sentiment: report.sentiment,
                    kwic: report.kwic,
                    totalDurationMs: report.totalDurationMs
                )
            )
            if let checkpointURL {
                let aggregate = aggregateReport(
                    from: report,
                    runs: runs,
                    status: index == options.repeatCount ? "ok" : "running"
                )
                try aggregate.write(to: checkpointURL)
            }
        }

        guard let latestReport else {
            throw NSError(
                domain: "UserBenchmarkTests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Benchmark repeat count produced no runs."]
            )
        }
        return aggregateReport(from: latestReport, runs: runs, status: "ok")
    }

    func run(
        inputURL: URL,
        options: UserBenchmarkOptions,
        checkpointURL: URL? = nil
    ) async throws -> UserBenchmarkReport {
        let totalStartedAt = Date()
        var stages: [UserBenchmarkStageReport] = []

        let readStartedAt = Date()
        let data = try Data(contentsOf: inputURL)
        stages.append(
            stageReport(
                name: "readFile",
                startedAt: readStartedAt,
                status: "ok",
                detail: nil
            )
        )

        let decodeStartedAt = Date()
        let text = String(decoding: data, as: UTF8.self)
        stages.append(
            stageReport(
                name: "decodeText",
                startedAt: decodeStartedAt,
                status: "ok",
                detail: "utf8"
            )
        )

        let inputReport = UserBenchmarkInputReport(
            fileName: inputURL.lastPathComponent,
            fileExtension: inputURL.pathExtension,
            byteCount: data.count,
            characterCount: text.count,
            lineCount: text.split(whereSeparator: \.isNewline).count,
            sha256: sha256Hex(data)
        )
        let hardware = hardwareReport()
        let providerCatalog = try? SentimentModelManager().providerCatalog()
        let progressCheckpointWriter = UserBenchmarkProgressCheckpointWriter(
            url: checkpointURL,
            totalStartedAt: totalStartedAt,
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog
        )
        try writeCheckpoint(
            to: checkpointURL,
            status: "running",
            totalStartedAt: totalStartedAt,
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog,
            stages: stages,
            stats: nil,
            topics: nil,
            sentiment: nil,
            kwic: nil
        )

        let engine = NativeAnalysisEngine()
        let documentKey = DocumentCacheKey(text: text)

        let parseStartedAt = Date()
        let index = engine.indexedDocument(for: text, documentKey: documentKey)
        stages.append(
            stageReport(
                name: "parseDocument",
                startedAt: parseStartedAt,
                status: "ok",
                detail: nil
            )
        )

        let statsStartedAt = Date()
        let stats = engine.runStats(text: text, documentKey: documentKey)
        let statsReport = UserBenchmarkStatsReport(
            tokenCount: stats.tokenCount,
            typeCount: stats.typeCount,
            sentenceCount: index.sentenceCount,
            paragraphCount: index.paragraphCount,
            ttr: stats.ttr,
            sttr: stats.sttr
        )
        let statsStage = stageReport(
            name: "stats",
            startedAt: statsStartedAt,
            status: "ok",
            detail: nil
        )
        stages.append(statsStage)
        try writeCheckpoint(
            to: checkpointURL,
            status: "running",
            totalStartedAt: totalStartedAt,
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog,
            stages: stages,
            stats: statsReport,
            topics: nil,
            sentiment: nil,
            kwic: nil
        )

        let topicsReport: UserBenchmarkTopicsReport?
        if options.runTopics {
            let topicsStartedAt = Date()
            stages.append(
                UserBenchmarkStageReport(
                    name: "topics",
                    durationMs: 0,
                    status: "running",
                    detail: nil
                )
            )
            try writeCheckpoint(
                to: checkpointURL,
                status: "running",
                totalStartedAt: totalStartedAt,
                input: inputReport,
                options: options,
                hardware: hardware,
                sentimentModelProviderCatalog: providerCatalog,
                stages: stages,
                stats: statsReport,
                topics: nil,
                sentiment: nil,
                kwic: nil
            )
            let topicRunningStages = stages
            topicsReport = await runTopics(
                text: text,
                minTopicSize: options.minTopicSize,
                startedAt: topicsStartedAt,
                progressCheckpoint: { topicsSnapshot in
                    progressCheckpointWriter.write(
                        status: "running",
                        stages: topicRunningStages,
                        stats: statsReport,
                        topics: topicsSnapshot,
                        sentiment: nil,
                        kwic: nil
                    )
                }
            )
            stages[stages.count - 1] = UserBenchmarkStageReport(
                name: "topics",
                durationMs: topicsReport?.durationMs ?? elapsedMilliseconds(since: topicsStartedAt),
                status: topicsReport?.status ?? "error",
                detail: topicsReport?.error
            )
        } else {
            topicsReport = nil
        }
        try writeCheckpoint(
            to: checkpointURL,
            status: "running",
            totalStartedAt: totalStartedAt,
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog,
            stages: stages,
            stats: statsReport,
            topics: topicsReport,
            sentiment: nil,
            kwic: nil
        )

        let sentimentReport: UserBenchmarkSentimentReport?
        if options.runSentiment {
            let sentimentStartedAt = Date()
            stages.append(
                UserBenchmarkStageReport(
                    name: "sentiment",
                    durationMs: 0,
                    status: "running",
                    detail: nil
                )
            )
            try writeCheckpoint(
                to: checkpointURL,
                status: "running",
                totalStartedAt: totalStartedAt,
                input: inputReport,
                options: options,
                hardware: hardware,
                sentimentModelProviderCatalog: providerCatalog,
                stages: stages,
                stats: statsReport,
                topics: topicsReport,
                sentiment: nil,
                kwic: nil
            )
            sentimentReport = runSentiment(
                text: text,
                engine: engine,
                options: options,
                startedAt: sentimentStartedAt
            )
            stages[stages.count - 1] = UserBenchmarkStageReport(
                name: "sentiment",
                durationMs: sentimentReport?.durationMs ?? elapsedMilliseconds(since: sentimentStartedAt),
                status: sentimentReport?.status ?? "error",
                detail: sentimentReport?.error
            )
        } else {
            sentimentReport = nil
        }
        try writeCheckpoint(
            to: checkpointURL,
            status: "running",
            totalStartedAt: totalStartedAt,
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog,
            stages: stages,
            stats: statsReport,
            topics: topicsReport,
            sentiment: sentimentReport,
            kwic: nil
        )

        let kwicReport: UserBenchmarkKWICReport?
        if options.runKWIC {
            let kwicStartedAt = Date()
            stages.append(
                UserBenchmarkStageReport(
                    name: "kwicSmoke",
                    durationMs: 0,
                    status: "running",
                    detail: nil
                )
            )
            try writeCheckpoint(
                to: checkpointURL,
                status: "running",
                totalStartedAt: totalStartedAt,
                input: inputReport,
                options: options,
                hardware: hardware,
                sentimentModelProviderCatalog: providerCatalog,
                stages: stages,
                stats: statsReport,
                topics: topicsReport,
                sentiment: sentimentReport,
                kwic: nil
            )
            kwicReport = runKWICSmoke(
                text: text,
                stats: stats,
                engine: engine,
                documentKey: documentKey,
                startedAt: kwicStartedAt
            )
            stages[stages.count - 1] = UserBenchmarkStageReport(
                name: "kwicSmoke",
                durationMs: kwicReport?.durationMs ?? elapsedMilliseconds(since: kwicStartedAt),
                status: kwicReport?.status ?? "error",
                detail: kwicReport?.error
            )
        } else {
            kwicReport = nil
        }

        return UserBenchmarkReport(
            status: "ok",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            input: inputReport,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: providerCatalog,
            stages: stages,
            stats: statsReport,
            topics: topicsReport,
            sentiment: sentimentReport,
            kwic: kwicReport,
            totalDurationMs: elapsedMilliseconds(since: totalStartedAt),
            runs: nil,
            summary: nil
        )
    }

    private func runTopics(
        text: String,
        minTopicSize: Int,
        startedAt: Date,
        progressCheckpoint: @Sendable @escaping (UserBenchmarkTopicsReport) -> Void = { _ in }
    ) async -> UserBenchmarkTopicsReport {
        let recorder = UserBenchmarkTopicProgressRecorder()
        do {
            let result = try await NativeTopicEngine().analyze(
                text: text,
                options: TopicAnalysisOptions(minTopicSize: minTopicSize),
                progress: { progress in
                    recorder.record(progress)
                    progressCheckpoint(
                        .running(
                            durationMs: Date().timeIntervalSince(startedAt) * 1000,
                            progressStageDurationsMs: recorder.snapshot()
                        )
                    )
                }
            )
            let reduction = result.diagnostics.embeddingReduction
            let approximateClustering = result.diagnostics.approximateClustering
            return UserBenchmarkTopicsReport(
                status: "ok",
                durationMs: elapsedMilliseconds(since: startedAt),
                progressStageDurationsMs: recorder.finish(),
                clusteringStageDurationsMs: approximateClustering?.stageDurationsMs,
                approximateCandidateEvaluationCount: approximateClustering?.candidateEvaluationCount,
                approximateCoarseCandidateCounts: approximateClustering?.coarseCandidateCounts,
                approximateRefinedCandidateCounts: approximateClustering?.refinedCandidateCounts,
                approximateUsedTwoStageSearch: approximateClustering?.usedTwoStageSearch,
                provider: result.modelProvider,
                providerTier: result.diagnostics.providerTier.rawValue,
                strategy: result.diagnostics.clusteringStrategy.rawValue,
                totalSegments: result.totalSegments,
                clusteredSegments: result.clusteredSegments,
                outlierCount: result.outlierCount,
                clusterCount: result.clusters.count,
                embeddingReductionApplied: reduction.applied,
                originalDimensions: reduction.originalDimensions,
                reducedDimensions: reduction.reducedDimensions,
                explainedVariance: reduction.explainedVariance,
                warningCount: result.warnings.count,
                error: nil
            )
        } catch {
            return UserBenchmarkTopicsReport(
                status: "error",
                durationMs: elapsedMilliseconds(since: startedAt),
                progressStageDurationsMs: recorder.finish(),
                clusteringStageDurationsMs: nil,
                approximateCandidateEvaluationCount: nil,
                approximateCoarseCandidateCounts: nil,
                approximateRefinedCandidateCounts: nil,
                approximateUsedTwoStageSearch: nil,
                provider: nil,
                providerTier: nil,
                strategy: nil,
                totalSegments: nil,
                clusteredSegments: nil,
                outlierCount: nil,
                clusterCount: nil,
                embeddingReductionApplied: nil,
                originalDimensions: nil,
                reducedDimensions: nil,
                explainedVariance: nil,
                warningCount: nil,
                error: String(describing: error)
            )
        }
    }

    private func runSentiment(
        text: String,
        engine: NativeAnalysisEngine,
        options: UserBenchmarkOptions,
        startedAt: Date
    ) -> UserBenchmarkSentimentReport {
        let request = SentimentRunRequest(
            source: .openedCorpus,
            unit: options.sentimentUnit,
            contextBasis: .visibleContext,
            thresholds: SentimentThresholdPreset.conservative.thresholds,
            texts: [
                SentimentInputText(
                    id: "user-file",
                    sourceTitle: "User File",
                    text: text
                )
            ],
            backend: options.sentimentBackend
        )
        let result = engine.runSentiment(request)
        let firstDiagnostics = result.rows.first?.diagnostics
        let inferencePaths = Dictionary(
            grouping: result.rows.compactMap { $0.diagnostics.inferencePath?.rawValue },
            by: { $0 }
        )
        .mapValues(\.count)

        return UserBenchmarkSentimentReport(
            status: "ok",
            durationMs: elapsedMilliseconds(since: startedAt),
            backendKind: result.backendKind.rawValue,
            providerID: result.providerID,
            providerFamily: result.providerFamily?.rawValue,
            modelInputKind: firstDiagnostics?.modelInputKind?.rawValue,
            coreMLComputeUnits: firstDiagnostics?.coreMLComputeUnits,
            rowCount: result.rows.count,
            positiveCount: result.overallSummary.positiveCount,
            neutralCount: result.overallSummary.neutralCount,
            negativeCount: result.overallSummary.negativeCount,
            averageNetScore: result.overallSummary.averageNetScore,
            inferencePaths: inferencePaths,
            error: nil
        )
    }

    private func runKWICSmoke(
        text: String,
        stats: StatsResult,
        engine: NativeAnalysisEngine,
        documentKey: DocumentCacheKey,
        startedAt: Date
    ) -> UserBenchmarkKWICReport {
        guard let candidate = stats.frequencyRows.first(where: { $0.word.count > 1 && $0.count > 1 }) else {
            return UserBenchmarkKWICReport(
                status: "skipped",
                durationMs: elapsedMilliseconds(since: startedAt),
                keywordRank: nil,
                keywordCount: nil,
                keywordSHA256: nil,
                rowCount: nil,
                error: "No repeated token candidate."
            )
        }

        do {
            let result = try engine.runKWIC(
                text: text,
                keyword: candidate.word,
                leftWindow: 5,
                rightWindow: 5,
                searchOptions: .default,
                documentKey: documentKey
            )
            return UserBenchmarkKWICReport(
                status: "ok",
                durationMs: elapsedMilliseconds(since: startedAt),
                keywordRank: candidate.rank,
                keywordCount: candidate.count,
                keywordSHA256: sha256Hex(Data(candidate.word.utf8)),
                rowCount: result.rows.count,
                error: nil
            )
        } catch {
            return UserBenchmarkKWICReport(
                status: "error",
                durationMs: elapsedMilliseconds(since: startedAt),
                keywordRank: candidate.rank,
                keywordCount: candidate.count,
                keywordSHA256: sha256Hex(Data(candidate.word.utf8)),
                rowCount: nil,
                error: String(describing: error)
            )
        }
    }

    private func hardwareReport() -> UserBenchmarkHardwareReport {
        let profile = HardwareAccelerationPolicy.currentHardwareProfile()
        let families: [SentimentModelProviderFamily] = [
            .embeddingLogReg,
            .textMaxEnt,
            .transformerCoreML
        ]
        let computeUnits = Dictionary(uniqueKeysWithValues: families.map { family in
            (
                family.rawValue,
                HardwareAccelerationPolicy.coreMLComputeUnitsLabel(
                    for: family,
                    profile: profile
                )
            )
        })

        return UserBenchmarkHardwareReport(
            summaryLine: profile.summaryLine,
            hardwareClass: profile.acceleration.hardwareClass.rawValue,
            hasMetalGPU: profile.acceleration.hasMetalGPU,
            hasAppleNeuralEngine: profile.acceleration.hasAppleNeuralEngine,
            processorCount: profile.processorCount,
            activeProcessorCount: profile.activeProcessorCount,
            physicalMemoryMB: profile.physicalMemoryMegabytes,
            lowPowerModeEnabled: profile.lowPowerModeEnabled,
            thermalProfile: profile.thermalProfile.rawValue,
            operatingSystem: profile.operatingSystem.displayVersion,
            coreMLComputeUnits: computeUnits
        )
    }

    private func aggregateReport(
        from base: UserBenchmarkReport,
        runs: [UserBenchmarkRunReport],
        status: String
    ) -> UserBenchmarkReport {
        UserBenchmarkReport(
            status: status,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            input: base.input,
            options: base.options,
            hardware: base.hardware,
            sentimentModelProviderCatalog: base.sentimentModelProviderCatalog,
            stages: base.stages,
            stats: base.stats,
            topics: base.topics,
            sentiment: base.sentiment,
            kwic: base.kwic,
            totalDurationMs: base.totalDurationMs,
            runs: runs,
            summary: summaryReport(for: runs)
        )
    }

    private func summaryReport(for runs: [UserBenchmarkRunReport]) -> UserBenchmarkSummaryReport {
        let successfulRuns = runs.filter { $0.status == "ok" }
        return UserBenchmarkSummaryReport(
            runCount: runs.count,
            successfulRunCount: successfulRuns.count,
            totalDurationMs: durationSummary(successfulRuns.map(\.totalDurationMs)),
            topicsDurationMs: durationSummary(successfulRuns.compactMap { $0.topics?.durationMs }),
            sentimentDurationMs: durationSummary(successfulRuns.compactMap { $0.sentiment?.durationMs }),
            kwicDurationMs: durationSummary(successfulRuns.compactMap { $0.kwic?.durationMs })
        )
    }

    private func durationSummary(_ values: [Double]) -> UserBenchmarkDurationSummary? {
        guard !values.isEmpty else { return nil }

        let sorted = values.sorted()
        let midpoint = sorted.count / 2
        let median: Double
        if sorted.count.isMultiple(of: 2) {
            median = (sorted[midpoint - 1] + sorted[midpoint]) / 2
        } else {
            median = sorted[midpoint]
        }
        return UserBenchmarkDurationSummary(
            median: median,
            p50: percentile(sorted, 0.50),
            p95: percentile(sorted, 0.95),
            min: sorted.first ?? median,
            max: sorted.last ?? median
        )
    }

    private func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        guard let first = sortedValues.first else { return 0 }
        guard sortedValues.count > 1 else { return first }
        let clamped = min(max(percentile, 0), 1)
        let position = clamped * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        guard lowerIndex != upperIndex else {
            return sortedValues[lowerIndex]
        }
        let lower = sortedValues[lowerIndex]
        let upper = sortedValues[upperIndex]
        let weight = position - Double(lowerIndex)
        return lower + ((upper - lower) * weight)
    }

    private func writeCheckpoint(
        to url: URL?,
        status: String,
        totalStartedAt: Date,
        input: UserBenchmarkInputReport,
        options: UserBenchmarkOptions,
        hardware: UserBenchmarkHardwareReport,
        sentimentModelProviderCatalog: SentimentModelProviderCatalog?,
        stages: [UserBenchmarkStageReport],
        stats: UserBenchmarkStatsReport?,
        topics: UserBenchmarkTopicsReport?,
        sentiment: UserBenchmarkSentimentReport?,
        kwic: UserBenchmarkKWICReport?
    ) throws {
        guard let url else { return }

        let report = UserBenchmarkReport(
            status: status,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            input: input,
            options: options,
            hardware: hardware,
            sentimentModelProviderCatalog: sentimentModelProviderCatalog,
            stages: stages,
            stats: stats,
            topics: topics,
            sentiment: sentiment,
            kwic: kwic,
            totalDurationMs: elapsedMilliseconds(since: totalStartedAt),
            runs: nil,
            summary: nil
        )
        try report.write(to: url)
    }

    private func stageReport(
        name: String,
        startedAt: Date,
        status: String,
        detail: String?
    ) -> UserBenchmarkStageReport {
        UserBenchmarkStageReport(
            name: name,
            durationMs: elapsedMilliseconds(since: startedAt),
            status: status,
            detail: detail
        )
    }

    private func elapsedMilliseconds(since start: Date) -> Double {
        Date().timeIntervalSince(start) * 1000
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
