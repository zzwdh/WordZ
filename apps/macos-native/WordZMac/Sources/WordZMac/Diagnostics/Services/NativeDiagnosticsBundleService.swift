import Foundation

protocol NativeDiagnosticsBundleServicing {
    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact
    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact)
}

struct NativeDiagnosticsBundleService: NativeDiagnosticsBundleServicing {
    let fileManager: FileManager
    let temporaryRootURL: URL
    let jsonEncoder: JSONEncoder

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
                relativeTo: bundleDirectoryURL,
                description: "Human-readable diagnostics report.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.buildMetadata,
                to: bundleDirectoryURL.appendingPathComponent("build-metadata.json"),
                relativeTo: bundleDirectoryURL,
                description: "Resolved build metadata for the current app bundle.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.context,
                to: bundleDirectoryURL.appendingPathComponent("runtime-context.json"),
                relativeTo: bundleDirectoryURL,
                description: "Current runtime context and scene summary.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.hostPreferences,
                to: bundleDirectoryURL.appendingPathComponent("host-preferences.json"),
                relativeTo: bundleDirectoryURL,
                description: "Current host preference snapshot.",
                manifestEntries: &manifestEntries
            )
            try writeEncodable(
                payload.taskHistory,
                to: bundleDirectoryURL.appendingPathComponent("task-history.json"),
                relativeTo: bundleDirectoryURL,
                description: "Persistable task-center history.",
                manifestEntries: &manifestEntries
            )
            try writeJSONObject(
                payload.workspaceDraft.asJSONObject(),
                to: bundleDirectoryURL.appendingPathComponent("workspace-state.json"),
                relativeTo: bundleDirectoryURL,
                description: "Current workspace snapshot draft.",
                manifestEntries: &manifestEntries
            )
            try writeJSONObject(
                payload.uiSettings.asJSONObject(),
                to: bundleDirectoryURL.appendingPathComponent("ui-settings.json"),
                relativeTo: bundleDirectoryURL,
                description: "Current UI settings snapshot.",
                manifestEntries: &manifestEntries
            )
            for generatedFile in payload.generatedFiles {
                try writeData(
                    generatedFile.data,
                    to: bundleDirectoryURL.appendingPathComponent(generatedFile.relativePath),
                    relativeTo: bundleDirectoryURL,
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
                relativeTo: bundleDirectoryURL,
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
}
