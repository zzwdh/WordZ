import Foundation

extension EvidenceWorkbenchViewModel {
    var selectedItem: EvidenceItem? {
        guard let selectedItemID else { return filteredItems.first }
        return filteredItems.first(where: { $0.id == selectedItemID }) ?? filteredItems.first
    }

    var selectedFilteredIndex: Int? {
        guard let selectedItemID = selectedItem?.id else { return nil }
        return filteredItems.firstIndex(where: { $0.id == selectedItemID })
    }

    var canMoveSelectedItemUp: Bool {
        canMoveSelectedItem(.up)
    }

    var canMoveSelectedItemDown: Bool {
        canMoveSelectedItem(.down)
    }

    func applyItems(_ items: [EvidenceItem]) {
        self.items = items
        normalizeSelection()
        syncEditorState()
    }

    func normalizeSelection() {
        let filteredIDs = Set(filteredItems.map(\.id))
        if let selectedItemID, filteredIDs.contains(selectedItemID) {
            return
        }
        selectedItemID = filteredItems.first?.id
    }

    func syncEditorState() {
        citationFormatDraft = selectedItem?.citationFormat ?? .citationLine
        citationStyleDraft = selectedItem?.citationStyle ?? .plain
        noteDraft = selectedItem?.note ?? ""
    }
}
