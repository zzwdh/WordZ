import Foundation

extension NativeCorpusStore: EvidenceItemManagingStorage {
    func listEvidenceItems() throws -> [EvidenceItem] {
        try ensureInitialized()
        return try loadEvidenceItems()
    }

    func saveEvidenceItem(_ item: EvidenceItem) throws -> EvidenceItem {
        try ensureInitialized()

        guard !item.corpusID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw missingItemError("证据条目缺少语料来源。")
        }

        var items = try loadEvidenceItems()
        var normalized = item
        normalized.sectionTitle = normalizedEvidenceTextField(item.sectionTitle)
        normalized.claim = normalizedEvidenceTextField(item.claim)
        normalized.tags = normalizedEvidenceTags(item.tags)
        normalized.note = normalizedEvidenceTextField(item.note)

        if let existingIndex = items.firstIndex(where: { $0.id == item.id }) {
            normalized.updatedAt = timestamp()
            items[existingIndex] = normalized
        } else {
            items.insert(normalized, at: 0)
        }

        try saveEvidenceItems(items)
        return normalized
    }

    func deleteEvidenceItem(itemID: String) throws {
        try ensureInitialized()
        var items = try loadEvidenceItems()
        guard items.contains(where: { $0.id == itemID }) else {
            throw missingItemError("未找到要删除的证据条目。")
        }
        items.removeAll { $0.id == itemID }
        try saveEvidenceItems(items)
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) throws {
        try ensureInitialized()
        var seenIDs = Set<String>()
        let sanitized = items.compactMap { item -> EvidenceItem? in
            guard seenIDs.insert(item.id).inserted else {
                return nil
            }
            var normalized = item
            normalized.sectionTitle = normalizedEvidenceTextField(item.sectionTitle)
            normalized.claim = normalizedEvidenceTextField(item.claim)
            normalized.tags = normalizedEvidenceTags(item.tags)
            normalized.note = normalizedEvidenceTextField(item.note)
            return normalized
        }
        try saveEvidenceItems(sanitized)
    }

    private func normalizedEvidenceTextField(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedEvidenceTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { return nil }
            return trimmed
        }
    }
}
