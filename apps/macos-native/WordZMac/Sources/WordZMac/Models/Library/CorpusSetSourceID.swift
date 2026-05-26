import Foundation

enum CorpusSetSourceID {
    private static let prefix = "set:"

    static func sourceID(for corpusSetID: String) -> String {
        prefix + corpusSetID
    }

    static func corpusSetID(from sourceID: String) -> String? {
        guard sourceID.hasPrefix(prefix) else { return nil }
        let id = String(sourceID.dropFirst(prefix.count))
        return id.isEmpty ? nil : id
    }
}
