import Foundation

extension NativeCorpusStore: ConcordanceSavedSetManagingStorage {
    func listConcordanceSavedSets() throws -> [ConcordanceSavedSet] {
        try ensureInitialized()
        if let cachedConcordanceSavedSets {
            return cachedConcordanceSavedSets.sorted { $0.updatedAt > $1.updatedAt }
        }
        let sets = try concordanceSavedSetStore.loadSets()
        cachedConcordanceSavedSets = sets
        return sets.sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) throws -> ConcordanceSavedSet {
        try ensureInitialized()

        let trimmedName = set.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw missingItemError("命中集名称不能为空。")
        }
        guard !set.rows.isEmpty else {
            throw missingItemError("命中集至少需要一条结果行。")
        }

        var sets = try concordanceSavedSetStore.loadSets()
        if let existingIndex = sets.firstIndex(where: {
            $0.id == set.id || ($0.kind == set.kind && $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame)
        }) {
            var updated = set
            updated.name = trimmedName
            updated.updatedAt = timestamp()
            sets[existingIndex] = updated
            try concordanceSavedSetStore.saveSets(sets)
            cachedConcordanceSavedSets = sets
            return updated
        }

        var created = set
        created.name = trimmedName
        sets.append(created)
        try concordanceSavedSetStore.saveSets(sets)
        cachedConcordanceSavedSets = sets
        return created
    }

    func deleteConcordanceSavedSet(setID: String) throws {
        try ensureInitialized()
        var sets = try concordanceSavedSetStore.loadSets()
        guard sets.contains(where: { $0.id == setID }) else {
            throw missingItemError("未找到要删除的命中集。")
        }
        sets.removeAll { $0.id == setID }
        try concordanceSavedSetStore.saveSets(sets)
        cachedConcordanceSavedSets = sets
    }
}
