import Foundation

struct NativeDiagnosticsBundleArtifact: Equatable, Sendable {
    let archiveURL: URL
    let workingDirectoryURL: URL
}

struct NativeDiagnosticsBundleContext: Codable, Equatable, Sendable {
    let generatedAt: String
    let appName: String
    let versionLabel: String
    let buildSummary: String
    let workspaceSummary: String
    let activeTab: String
    let selectedFolderName: String
    let selectedCorpusName: String
    let engineEntryPath: String
    let runtimeWorkingDirectory: String
    let userDataDirectory: String
    let taskCenterSummary: String
    let runningTaskCount: Int
    let persistedTaskCount: Int
}

struct NativeDiagnosticsBundleSourceFile: Equatable, Sendable {
    let sourceURL: URL
    let relativePath: String
    let description: String
}

struct NativeDiagnosticsBundleGeneratedFile: Equatable, Sendable {
    let data: Data
    let relativePath: String
    let description: String
}

struct NativeDiagnosticsBundlePayload: Sendable {
    let bundleBaseName: String
    let reportText: String
    let buildMetadata: NativeBuildMetadata
    let context: NativeDiagnosticsBundleContext
    let hostPreferences: NativeHostPreferencesSnapshot
    let taskHistory: [PersistedNativeBackgroundTaskItem]
    let workspaceDraft: WorkspaceStateDraft
    let uiSettings: UISettingsSnapshot
    let generatedFiles: [NativeDiagnosticsBundleGeneratedFile]
    let extraFiles: [NativeDiagnosticsBundleSourceFile]

    init(
        bundleBaseName: String,
        reportText: String,
        buildMetadata: NativeBuildMetadata,
        context: NativeDiagnosticsBundleContext,
        hostPreferences: NativeHostPreferencesSnapshot,
        taskHistory: [PersistedNativeBackgroundTaskItem],
        workspaceDraft: WorkspaceStateDraft,
        uiSettings: UISettingsSnapshot,
        generatedFiles: [NativeDiagnosticsBundleGeneratedFile] = [],
        extraFiles: [NativeDiagnosticsBundleSourceFile]
    ) {
        self.bundleBaseName = bundleBaseName
        self.reportText = reportText
        self.buildMetadata = buildMetadata
        self.context = context
        self.hostPreferences = hostPreferences
        self.taskHistory = taskHistory
        self.workspaceDraft = workspaceDraft
        self.uiSettings = uiSettings
        self.generatedFiles = generatedFiles
        self.extraFiles = extraFiles
    }
}

protocol NativeDiagnosticsBundleServicing {
    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact
    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact)
}

struct NativeDiagnosticsBundleService: NativeDiagnosticsBundleServicing {
    private let fileManager: FileManager
    private let temporaryRootURL: URL
    private let jsonEncoder: JSONEncoder

    init(
        fileManager: FileManager = .default,
        temporaryRootURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.temporaryRootURL = temporaryRootURL ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact {
        let workingDirectoryURL = temporaryRootURL
            .appendingPathComponent("WordZMacDiagnostics-\(UUID().uuidString)", isDirectory: true)
        let bundleDirectoryURL = workingDirectoryURL.appendingPathComponent(payload.bundleBaseName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: bundleDirectoryURL, withIntermediateDirectories: true)

            var manifestEntries: [NativeDiagnosticsBundleManifestEntry] = []

            try writeText(
                payload.reportText,
                to: bundleDirectoryURL.appendingPathComponent("diagnostics.txt"),
                description: "Human-readable diagnostics report.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.buildMetadata,
                to: bundleDirectoryURL.appendingPathComponent("build-metadata.json"),
                description: "Resolved build metadata for the current app bundle.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.context,
                to: bundleDirectoryURL.appendingPathComponent("runtime-context.json"),
                description: "Current runtime context and scene summary.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.hostPreferences,
                to: bundleDirectoryURL.appendingPathComponent("host-preferences.json"),
                description: "Current host preference snapshot.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.taskHistory,
                to: bundleDirectoryURL.appendingPathComponent("task-history.json"),
                description: "Persistable task-center history.",
                manifestEntries: &manifestEntries
            )
            try writeJSONObject(
                payload.workspaceDraft.asJSONObject(),
                to: bundleDirectoryURL.appendingPathComponent("workspace-state.json"),
                description: "Current workspace snapshot draft.",
                manifestEntries: &manifestEntries
            )
            try writeJSONObject(
                payload.uiSettings.asJSONObject(),
                to: bundleDirectoryURL.appendingPathComponent("ui-settings.json"),
                description: "Current UI settings snapshot.",
                manifestEntries: &manifestEntries
            )
            for generatedFile in payload.generatedFiles {
                try writeData(
                    generatedFile.data,
                    to: bundleDirectoryURL.appendingPathComponent(generatedFile.relativePath),
                    description: generatedFile.description,
                    manifestEntries: &manifestEntries
                )
            }

            for sourceFile in payload.extraFiles where fileManager.fileExists(atPath: sourceFile.sourceURL.path) {
                let destinationURL = bundleDirectoryURL.appendingPathComponent(sourceFile.relativePath)
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceFile.sourceURL, to: destinationURL)
                manifestEntries.append(
                    NativeDiagnosticsBundleManifestEntry(
                        path: sourceFile.relativePath,
                        description: sourceFile.description
                    )
                )
            }

            let manifest = NativeDiagnosticsBundleManifest(
                generatedAt: payload.context.generatedAt,
                bundleBaseName: payload.bundleBaseName,
                includedFiles: (manifestEntries + [
                    NativeDiagnosticsBundleManifestEntry(
                        path: "manifest.json",
                        description: "Inventory of the diagnostics bundle contents."
                    )
                ]).sorted { $0.path < $1.path }
            )
            try writeEncodable(
                manifest,
                to: bundleDirectoryURL.appendingPathComponent("manifest.json"),
                description: "Inventory of the diagnostics bundle contents.",
                manifestEntries: &manifestEntries
            )

            let archiveURL = workingDirectoryURL.appendingPathComponent("\(payload.bundleBaseName).zip")
            try zip(directoryURL: bundleDirectoryURL, archiveURL: archiveURL)
            return NativeDiagnosticsBundleArtifact(
                archiveURL: archiveURL,
                workingDirectoryURL: workingDirectoryURL
            )
        } catch {
            try? fileManager.removeItem(at: workingDirectoryURL)
            throw error
        }
    }

    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact) {
        try? fileManager.removeItem(at: artifact.workingDirectoryURL)
    }

    private func writeText(
        _ text: String,
        to url: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        manifestEntries.append(NativeDiagnosticsBundleManifestEntry(path: url.lastPathComponent, description: description))
    }

    private func writeEncodable<Value: Encodable>(
        _ value: Value,
        to url: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        let data = try jsonEncoder.encode(value)
        try data.write(to: url, options: .atomic)
        manifestEntries.append(NativeDiagnosticsBundleManifestEntry(path: url.lastPathComponent, description: description))
    }

    private func writeJSONObject(
        _ object: JSONObject,
        to url: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try writeData(data, to: url, description: description, manifestEntries: &manifestEntries)
    }

    private func writeData(
        _ data: Data,
        to url: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        manifestEntries.append(
            NativeDiagnosticsBundleManifestEntry(
                path: relativePath(for: url),
                description: description
            )
        )
    }

    private func relativePath(for url: URL) -> String {
        let pathComponents = url.pathComponents
        if let bundleIndex = pathComponents.lastIndex(where: { $0.hasPrefix("WordZMac-diagnostics") }) {
            return pathComponents[(bundleIndex + 1)...].joined(separator: "/")
        }
        return url.lastPathComponent
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
                domain: "WordZMac.NativeDiagnosticsBundleService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: stderr.isEmpty ? "无法创建诊断包压缩文件。" : stderr]
            )
        }
    }
}

private struct NativeDiagnosticsBundleManifest: Codable, Equatable {
    let generatedAt: String
    let bundleBaseName: String
    let includedFiles: [NativeDiagnosticsBundleManifestEntry]
}

private struct NativeDiagnosticsBundleManifestEntry: Codable, Equatable {
    let path: String
    let description: String
}
