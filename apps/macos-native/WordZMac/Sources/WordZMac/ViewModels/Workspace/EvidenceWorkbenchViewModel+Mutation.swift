import Foundation

extension EvidenceWorkbenchViewModel {
    func canMoveSelectedItem(_ direction: EvidenceWorkbenchMoveDirection) -> Bool {
        EvidenceWorkbenchMutationPlanner.canMoveSelectedItem(
            selectedItemID: selectedItem?.id,
            filteredItems: filteredItems,
            direction: direction
        )
    }

    func reorderedItemsMovingSelected(_ direction: EvidenceWorkbenchMoveDirection) -> [EvidenceItem]? {
        EvidenceWorkbenchMutationPlanner.reorderedItemsMovingSelected(
            selectedItemID: selectedItem?.id,
            items: items,
            filteredItems: filteredItems,
            direction: direction
        )
    }
}
