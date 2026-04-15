import Foundation

struct StoredTokenPosition: Hashable, Equatable, Sendable {
    let sentenceId: Int
    let tokenIndex: Int
}

struct StoredTokenPositionIndexArtifact: Equatable, Sendable {
    enum LookupMode: Equatable, Sendable {
        case exact
        case normalized
    }

    struct Lookup: Equatable, Sendable {
        let mode: LookupMode
        let key: String
    }

    let textDigest: String
    let exactPositions: [String: [StoredTokenPosition]]
    let normalizedPositions: [String: [StoredTokenPosition]]

    func positions(for lookup: Lookup) -> [StoredTokenPosition] {
        switch lookup.mode {
        case .exact:
            return exactPositions[lookup.key, default: []]
        case .normalized:
            return normalizedPositions[lookup.key, default: []]
        }
    }
}
