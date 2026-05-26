import Foundation

enum EvidenceWorkbenchMutationPlanner {}

extension EvidenceWorkbenchMutationPlanner {
    static func selectedIndex(
        selectedItemID: String?,
        filteredItems: [EvidenceItem]
    ) -> Int? {
        let resolvedItemID = selectedItemID ?? filteredItems.first?.id
        guard let resolvedItemID else { return nil }
        return filteredItems.firstIndex { $0.id == resolvedItemID }
    }

    static func reorderedItemsReplacingFilteredSlots(
        items: [EvidenceItem],
        filteredItems: [EvidenceItem],
        with reorderedFilteredIDs: [String]
    ) -> [EvidenceItem]? {
        guard reorderedFilteredIDs.count == filteredItems.count else { return nil }

        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let reorderedFilteredItems = reorderedFilteredIDs.compactMap { itemsByID[$0] }
        guard reorderedFilteredItems.count == reorderedFilteredIDs.count else { return nil }
        return reorderedItemsReplacingFilteredSlots(
            items: items,
            filteredItems: filteredItems,
            with: reorderedFilteredItems
        )
    }

    static func reorderedItemsReplacingFilteredSlots(
        items: [EvidenceItem],
        filteredItems: [EvidenceItem],
        with reorderedFilteredItems: [EvidenceItem]
    ) -> [EvidenceItem]? {
        guard reorderedFilteredItems.count == filteredItems.count else { return nil }

        let filteredIDs = Set(filteredItems.map(\.id))
        var filteredIterator = reorderedFilteredItems.makeIterator()
        var reordered: [EvidenceItem] = []
        reordered.reserveCapacity(items.count)

        for item in items {
            guard filteredIDs.contains(item.id) else {
                reordered.append(item)
                continue
            }

            guard let nextItem = filteredIterator.next() else {
                return nil
            }
            reordered.append(nextItem)
        }

        guard filteredIterator.next() == nil else { return nil }
        return reordered
    }

    static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
