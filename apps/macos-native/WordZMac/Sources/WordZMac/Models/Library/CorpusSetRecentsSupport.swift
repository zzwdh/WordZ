import Foundation

enum CorpusSetRecentsSupport {
    static let maxRecentCorpusSetIDs = 8

    static func normalizedRecentCorpusSetIDs(_ corpusSetIDs: [String]) -> [String] {
        var normalized: [String] = []
        var seenIDs = Set<String>()

        for corpusSetID in corpusSetIDs {
            let trimmed = corpusSetID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seenIDs.contains(trimmed) else { continue }

            normalized.append(trimmed)
            seenIDs.insert(trimmed)

            if normalized.count == maxRecentCorpusSetIDs {
                break
            }
        }

        return normalized
    }

    static func updatedRecentCorpusSetIDs(
        current: [String],
        newID: String
    ) -> [String] {
        let trimmed = newID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return normalizedRecentCorpusSetIDs(current)
        }

        return normalizedRecentCorpusSetIDs([trimmed] + current)
    }

    static func recentCorpusSets(
        from corpusSets: [LibraryCorpusSetItem],
        recentIDs: [String]
    ) -> [LibraryCorpusSetItem] {
        let corpusSetsByID = Dictionary(uniqueKeysWithValues: corpusSets.map { ($0.id, $0) })
        return normalizedRecentCorpusSetIDs(recentIDs).compactMap { corpusSetsByID[$0] }
    }
}
