import Foundation

extension NativeCorpusStore {
    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) throws -> LibraryCorpusSetItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw missingItemError("语料集名称不能为空。")
        }

        let corpora = try loadCorpora()
        let corporaByID = Dictionary(uniqueKeysWithValues: corpora.map { ($0.id, $0) })
        var seen: Set<String> = []
        let resolvedCorpora = corpusIDs
            .filter { seen.insert($0).inserted }
            .compactMap { corporaByID[$0] }

        guard !resolvedCorpora.isEmpty else {
            throw missingItemError("当前没有可保存到语料集的语料。")
        }

        var corpusSets = try loadCorpusSets()
        let now = timestamp()
        if let existingIndex = corpusSets.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            corpusSets[existingIndex].name = trimmedName
            corpusSets[existingIndex].corpusIDs = resolvedCorpora.map(\.id)
            corpusSets[existingIndex].corpusNames = resolvedCorpora.map(\.name)
            corpusSets[existingIndex].metadataFilterState = metadataFilterState
            corpusSets[existingIndex].updatedAt = now
            try saveCorpusSets(corpusSets)
            return corpusSets[existingIndex].libraryItem
        }

        let created = NativeCorpusSetRecord(
            id: UUID().uuidString,
            name: trimmedName,
            corpusIDs: resolvedCorpora.map(\.id),
            corpusNames: resolvedCorpora.map(\.name),
            metadataFilterState: metadataFilterState,
            createdAt: now,
            updatedAt: now
        )
        corpusSets.append(created)
        try saveCorpusSets(corpusSets)
        return created.libraryItem
    }

    func deleteCorpusSet(corpusSetID: String) throws {
        var corpusSets = try loadCorpusSets()
        guard corpusSets.contains(where: { $0.id == corpusSetID }) else {
            throw missingItemError("未找到要删除的语料集。")
        }
        corpusSets.removeAll { $0.id == corpusSetID }
        try saveCorpusSets(corpusSets)
    }
}
