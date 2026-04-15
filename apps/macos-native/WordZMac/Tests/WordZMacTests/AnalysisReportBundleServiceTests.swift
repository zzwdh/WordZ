import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class AnalysisReportBundleServiceTests: XCTestCase {
    func testBuildBundleWritesArchiveWithReportDraftAndCurrentExports() throws {
        let service = AnalysisReportBundleService()
        let payload = AnalysisReportBundlePayload(
            bundleBaseName: "WordZMac-report-test",
            reportText: "WordZ Report Bundle\nAnalysis: Stats",
            buildMetadata: .empty,
            workspaceDraft: .empty,
            tableSnapshot: NativeTableExportSnapshot(
                suggestedBaseName: "stats",
                table: NativeTableDescriptor(
                    columns: [
                        NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
                        NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil, presentation: .numeric())
                    ]
                ),
                rows: [
                    NativeTableRowDescriptor(id: "row-1", values: ["word": "rose", "count": "7"])
                ],
                metadataLines: ["Visible Rows: 1"]
            ),
            textDocuments: [
                AnalysisReportBundleTextDocument(
                    relativePath: "reading/summary.txt",
                    description: "Reading summary export.",
                    document: PlainTextExportDocument(suggestedName: "summary.txt", text: "A reading summary")
                )
            ],
            generatedFiles: [
                AnalysisReportBundleGeneratedFile(
                    relativePath: "method-summary.txt",
                    description: "Method summary export.",
                    data: Data("Visible Rows: 1".utf8)
                ),
                AnalysisReportBundleGeneratedFile(
                    relativePath: "notes/context.json",
                    description: "Additional report metadata.",
                    data: Data("{\"activeTab\":\"stats\"}".utf8)
                )
            ]
        )

        let artifact = try service.buildBundle(payload: payload)
        defer { service.cleanup(artifact) }

        let extractDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-report-extract-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: extractDirectoryURL) }

        try unzip(archiveURL: artifact.archiveURL, destinationURL: extractDirectoryURL)

        let bundleDirectoryURL = extractDirectoryURL.appendingPathComponent("WordZMac-report-test", isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("report.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("workspace-draft.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("current-result.csv").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("method-summary.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("reading/summary.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("notes/context.json").path))

        let csvText = try String(contentsOf: bundleDirectoryURL.appendingPathComponent("current-result.csv"), encoding: .utf8)
        XCTAssertTrue(csvText.contains("rose"))
        XCTAssertTrue(csvText.contains("Visible Rows: 1"))

        let methodSummaryText = try String(contentsOf: bundleDirectoryURL.appendingPathComponent("method-summary.txt"), encoding: .utf8)
        XCTAssertTrue(methodSummaryText.contains("Visible Rows: 1"))

        let manifestData = try Data(contentsOf: bundleDirectoryURL.appendingPathComponent("manifest.json"))
        let manifestObject = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let includedFiles = try XCTUnwrap(manifestObject["includedFiles"] as? [[String: Any]])
        let paths = includedFiles.compactMap { $0["path"] as? String }
        XCTAssertTrue(paths.contains("current-result.csv"))
        XCTAssertTrue(paths.contains("method-summary.txt"))
        XCTAssertTrue(paths.contains("reading/summary.txt"))
    }

    private func unzip(archiveURL: URL, destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            XCTFail("Failed to unzip report bundle: \(stderr)")
            return
        }
    }
}
