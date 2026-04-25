import Foundation
import XCTest
@testable import WordZWorkspaceCore

final class SentimentToolingTests: XCTestCase {
    func testGenerateSentimentGoldScriptRebuildsCuratedNewsManifest() throws {
        let temporaryDirectory = makeTemporaryDirectory(prefix: "wordz-sentiment-gold")
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let scriptURL = repositoryRootURL.appendingPathComponent("Scripts/generate-sentiment-gold.swift")
        let datasetURL = repositoryRootURL
            .appendingPathComponent("Tests/WordZMacTests/Fixtures/Sentiment/sentiment-gold-v3.json")
        let manifestURL = temporaryDirectory.appendingPathComponent("sentiment-gold-v3-manifest.json")

        try runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/swift"),
            arguments: [
                scriptURL.path,
                "--input", datasetURL.path,
                "--manifest", manifestURL.path,
                "--version", "v3"
            ]
        )

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(GeneratedGoldManifest.self, from: manifestData)

        XCTAssertEqual(manifest.version, "v3")
        XCTAssertEqual(manifest.totalExamples, 54)
        XCTAssertEqual(manifest.countsByDomain["news"], 54)
        XCTAssertEqual(manifest.countsByTag?["quoted"], 6)
        XCTAssertEqual(manifest.countsByTag?["reported"], 6)
        XCTAssertTrue(manifest.notes.contains("news-oriented benchmark"))
    }

    func testTrainSentimentModelWrapperWritesProfileAwareEvaluationAndStableManifest() throws {
        let temporaryDirectory = makeTemporaryDirectory(prefix: "wordz-sentiment-train")
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let datasetURL = temporaryDirectory.appendingPathComponent("mini-news-focused.json")
        let datasetManifestURL = temporaryDirectory.appendingPathComponent("mini-news-focused-manifest.json")
        let evaluationURL = temporaryDirectory.appendingPathComponent("evaluation.json")
        let modelManifestURL = temporaryDirectory.appendingPathComponent("SentimentModelManifest.json")
        let resourceDirectoryURL = temporaryDirectory.appendingPathComponent("Resources", isDirectory: true)

        try writeMiniNewsDataset(to: datasetURL)

        let scriptURL = repositoryRootURL.appendingPathComponent("Scripts/train-sentiment-model.sh")
        try runProcess(
            executableURL: URL(fileURLWithPath: "/bin/zsh"),
            arguments: [
                scriptURL.path,
                "--dataset-profile", "news-focused",
                "--dataset-path", datasetURL.path,
                "--dataset-manifest-path", datasetManifestURL.path,
                "--evaluation-output", evaluationURL.path,
                "--model-manifest-output", modelManifestURL.path,
                "--resource-dir", resourceDirectoryURL.path,
                "--no-sync-bundled-model",
                "--skip-benchmarks"
            ]
        )

        let evaluation = try JSONDecoder().decode(
            GeneratedEvaluationReport.self,
            from: Data(contentsOf: evaluationURL)
        )
        XCTAssertEqual(evaluation.datasetProfile, "news-focused")
        XCTAssertEqual(evaluation.evaluationTarget, "news-focused")
        XCTAssertEqual(evaluation.dataset, datasetURL.lastPathComponent)
        XCTAssertEqual(evaluation.testCount, 6)

        let modelManifest = try JSONDecoder().decode(
            GeneratedModelManifest.self,
            from: Data(contentsOf: modelManifestURL)
        )
        XCTAssertEqual(modelManifest.revision, "sentiment-model-pack-v2")
        XCTAssertEqual(modelManifest.providers.first?.revision, "coreml-sentiment-v2")

        let datasetManifest = try JSONDecoder().decode(
            GeneratedGoldManifest.self,
            from: Data(contentsOf: datasetManifestURL)
        )
        XCTAssertEqual(datasetManifest.version, "v3")
        XCTAssertEqual(datasetManifest.countsByDomain["news"], 18)
        XCTAssertEqual(datasetManifest.countsByTag?["reported"], 3)
    }

    func testPersistedReviewSampleCanBeAbsorbedIntoNewsBenchmarkRegressionExample() throws {
        let dataset = try SentimentGoldDataset.load(version: .v3)
        let benchmarkExample = try XCTUnwrap(
            dataset.first(where: { $0.tags.contains("reported") && $0.split == .test }),
            "Expected a reported news benchmark example."
        )

        let request = SentimentRunRequest(
            source: .pastedText,
            unit: .sentence,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: [
                SentimentInputText(
                    id: benchmarkExample.id,
                    sourceTitle: benchmarkExample.domain,
                    text: benchmarkExample.text
                )
            ],
            backend: .lexicon,
            domainPackID: .news
        )
        let result = NativeAnalysisEngine().runSentiment(request)
        let row = try XCTUnwrap(result.rows.first)
        let decision = reviewDecision(for: benchmarkExample.label)
        let reviewSample = SentimentReviewOverlaySupport.makeReviewSample(
            decision: decision,
            row: row,
            result: result,
            note: "Promote into news v3.1 regression set",
            timestamp: "2026-04-22T10:00:00Z"
        )

        let temporaryDirectory = makeTemporaryDirectory(prefix: "wordz-sentiment-review")
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let store = NativeCorpusStore(rootURL: temporaryDirectory)
        try store.ensureInitialized()
        _ = try store.saveSentimentReviewSample(reviewSample)
        let reloadedSamples = try store.listSentimentReviewSamples()
        let persistedSample = try XCTUnwrap(reloadedSamples.first)

        let presentation = SentimentReviewOverlaySupport.makePresentationResult(
            rawResult: result,
            reviewSamples: reloadedSamples
        )
        let effectiveRow = try XCTUnwrap(presentation.effectiveRows.first)
        let regressionExample = SentimentGoldExample(
            id: "review-regression-\(benchmarkExample.id)",
            split: .validation,
            domain: benchmarkExample.domain,
            label: effectiveRow.effectiveLabel,
            text: effectiveRow.rawRow.text,
            tags: benchmarkExample.tags
        )

        XCTAssertEqual(persistedSample.effectiveLabel, benchmarkExample.label)
        XCTAssertEqual(regressionExample.label, benchmarkExample.label)
        XCTAssertEqual(regressionExample.domain, "news")
        XCTAssertEqual(Set(regressionExample.tags), Set(benchmarkExample.tags))
        XCTAssertTrue(regressionExample.tags.contains("reported"))
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeTemporaryDirectory(prefix: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func runProcess(
        executableURL: URL,
        arguments: [String]
    ) throws {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let description = """
            Process failed: \(executableURL.path) \(arguments.joined(separator: " "))
            stdout:
            \(stdout)
            stderr:
            \(stderr)
            """
            throw NSError(
                domain: "SentimentToolingTests.ProcessFailure",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: description
                ]
            )
        }
    }

    private func writeMiniNewsDataset(to url: URL) throws {
        let examples = [
            ScriptGoldExample(id: "train-pos-1", split: "train", domain: "news", label: "positive", text: "Officials praised the strong recovery.", tags: ["commentary"]),
            ScriptGoldExample(id: "train-pos-2", split: "train", domain: "news", label: "positive", text: "Markets reacted positively after the encouraging report.", tags: ["stance"]),
            ScriptGoldExample(id: "train-neg-1", split: "train", domain: "news", label: "negative", text: "Officials warned of a worsening crisis.", tags: ["reported"]),
            ScriptGoldExample(id: "train-neg-2", split: "train", domain: "news", label: "negative", text: "The mayor faced intense criticism after the chaotic rollout.", tags: ["commentary"]),
            ScriptGoldExample(id: "train-neu-1", split: "train", domain: "news", label: "neutral", text: "According to court records, the hearing resumed before noon.", tags: ["procedural"]),
            ScriptGoldExample(id: "train-neu-2", split: "train", domain: "news", label: "neutral", text: "The agency issued the notice after the vote.", tags: ["procedural"]),
            ScriptGoldExample(id: "validation-pos-1", split: "validation", domain: "news", label: "positive", text: "\"A breakthrough,\" the minister said after the vote.", tags: ["quoted"]),
            ScriptGoldExample(id: "validation-neg-1", split: "validation", domain: "news", label: "negative", text: "Officials described the repairs as costly during the afternoon briefing.", tags: ["reported"]),
            ScriptGoldExample(id: "validation-neu-1", split: "validation", domain: "news", label: "neutral", text: "The filing was released before noon after the hearing.", tags: ["procedural"]),
            ScriptGoldExample(id: "validation-pos-2", split: "validation", domain: "news", label: "positive", text: "Residents welcomed the plan and praised the relief effort.", tags: ["commentary"]),
            ScriptGoldExample(id: "validation-neg-2", split: "validation", domain: "news", label: "negative", text: "\"A scandal,\" critics said as scrutiny intensified.", tags: ["quoted"]),
            ScriptGoldExample(id: "validation-neu-2", split: "validation", domain: "news", label: "neutral", text: "Court records show the notice was issued on Tuesday.", tags: ["procedural"]),
            ScriptGoldExample(id: "test-pos-1", split: "test", domain: "news", label: "positive", text: "Supporters hailed the proposal as a major breakthrough.", tags: ["stance"]),
            ScriptGoldExample(id: "test-pos-2", split: "test", domain: "news", label: "positive", text: "\"A relief,\" local leaders said after the briefing.", tags: ["quoted"]),
            ScriptGoldExample(id: "test-neg-1", split: "test", domain: "news", label: "negative", text: "The report warned of serious risks and a worsening decline.", tags: ["reported"]),
            ScriptGoldExample(id: "test-neg-2", split: "test", domain: "news", label: "negative", text: "Commentators called the policy chaotic and under fire.", tags: ["commentary"]),
            ScriptGoldExample(id: "test-neu-1", split: "test", domain: "news", label: "neutral", text: "The agency issued the statement before noon.", tags: ["procedural"]),
            ScriptGoldExample(id: "test-neu-2", split: "test", domain: "news", label: "neutral", text: "According to court records, the filing was released after the hearing.", tags: ["procedural"])
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(examples).write(to: url, options: .atomic)
    }

    private func reviewDecision(for label: SentimentLabel) -> SentimentReviewDecision {
        switch label {
        case .positive:
            return .overridePositive
        case .neutral:
            return .overrideNeutral
        case .negative:
            return .overrideNegative
        }
    }
}

private struct GeneratedGoldManifest: Decodable {
    let version: String
    let totalExamples: Int
    let countsByDomain: [String: Int]
    let countsByTag: [String: Int]?
    let notes: String
}

private struct GeneratedEvaluationReport: Decodable {
    let dataset: String
    let datasetProfile: String
    let evaluationTarget: String
    let testCount: Int
}

private struct GeneratedModelManifest: Decodable {
    let revision: String
    let providers: [GeneratedModelProvider]
}

private struct GeneratedModelProvider: Decodable {
    let revision: String
}

private struct ScriptGoldExample: Encodable {
    let id: String
    let split: String
    let domain: String
    let label: String
    let text: String
    let tags: [String]
}
