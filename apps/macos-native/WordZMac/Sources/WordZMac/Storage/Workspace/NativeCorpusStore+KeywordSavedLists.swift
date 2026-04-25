import Foundation

extension NativeCorpusStore: KeywordSavedListManagingStorage {
    func listKeywordSavedLists() throws -> [KeywordSavedList] {
        try ensureInitialized()
        return try loadKeywordSavedLists()
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveKeywordSavedList(_ list: KeywordSavedList) throws -> KeywordSavedList {
        try ensureInitialized()

        let trimmedName = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw missingItemError("关键词词表名称不能为空。")
        }

        var lists = try loadKeywordSavedLists()
        if let existingIndex = lists.firstIndex(where: { $0.id == list.id || $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            var updated = list
            updated.name = trimmedName
            updated.updatedAt = timestamp()
            lists[existingIndex] = updated
            try saveKeywordSavedLists(lists)
            return updated
        }

        var created = list
        created.name = trimmedName
        lists.append(created)
        try saveKeywordSavedLists(lists)
        return created
    }

    func deleteKeywordSavedList(listID: String) throws {
        try ensureInitialized()
        var lists = try loadKeywordSavedLists()
        guard lists.contains(where: { $0.id == listID }) else {
            throw missingItemError("未找到要删除的关键词词表。")
        }
        lists.removeAll { $0.id == listID }
        try saveKeywordSavedLists(lists)
    }
}
