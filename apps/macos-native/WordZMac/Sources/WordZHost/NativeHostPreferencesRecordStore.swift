import Foundation

@MainActor
package protocol NativeHostPreferencesRecordStoring: AnyObject {
    func load() -> NativeHostPreferencesRecord
    func save(_ record: NativeHostPreferencesRecord) throws
}

@MainActor
package final class NativeHostPreferencesRecordStore: NativeHostPreferencesRecordStoring {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    package init(
        fileURL: URL,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileURL = fileURL
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    package func load() -> NativeHostPreferencesRecord {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }
        return (try? decoder.decode(NativeHostPreferencesRecord.self, from: data)) ?? .default
    }

    package func save(_ record: NativeHostPreferencesRecord) throws {
        try ensureParentDirectory()
        let data = try encoder.encode(record)
        try data.write(to: fileURL, options: .atomic)
    }

    private func ensureParentDirectory() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
