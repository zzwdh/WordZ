import Foundation

extension NativeCorpusStore: EvidenceItemManagingStorage {
    func listEvidenceItems() throws -> [EvidenceItem] {
        try ensureInitialized()
        if let cachedEvidenceItems {
            return cachedEvidenceItems
        }
        let items = try evidenceItemStore.loadItems()
        cachedEvidenceItems = items
        return items
    }

    func saveEvidenceItem(_ item: EvidenceItem) throws -> EvidenceItem {
        try ensureInitialized()

        guard !item.corpusID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw missingItemError("证据条目缺少语料来源。")
        }

        var items = try evidenceItemStore.loadItems()
        var normalized = item
        normalized.note = normalizedEvidenceNote(item.note)

        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            normalized.updatedAt = timestamp()
            items[existingIndex] = normalized
        } else {
            items.insert(normalized, at: 0)
        }

        try evidenceItemStore.saveItems(items)
        cachedEvidenceItems = items
        return normalized
    }

    func deleteEvidenceItem(itemID: String) throws {
        try ensureInitialized()
        var items = try evidenceItemStore.loadItems()
        guard items.contains(where: { $0.id == itemID }) else {
            throw missingItemError("未找到要删除的证据条目。")
        }
        items.removeAll { $0.id == itemID }
        try evidenceItemStore.saveItems(items)
        cachedEvidenceItems = items
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) throws {
        try ensureInitialized()
        var seenIDs = Set<String>()
        let sanitized = items.compactMap { item -> EvidenceItem? in
            guard seenIDs.insert(item.id).inserted else {
                return nil
            }
            var normalized = item
            normalized.note = normalizedEvidenceNote(item.note)
            return normalized
        }
        try evidenceItemStore.saveItems(sanitized)
        cachedEvidenceItems = sanitized
    }

    private func normalizedEvidenceNote(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
