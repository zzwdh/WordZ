import Combine
import Foundation
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class LibraryPerformanceBaselineTests: XCTestCase {
    func testLibraryManagementViewModelAppliesInitialEmptyLibrarySnapshotOnce() {
        let viewModel = LibraryManagementViewModel()

        viewModel.applyBootstrap(.empty)

        XCTAssertEqual(viewModel.scene.librarySummary, "语料 0 · 文件夹 0")
        XCTAssertEqual(viewModel.scene.currentScopeSummary, "全部语料 · 0 条语料")

        var scenePublishCount = 0
        let sceneCancellable = viewModel.$scene.dropFirst().sink { _ in
            scenePublishCount += 1
        }
        defer {
            sceneCancellable.cancel()
        }

        viewModel.applyBootstrap(.empty)

        XCTAssertEqual(scenePublishCount, 0)
    }

    func testRunLibraryPerformanceBaselineForRoadmap() throws {
        let options = LibraryPerformanceBaselineOptions.fromEnvironment()
        let report = try LibraryPerformanceBaselineRunner().run(options: options)
        let outputURL = roadmapBaselineOutputDirectoryURL
            .appendingPathComponent("library-baseline.json")
        try report.write(to: outputURL)

        XCTAssertEqual(report.status, "ok")
        XCTAssertEqual(report.summary.runCount, options.repeatCount)
        XCTAssertEqual(report.summary.successfulRunCount, options.repeatCount)
        XCTAssertEqual(report.summary.importedCorpusCount, options.importCorpusCount * options.repeatCount)
        XCTAssertNotNil(report.summary.importDurationMs.p50)
        XCTAssertNotNil(report.summary.sceneOpenDurationMs.p95)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
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
}

private struct LibraryPerformanceBaselineOptions: Codable, Equatable {
    let repeatCount: Int
    let importCorpusCount: Int
    let generatedCharactersPerFile: Int
    let sceneCorpusCount: Int
    let sceneFolderCount: Int
    let sceneCorpusSetCount: Int
    let buildConfiguration: String

    static func fromEnvironment() -> Self {
        let environment = ProcessInfo.processInfo.environment
        return Self(
            repeatCount: max(1, Int(environment["WORDZ_1_4_LIBRARY_BASELINE_REPEAT_COUNT"] ?? "") ?? 3),
            importCorpusCount: max(1, Int(environment["WORDZ_1_4_LIBRARY_BASELINE_IMPORT_COUNT"] ?? "") ?? 24),
            generatedCharactersPerFile: max(
                256,
                Int(environment["WORDZ_1_4_LIBRARY_BASELINE_CHARACTERS_PER_FILE"] ?? "") ?? 1_200
            ),
            sceneCorpusCount: max(1, Int(environment["WORDZ_1_4_LIBRARY_BASELINE_SCENE_CORPUS_COUNT"] ?? "") ?? 1_200),
            sceneFolderCount: max(1, Int(environment["WORDZ_1_4_LIBRARY_BASELINE_SCENE_FOLDER_COUNT"] ?? "") ?? 32),
            sceneCorpusSetCount: max(0, Int(environment["WORDZ_1_4_LIBRARY_BASELINE_SCENE_SET_COUNT"] ?? "") ?? 24),
            buildConfiguration: environment["WORDZ_1_4_LIBRARY_BASELINE_BUILD_CONFIGURATION"] ?? "debug"
        )
    }
}

private struct LibraryPerformanceBaselineReport: Codable {
    let status: String
    let generatedAt: String
    let options: LibraryPerformanceBaselineOptions
    let hardware: LibraryPerformanceHardwareReport
    let input: LibraryPerformanceInputReport
    let runs: [LibraryPerformanceRunReport]
    let summary: LibraryPerformanceSummaryReport

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

private struct LibraryPerformanceInputReport: Codable {
    let generatedImportFileCount: Int
    let generatedCharactersPerFile: Int
    let generatedImportTotalCharacters: Int
    let sceneCorpusCount: Int
    let sceneFolderCount: Int
    let sceneCorpusSetCount: Int
}

private struct LibraryPerformanceHardwareReport: Codable {
    let processorCount: Int
    let activeProcessorCount: Int
    let physicalMemoryMB: Int
    let operatingSystem: String
    let lowPowerModeEnabled: Bool
    let thermalProfile: String
}

private struct LibraryPerformanceRunReport: Codable {
    let index: Int
    let status: String
    let initializeStoreDurationMs: Double
    let importDurationMs: Double
    let listLibraryDurationMs: Double
    let listLibrarySearchDurationMs: Double
    let sceneOpenDurationMs: Double
    let sceneRefreshDurationMs: Double
    let sceneSearchDurationMs: Double
    let sceneFolderSwitchDurationMs: Double
    let sceneSelectionDurationMs: Double
    let importedCorpusCount: Int
    let skippedCorpusCount: Int
    let listedCorpusCount: Int
    let searchResultCorpusCount: Int
    let sceneOpenSnapshot: LibrarySceneSnapshotReport
    let sceneSearchSnapshot: LibrarySceneSnapshotReport
    let sceneSelectionSnapshot: LibrarySceneSnapshotReport
}

private struct LibraryPerformanceSummaryReport: Codable {
    let runCount: Int
    let successfulRunCount: Int
    let initializeStoreDurationMs: LibraryDurationSummary
    let importDurationMs: LibraryDurationSummary
    let listLibraryDurationMs: LibraryDurationSummary
    let listLibrarySearchDurationMs: LibraryDurationSummary
    let sceneOpenDurationMs: LibraryDurationSummary
    let sceneRefreshDurationMs: LibraryDurationSummary
    let sceneSearchDurationMs: LibraryDurationSummary
    let sceneFolderSwitchDurationMs: LibraryDurationSummary
    let sceneSelectionDurationMs: LibraryDurationSummary
    let importedCorpusCount: Int
    let listedCorpusCount: Int
}

private struct LibraryDurationSummary: Codable {
    let median: Double?
    let p50: Double?
    let p95: Double?
    let min: Double?
    let max: Double?

    static let empty = LibraryDurationSummary(
        median: nil,
        p50: nil,
        p95: nil,
        min: nil,
        max: nil
    )
}

private struct LibrarySceneSnapshotReport: Codable {
    let visibleCorpusCount: Int
    let folderCount: Int
    let corpusSetCount: Int
    let selectedCorpusCount: Int
    let filterChipCount: Int
    let librarySummary: String
    let currentScopeSummary: String
}

@MainActor
private final class LibraryPerformanceBaselineRunner {
    func run(options: LibraryPerformanceBaselineOptions) throws -> LibraryPerformanceBaselineReport {
        let syntheticSceneSnapshot = makeSyntheticSceneSnapshot(options: options)
        var runs: [LibraryPerformanceRunReport] = []

        for index in 1...options.repeatCount {
            runs.append(
                try runOnce(
                    index: index,
                    options: options,
                    syntheticSceneSnapshot: syntheticSceneSnapshot
                )
            )
        }

        return LibraryPerformanceBaselineReport(
            status: "ok",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            options: options,
            hardware: hardwareReport(),
            input: LibraryPerformanceInputReport(
                generatedImportFileCount: options.importCorpusCount,
                generatedCharactersPerFile: options.generatedCharactersPerFile,
                generatedImportTotalCharacters: options.importCorpusCount * options.generatedCharactersPerFile,
                sceneCorpusCount: options.sceneCorpusCount,
                sceneFolderCount: options.sceneFolderCount,
                sceneCorpusSetCount: options.sceneCorpusSetCount
            ),
            runs: runs,
            summary: summary(from: runs)
        )
    }

    private func runOnce(
        index: Int,
        options: LibraryPerformanceBaselineOptions,
        syntheticSceneSnapshot: LibrarySnapshot
    ) throws -> LibraryPerformanceRunReport {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-library-baseline-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURLs = try writeGeneratedCorpusFiles(
            rootURL: rootURL.appendingPathComponent("sources", isDirectory: true),
            count: options.importCorpusCount,
            characterCount: options.generatedCharactersPerFile
        )

        let store = NativeCorpusStore(
            rootURL: rootURL.appendingPathComponent("store", isDirectory: true)
        )

        let initializeStartedAt = Date()
        try store.ensureInitialized()
        let initializeStoreDurationMs = elapsedMilliseconds(since: initializeStartedAt)

        let importStartedAt = Date()
        let importResult = try store.importCorpusPaths(
            sourceURLs.map(\.path),
            folderId: "",
            preserveHierarchy: false
        )
        let importDurationMs = elapsedMilliseconds(since: importStartedAt)

        let listStartedAt = Date()
        let listedSnapshot = try store.listLibrary(folderId: "all")
        let listLibraryDurationMs = elapsedMilliseconds(since: listStartedAt)

        let listSearchStartedAt = Date()
        let searchedSnapshot = try store.listLibrary(
            folderId: "all",
            metadataFilterState: .empty,
            searchQuery: "baseline"
        )
        let listLibrarySearchDurationMs = elapsedMilliseconds(since: listSearchStartedAt)

        let viewModel = LibraryManagementViewModel()

        let sceneOpenStartedAt = Date()
        viewModel.applyBootstrap(syntheticSceneSnapshot)
        let sceneOpenDurationMs = elapsedMilliseconds(since: sceneOpenStartedAt)
        let sceneOpenSnapshot = sceneReport(from: viewModel.scene)

        let sceneRefreshStartedAt = Date()
        viewModel.applyBootstrap(syntheticSceneSnapshot)
        let sceneRefreshDurationMs = elapsedMilliseconds(since: sceneRefreshStartedAt)

        let sceneSearchStartedAt = Date()
        viewModel.searchQuery = "tag-3"
        let sceneSearchDurationMs = elapsedMilliseconds(since: sceneSearchStartedAt)
        let sceneSearchSnapshot = sceneReport(from: viewModel.scene)

        let sceneFolderStartedAt = Date()
        viewModel.selectFolder("folder-\(min(7, max(options.sceneFolderCount - 1, 0)))")
        let sceneFolderSwitchDurationMs = elapsedMilliseconds(since: sceneFolderStartedAt)

        let selectedCorpusIDs = Set((0..<min(80, options.sceneCorpusCount)).map { "corpus-\($0)" })
        let sceneSelectionStartedAt = Date()
        viewModel.searchQuery = ""
        viewModel.selectCorpusIDs(selectedCorpusIDs)
        let sceneSelectionDurationMs = elapsedMilliseconds(since: sceneSelectionStartedAt)
        let sceneSelectionSnapshot = sceneReport(from: viewModel.scene)

        return LibraryPerformanceRunReport(
            index: index,
            status: "ok",
            initializeStoreDurationMs: initializeStoreDurationMs,
            importDurationMs: importDurationMs,
            listLibraryDurationMs: listLibraryDurationMs,
            listLibrarySearchDurationMs: listLibrarySearchDurationMs,
            sceneOpenDurationMs: sceneOpenDurationMs,
            sceneRefreshDurationMs: sceneRefreshDurationMs,
            sceneSearchDurationMs: sceneSearchDurationMs,
            sceneFolderSwitchDurationMs: sceneFolderSwitchDurationMs,
            sceneSelectionDurationMs: sceneSelectionDurationMs,
            importedCorpusCount: importResult.importedCount,
            skippedCorpusCount: importResult.skippedCount,
            listedCorpusCount: listedSnapshot.corpora.count,
            searchResultCorpusCount: searchedSnapshot.corpora.count,
            sceneOpenSnapshot: sceneOpenSnapshot,
            sceneSearchSnapshot: sceneSearchSnapshot,
            sceneSelectionSnapshot: sceneSelectionSnapshot
        )
    }

    private func writeGeneratedCorpusFiles(
        rootURL: URL,
        count: Int,
        characterCount: Int
    ) throws -> [URL] {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return try (0..<count).map { index in
            let url = rootURL.appendingPathComponent(
                "library-baseline-\(String(format: "%03d", index))-alpha.txt"
            )
            try generatedText(index: index, characterCount: characterCount)
                .write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    private func generatedText(index: Int, characterCount: Int) -> String {
        let seed = """
        Library baseline corpus \(index). alpha beta gamma delta epsilon.
        This file measures import, cleaning, tokenization, storage, and library listing.
        Section \(index % 6) includes baseline search terms and repeated academic prose.
        """
        var text = seed
        while text.count < characterCount {
            text += "\n\(seed)"
        }
        return String(text.prefix(characterCount))
    }

    private func makeSyntheticSceneSnapshot(options: LibraryPerformanceBaselineOptions) -> LibrarySnapshot {
        let folders = (0..<options.sceneFolderCount).map { index in
            LibraryFolderItem(json: [
                "id": "folder-\(index)",
                "name": "Baseline Folder \(index)"
            ])
        }
        let corpora = (0..<options.sceneCorpusCount).map { index in
            syntheticCorpus(index: index, folderCount: options.sceneFolderCount)
        }
        let corpusSets = (0..<options.sceneCorpusSetCount).map { index in
            syntheticCorpusSet(
                index: index,
                corpusCount: options.sceneCorpusCount
            )
        }
        return LibrarySnapshot(
            folders: folders,
            corpora: corpora,
            corpusSets: corpusSets
        )
    }

    private func syntheticCorpus(index: Int, folderCount: Int) -> LibraryCorpusItem {
        let folderIndex = index % max(folderCount, 1)
        return LibraryCorpusItem(json: [
            "id": "corpus-\(index)",
            "name": "Baseline Corpus \(String(format: "%04d", index))",
            "folderId": "folder-\(folderIndex)",
            "folderName": "Baseline Folder \(folderIndex)",
            "sourceType": "txt",
            "representedPath": "/baseline/corpus-\(index).txt",
            "storageFileName": "corpus-\(index).db",
            "cleaningStatus": index.isMultiple(of: 7) ? "cleanedWithChanges" : "cleaned",
            "metadata": [
                "sourceLabel": "Source \(index % 12)",
                "yearLabel": "\(2010 + (index % 15))",
                "genreLabel": index.isMultiple(of: 3) ? "News" : "Academic",
                "tags": ["tag-\(index % 9)", "batch-\(index % 5)"]
            ]
        ])
    }

    private func syntheticCorpusSet(index: Int, corpusCount: Int) -> LibraryCorpusSetItem {
        let memberCount = min(48, max(corpusCount, 1))
        let start = corpusCount == 0 ? 0 : (index * 37) % corpusCount
        let corpusIDs = (0..<memberCount).map { offset in
            "corpus-\((start + offset) % max(corpusCount, 1))"
        }
        return LibraryCorpusSetItem(json: [
            "id": "set-\(index)",
            "name": "Baseline Set \(index)",
            "corpusIds": corpusIDs,
            "corpusNames": corpusIDs,
            "metadataFilter": [:],
            "createdAt": "2026-06-16T00:00:00Z",
            "updatedAt": "2026-06-16T00:00:00Z"
        ])
    }

    private func sceneReport(from scene: LibraryManagementSceneModel) -> LibrarySceneSnapshotReport {
        LibrarySceneSnapshotReport(
            visibleCorpusCount: scene.corpora.count,
            folderCount: scene.folders.count,
            corpusSetCount: scene.corpusSets.count + scene.recentCorpusSets.count,
            selectedCorpusCount: scene.selectedCorpusIDs.count,
            filterChipCount: scene.filterChips.count,
            librarySummary: scene.librarySummary,
            currentScopeSummary: scene.currentScopeSummary
        )
    }

    private func summary(from runs: [LibraryPerformanceRunReport]) -> LibraryPerformanceSummaryReport {
        let successfulRuns = runs.filter { $0.status == "ok" }
        return LibraryPerformanceSummaryReport(
            runCount: runs.count,
            successfulRunCount: successfulRuns.count,
            initializeStoreDurationMs: durationSummary(successfulRuns.map(\.initializeStoreDurationMs)),
            importDurationMs: durationSummary(successfulRuns.map(\.importDurationMs)),
            listLibraryDurationMs: durationSummary(successfulRuns.map(\.listLibraryDurationMs)),
            listLibrarySearchDurationMs: durationSummary(successfulRuns.map(\.listLibrarySearchDurationMs)),
            sceneOpenDurationMs: durationSummary(successfulRuns.map(\.sceneOpenDurationMs)),
            sceneRefreshDurationMs: durationSummary(successfulRuns.map(\.sceneRefreshDurationMs)),
            sceneSearchDurationMs: durationSummary(successfulRuns.map(\.sceneSearchDurationMs)),
            sceneFolderSwitchDurationMs: durationSummary(successfulRuns.map(\.sceneFolderSwitchDurationMs)),
            sceneSelectionDurationMs: durationSummary(successfulRuns.map(\.sceneSelectionDurationMs)),
            importedCorpusCount: successfulRuns.map(\.importedCorpusCount).reduce(0, +),
            listedCorpusCount: successfulRuns.last?.listedCorpusCount ?? 0
        )
    }

    private func durationSummary(_ values: [Double]) -> LibraryDurationSummary {
        guard !values.isEmpty else { return .empty }
        let sorted = values.sorted()
        return LibraryDurationSummary(
            median: percentile(sorted, 0.50),
            p50: percentile(sorted, 0.50),
            p95: percentile(sorted, 0.95),
            min: sorted.first,
            max: sorted.last
        )
    }

    private func percentile(_ sortedValues: [Double], _ percentile: Double) -> Double {
        guard !sortedValues.isEmpty else { return 0 }
        guard sortedValues.count > 1 else { return sortedValues[0] }
        let clamped = min(max(percentile, 0), 1)
        let position = Double(sortedValues.count - 1) * clamped
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
    }

    private func elapsedMilliseconds(since startedAt: Date) -> Double {
        Date().timeIntervalSince(startedAt) * 1000
    }

    private func hardwareReport() -> LibraryPerformanceHardwareReport {
        let processInfo = ProcessInfo.processInfo
        return LibraryPerformanceHardwareReport(
            processorCount: processInfo.processorCount,
            activeProcessorCount: processInfo.activeProcessorCount,
            physicalMemoryMB: Int(processInfo.physicalMemory / 1_048_576),
            operatingSystem: processInfo.operatingSystemVersionString,
            lowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalProfile: String(describing: processInfo.thermalState)
        )
    }
}
