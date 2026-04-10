import Foundation

struct AnalysisReportBundleTextDocument: Equatable, Sendable {
    let relativePath: String
    let description: String
    let document: PlainTextExportDocument
}

struct AnalysisReportBundleGeneratedFile: Equatable, Sendable {
    let relativePath: String
    let description: String
    let data: Data
}

struct AnalysisReportBundlePayload: Equatable, Sendable {
    let bundleBaseName: String
    let reportText: String
    let buildMetadata: NativeBuildMetadata
    let workspaceDraft: WorkspaceStateDraft
    let tableSnapshot: NativeTableExportSnapshot?
    let textDocuments: [AnalysisReportBundleTextDocument]
    let generatedFiles: [AnalysisReportBundleGeneratedFile]
}

struct AnalysisReportBundleArtifact: Equatable, Sendable {
    let workingDirectoryURL: URL
    let bundleDirectoryURL: URL
    let archiveURL: URL
}

@MainActor
protocol AnalysisReportBundleServicing: AnyObject {
    func buildBundle(payload: AnalysisReportBundlePayload) throws -> AnalysisReportBundleArtifact
    func cleanup(_ artifact: AnalysisReportBundleArtifact)
}

@MainActor
final class AnalysisReportBundleService: AnalysisReportBundleServicing {
    private let fileManager: FileManager
    private let tableExportService: TableExportService

    init(
        fileManager: FileManager = .default,
        tableExportService: TableExportService = TableExportService()
    ) {
        self.fileManager = fileManager
        self.tableExportService = tableExportService
    }

    func buildBundle(payload: AnalysisReportBundlePayload) throws -> AnalysisReportBundleArtifact {
        let workingDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("WordZMacReport-\(UUID().uuidString)", isDirectory: true)
        let bundleDirectoryURL = workingDirectoryURL.appendingPathComponent(payload.bundleBaseName, isDirectory: true)
        let archiveURL = workingDirectoryURL.appendingPathComponent("\(payload.bundleBaseName).zip")

        try fileManager.createDirectory(at: bundleDirectoryURL, withIntermediateDirectories: true)

        var manifestEntries: [AnalysisReportBundleManifestEntry] = []

        let reportURL = bundleDirectoryURL.appendingPathComponent("report.txt")
        try payload.reportText.write(to: reportURL, atomically: true, encoding: .utf8)
        manifestEntries.append(.init(path: "report.txt", description: "Human-readable analysis report summary."))

        let metadataURL = bundleDirectoryURL.appendingPathComponent("build-metadata.json")
        try writeJSON(payload.buildMetadata, to: metadataURL)
        manifestEntries.append(.init(path: "build-metadata.json", description: "Resolved build metadata for the current app bundle."))

        let draftURL = bundleDirectoryURL.appendingPathComponent("workspace-draft.json")
        let draftData = try JSONSerialization.data(withJSONObject: payload.workspaceDraft.asJSONObject(), options: [.prettyPrinted, .sortedKeys])
        try draftData.write(to: draftURL, options: .atomic)
        manifestEntries.append(.init(path: "workspace-draft.json", description: "Saved workspace draft used to build this report bundle."))

        if let tableSnapshot = payload.tableSnapshot {
            let tableURL = bundleDirectoryURL.appendingPathComponent("current-result.csv")
            try tableExportService.writeCSV(snapshot: tableSnapshot, to: tableURL.path)
            manifestEntries.append(.init(path: "current-result.csv", description: "Current visible result table as CSV."))
        }

        for textDocument in payload.textDocuments {
            let destinationURL = bundleDirectoryURL.appendingPathComponent(textDocument.relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try textDocument.document.text.write(to: destinationURL, atomically: true, encoding: .utf8)
            manifestEntries.append(.init(path: textDocument.relativePath, description: textDocument.description))
        }

        for generatedFile in payload.generatedFiles {
            let destinationURL = bundleDirectoryURL.appendingPathComponent(generatedFile.relativePath)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try generatedFile.data.write(to: destinationURL, options: .atomic)
            manifestEntries.append(.init(path: generatedFile.relativePath, description: generatedFile.description))
        }

        let manifest = AnalysisReportBundleManifest(
            bundleBaseName: payload.bundleBaseName,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            includedFiles: manifestEntries.sorted { $0.path < $1.path }
        )
        let manifestURL = bundleDirectoryURL.appendingPathComponent("manifest.json")
        try writeJSON(manifest, to: manifestURL)

        try zip(directoryURL: bundleDirectoryURL, archiveURL: archiveURL)
        return AnalysisReportBundleArtifact(
            workingDirectoryURL: workingDirectoryURL,
            bundleDirectoryURL: bundleDirectoryURL,
            archiveURL: archiveURL
        )
    }

    func cleanup(_ artifact: AnalysisReportBundleArtifact) {
        try? fileManager.removeItem(at: artifact.workingDirectoryURL)
    }

    private func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func zip(directoryURL: URL, archiveURL: URL) throws {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", directoryURL.path, archiveURL.path]
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(
                domain: "WordZMac.AnalysisReportBundleService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: stderr.isEmpty ? "无法创建报告 bundle 压缩文件。" : stderr]
            )
        }
    }
}

private struct AnalysisReportBundleManifest: Codable, Equatable {
    let bundleBaseName: String
    let generatedAt: String
    let includedFiles: [AnalysisReportBundleManifestEntry]
}

private struct AnalysisReportBundleManifestEntry: Codable, Equatable {
    let path: String
    let description: String
}
