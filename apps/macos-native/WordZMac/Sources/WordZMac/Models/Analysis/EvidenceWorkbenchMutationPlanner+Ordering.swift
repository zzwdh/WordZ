import Foundation

extension EvidenceWorkbenchMutationPlanner {
    static func canMoveSelectedItem(
        selectedItemID: String?,
        filteredItems: [EvidenceItem],
        direction: EvidenceWorkbenchMoveDirection
    ) -> Bool {
        guard let selectedIndex = selectedIndex(
            selectedItemID: selectedItemID,
            filteredItems: filteredItems
        ) else { return false }

        switch direction {
        case .up:
            return selectedIndex > 0
        case .down:
            return selectedIndex < filteredItems.index(before: filteredItems.endIndex)
        }
    }

    static func reorderedItemsMovingSelected(
        selectedItemID: String?,
        items: [EvidenceItem],
        filteredItems: [EvidenceItem],
        direction: EvidenceWorkbenchMoveDirection
    ) -> [EvidenceItem]? {
        guard let selectedIndex = selectedIndex(
            selectedItemID: selectedItemID,
            filteredItems: filteredItems
        ) else { return nil }

        let neighborIndex: Int
        switch direction {
        case .up:
            guard selectedIndex > 0 else { return nil }
            neighborIndex = selectedIndex - 1
        case .down:
            guard selectedIndex < filteredItems.index(before: filteredItems.endIndex) else { return nil }
            neighborIndex = selectedIndex + 1
        }

        var reorderedVisibleItems = filteredItems
        reorderedVisibleItems.swapAt(selectedIndex, neighborIndex)
        return reorderedItemsReplacingFilteredSlots(
            items: items,
            filteredItems: filteredItems,
            with: reorderedVisibleItems.map(\.id)
        )
    }
}
