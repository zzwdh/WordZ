import Foundation

extension NativeDiagnosticsBundleService {
    func writeText(
        _ text: String,
        to url: URL,
        relativeTo bundleDirectoryURL: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
        manifestEntries.append(
            NativeDiagnosticsBundleManifestEntry(
                path: relativePath(for: url, relativeTo: bundleDirectoryURL),
                description: description
            )
        )
    }

    func writeEncodable<Value: Encodable>(
        _ value: Value,
        to url: URL,
        relativeTo bundleDirectoryURL: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        let data = try jsonEncoder.encode(value)
        try data.write(to: url, options: .atomic)
        manifestEntries.append(
            NativeDiagnosticsBundleManifestEntry(
                path: relativePath(for: url, relativeTo: bundleDirectoryURL),
                description: description
            )
        )
    }

    func writeJSONObject(
        _ object: JSONObject,
        to url: URL,
        relativeTo bundleDirectoryURL: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try writeData(
            data,
            to: url,
            relativeTo: bundleDirectoryURL,
            description: description,
            manifestEntries: &manifestEntries
        )
    }

    func writeData(
        _ data: Data,
        to url: URL,
        relativeTo bundleDirectoryURL: URL,
        description: String,
        manifestEntries: inout [NativeDiagnosticsBundleManifestEntry]
    ) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        manifestEntries.append(
            NativeDiagnosticsBundleManifestEntry(
                path: relativePath(for: url, relativeTo: bundleDirectoryURL),
                description: description
            )
        )
    }

    func relativePath(for url: URL, relativeTo bundleDirectoryURL: URL) -> String {
        let bundlePath = bundleDirectoryURL.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath.hasPrefix(bundlePath + "/") else {
            return url.lastPathComponent
        }
        return String(targetPath.dropFirst(bundlePath.count + 1))
    }
}
